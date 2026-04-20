import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(FirebaseAuth.instance, FirebaseFirestore.instance);
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService(this._auth, this._firestore);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> getCurrentUser() async {
    return _auth.currentUser;
  }

  // Connexion
  Future<AppUser?> signIn(String email, String password) async {
    try {
      // 1. Authentification Firebase
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 15));
      
      if (result.user != null) {
        // 2. Récupération Profil Firestore avec Timeout
        final doc = await _firestore.collection('users').doc(result.user!.uid)
            .get()
            .timeout(const Duration(seconds: 10)); // Fail-Fast si réseau trop lent
            
        if (doc.exists) {
          return AppUser.fromMap(doc.data()!, doc.id);
        }
        // Si le doc n'existe pas, on retourne null pour signaler un profil manquant
        return null;
      }
      return null;
    } on FirebaseAuthException {
      rethrow; // Laisser l'UI gérer les codes d'erreur (wrong-password, user-not-found, etc.)
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Connexion expirée (Réseau trop lent). Veuillez réessayer.');
      }
      throw Exception('Erreur imprévue: $e');
    }
  }


  // Inscription
  Future<AppUser?> register(String email, String password, AppUser userModel, {bool sendEmailVerification = true}) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = result.user;

      if (firebaseUser != null) {
        if (sendEmailVerification) {
          await firebaseUser.sendEmailVerification();
        }

        // Enregistrement des données spécifiques dans Firestore
        final newUser = userModel.copyWith(
          id: firebaseUser.uid,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .set(newUser.toMap());

        return newUser;
      }
      return null;
    } catch (e) {
      throw Exception('Erreur d\'inscription: $e');
    }
  }

  // --- VALIDATION SMS ---

  /// Lance le processus de vérification du numéro de téléphone
  Future<void> verifyPhone({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(FirebaseAuthException e) onFailed,
    required Function(UserCredential user) onAutoVerify,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-vérification (souvent sur Android)
        final userCredential = await _auth.currentUser?.linkWithCredential(credential);
        if (userCredential != null) onAutoVerify(userCredential);
      },
      verificationFailed: onFailed,
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  /// Valide le code OTP reçu par SMS et retourne le Credential
  Future<PhoneAuthCredential> getPhoneCredential(String verificationId, String smsCode) async {
    return PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  /// Lie un compte existant avec un credential téléphonique
  Future<UserCredential?> linkPhone(PhoneAuthCredential credential) async {
    return await _auth.currentUser?.linkWithCredential(credential);
  }

  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Réinitialisation de mot de passe
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
