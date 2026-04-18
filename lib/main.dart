import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'models/user_model.dart';

import 'screens/auth/login_screen.dart';
import 'screens/restaurateur/restaurateur_home_screen.dart';
import 'screens/collecteur/collecteur_home_screen.dart';
import 'screens/acheteur/acheteur_dashboard.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: IvoireBioAxeApp()));
}

/// Clé globale pour afficher des SnackBars depuis n'importe où dans l'app.
/// Évite les problèmes d'affichage quand le Scaffold se reconstruit (StreamBuilder, etc.)
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class IvoireBioAxeApp extends StatelessWidget {
  const IvoireBioAxeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ivoire Bio-Axe',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          primary: const Color(0xFF4CAF50),
          secondary: const Color(0xFF795548),
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _notifsInitialized = false;

  Future<void> _initNotifications(String userId) async {
    if (_notifsInitialized) return;
    try {
      await PushNotificationService().initialize(userId);
      setState(() => _notifsInitialized = true);
      print('Notifications initialisées avec succès.');
    } catch (e) {
      print('Erreur init notifications: $e');
    }
  }

  void _scheduleNotificationInit(String userId) {
    if (_notifsInitialized) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_notifsInitialized) {
        _initNotifications(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.hasError) {
          return _ErrorScreen(message: 'Erreur Connexion (Auth) : ${authSnapshot.error}');
        }

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen(message: 'Authentification...');
        }

        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginScreen();
        }

        final uid = authSnapshot.data!.uid;
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.hasError) {
              return _ErrorScreen(
                message: 'Impossible de lire votre profil.\nVérifiez votre connexion internet.\n(Firestore: ${userSnapshot.error})',
                canSignOut: true,
              );
            }

            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen(message: 'Récupération du profil...');
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return _ErrorScreen(
                message: '❌ Utilisateur trouvé, mais profil manquant.\nID: $uid\n\nContactez le support ou réessayez avec un autre compte.',
                canSignOut: true,
              );
            }

            final data = userSnapshot.data!.data() as Map<String, dynamic>;
            final appUser = AppUser.fromMap(data, uid);
            final firebaseUser = authSnapshot.data!;

            // 🔒 VÉRIFICATION DE L'IDENTITÉ
            final isTestAccount = firebaseUser.email?.endsWith('@bioaxe.test') ?? false;
            if (!firebaseUser.emailVerified && !isTestAccount) {
              return _VerificationRequiredScreen(email: firebaseUser.email ?? "");
            }

            // 🔒 Vérification Collecteur : Approuvé par l'Admin ?
            if (appUser.role == UserRole.collecteur && (appUser.collecteurApproved == null || appUser.collecteurApproved == false)) {
              return _PendingApprovalScreen(
                message: appUser.collecteurApproved == false
                    ? '❌ Dossier refusé.'
                    : '⏳ Dossier en attente.',
              );
            }

            // ✅ Initialisation safe des notifications après le build
            _scheduleNotificationInit(uid);

            // ✅ Routage selon le rôle
            switch (appUser.role) {
              case UserRole.admin:
                return _AccessDeniedScreen();
              case UserRole.restaurateur:
                return RestaurateurHomeScreen(key: ValueKey('resto_$uid'), user: appUser);
              case UserRole.collecteur:
                return CollecteurHomeScreen(key: ValueKey('collect_$uid'), user: appUser);
              case UserRole.acheteur:
                return AcheteurDashboard(key: ValueKey('achat_$uid'), user: appUser);
            }
          },
        );
      },
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  final bool canSignOut;
  const _ErrorScreen({required this.message, this.canSignOut = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 60),
              ),
              const SizedBox(height: 32),
              const Text(
                'Oups ! Un souci est survenu',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 48),
              if (canSignOut)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Déconnexion et Réessayer', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthWrapper())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Réessayer maintenant', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  final String message;
  const _LoadingScreen({this.message = 'Chargement...'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco_rounded, size: 80, color: Color(0xFF4CAF50)).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1200.ms),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: Color(0xFF4CAF50),
              strokeWidth: 3,
            ),
            const SizedBox(height: 32),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.admin_panel_settings, size: 80, color: Color(0xFF2E7D32)),
              const SizedBox(height: 24),
              const Text('Espace Administrateur', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Votre espace de gestion est disponible sur le\nPortail Administrateur dédié.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.6)),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
                onPressed: () => FirebaseAuth.instance.signOut(),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingApprovalScreen extends StatelessWidget {
  final String message;
  const _PendingApprovalScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top_rounded, size: 80, color: Colors.orange),
              const SizedBox(height: 24),
              const Text('Ivoire Bio-Axe', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.6)),
              const SizedBox(height: 40),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
                onPressed: () => FirebaseAuth.instance.signOut(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationRequiredScreen extends StatelessWidget {
  final String email;
  const _VerificationRequiredScreen({required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_unread_outlined, size: 80, color: Colors.orange),
              const SizedBox(height: 24),
              const Text('Vérification Requise', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(
                'Veuillez cliquer sur le lien envoyé à :\n$email',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, height: 1.6),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => FirebaseAuth.instance.currentUser?.reload(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white),
                child: const Text('J\'ai vérifié mon email'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Retour / Se déconnecter', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
