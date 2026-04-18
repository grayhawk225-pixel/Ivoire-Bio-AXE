// ============================================================
//  SCRIPT DE CRÉATION DES COMPTES DE TEST - Ivoire Bio-Axe
//  Usage: dart run tool/seed_test_accounts.dart
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// ── Configuration Firebase ────────────────────────────────────
const String firebaseApiKey = 'AIzaSyCZwqodUvl4_nD7Y4Ex8lmIHP4iN3316zQ';
const String firestoreBaseUrl =
    'https://firestore.googleapis.com/v1/projects/ivoire-bio-axe/databases/(default)/documents';

// ── Comptes à créer ───────────────────────────────────────────
final List<Map<String, dynamic>> testAccounts = [
  {
    'email': 'restaurateur@bioaxe.test',
    'password': 'Test1234!',
    'displayName': 'Restaurant Test',
    'firestoreData': {
      'email': {'stringValue': 'restaurateur@bioaxe.test'},
      'role': {'stringValue': 'restaurateur'},
      'phoneNumber': {'stringValue': '0701020304'},
      'balance': {'doubleValue': 0.0},
      'restaurantName': {'stringValue': 'Restaurant La Ruche (TEST)'},
      'createdAt': {'timestampValue': '2026-01-01T00:00:00Z'},
    },
  },
  {
    'email': 'collecteur@bioaxe.test',
    'password': 'Test1234!',
    'displayName': 'Collecteur Test',
    'firestoreData': {
      'email': {'stringValue': 'collecteur@bioaxe.test'},
      'role': {'stringValue': 'collecteur'},
      'phoneNumber': {'stringValue': '0702030405'},
      'balance': {'doubleValue': 0.0},
      'vehicleType': {'stringValue': 'Tricycle'},
      'idCardUrl': {'stringValue': 'CI-TEST-001'},
      'collecteurApproved': {'booleanValue': true},
      'payoutMobileNumber': {'stringValue': '0702030405'},
      'payoutOperator': {'stringValue': 'Wave CI'},
      'createdAt': {'timestampValue': '2026-01-01T00:00:00Z'},
    },
  },
  {
    'email': 'acheteur@bioaxe.test',
    'password': 'Test1234!',
    'displayName': 'Acheteur Test',
    'firestoreData': {
      'email': {'stringValue': 'acheteur@bioaxe.test'},
      'role': {'stringValue': 'acheteur'},
      'phoneNumber': {'stringValue': '0703040506'},
      'balance': {'doubleValue': 5000.0},
      'profession': {'stringValue': 'Jardinier / Agriculteur'},
      'deliveryAddress': {'stringValue': 'Cocody, Abidjan (TEST)'},
      'mobileMoneyNumber': {'stringValue': '0703040506'},
      'mobileMoneyOperator': {'stringValue': 'Orange Money'},
      'createdAt': {'timestampValue': '2026-01-01T00:00:00Z'},
    },
  },
  {
    'email': 'admin@bioaxe.test',
    'password': 'Test1234!',
    'displayName': 'Administrateur',
    'firestoreData': {
      'email': {'stringValue': 'admin@bioaxe.test'},
      'role': {'stringValue': 'admin'},
      'phoneNumber': {'stringValue': '0700000000'},
      'balance': {'doubleValue': 0.0},
      'createdAt': {'timestampValue': '2026-01-01T00:00:00Z'},
    },
  },
];

// ── Fonctions ─────────────────────────────────────────────────

/// Crée un utilisateur Firebase Auth via l'API REST
Future<String?> createAuthUser(String email, String password) async {
  final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$firebaseApiKey');

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
      'returnSecureToken': true,
    }),
  );

  final body = jsonDecode(response.body);

  if (response.statusCode == 200) {
    return body['localId'] as String?;
  } else {
    final error = body['error']?['message'] ?? 'Erreur inconnue';
    if (error.contains('EMAIL_EXISTS')) {
      print('  ⚠️  Le compte $email existe déjà, on passe.');
      // Tenter de récupérer l'UID via connexion
      return await getUidBySignIn(email, password);
    }
    print('  ❌ Erreur Auth pour $email : $error');
    return null;
  }
}

/// Se connecte et retourne l'UID si le compte existe déjà
Future<String?> getUidBySignIn(String email, String password) async {
  final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$firebaseApiKey');

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
      'returnSecureToken': true,
    }),
  );

  final body = jsonDecode(response.body);
  if (response.statusCode == 200) {
    return body['localId'] as String?;
  }
  return null;
}

/// Écrit le document profil dans Firestore
Future<void> createFirestoreProfile(
    String uid, Map<String, dynamic> data) async {
  final url = Uri.parse('$firestoreBaseUrl/users/$uid');

  final response = await http.patch(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'fields': data}),
  );

  if (response.statusCode == 200 || response.statusCode == 201) {
    print('  ✅ Profil Firestore créé/mis à jour.');
  } else {
    print(
        '  ❌ Erreur Firestore (${response.statusCode}) : ${response.body.substring(0, 200)}');
  }
}

// ── Main ──────────────────────────────────────────────────────

void main() async {
  print('');
  print('╔══════════════════════════════════════════════════════╗');
  print('║  🌿 Ivoire Bio-Axe — Seed des comptes de TEST       ║');
  print('╚══════════════════════════════════════════════════════╝');
  print('');

  for (final account in testAccounts) {
    final email = account['email'] as String;
    final password = account['password'] as String;
    final role = (account['firestoreData'] as Map)['role']
        ['stringValue'] as String;

    print('▶ Création du compte : $email  [rôle: $role]');

    // 1. Créer le compte Firebase Auth
    final uid = await createAuthUser(email, password);
    if (uid == null) {
      print('  ⛔ Impossible de créer ou récupérer le compte. On passe.\n');
      continue;
    }
    print('  🔑 UID : $uid');

    // 2. Créer le profil Firestore
    await createFirestoreProfile(
        uid, account['firestoreData'] as Map<String, dynamic>);
    print('');
  }

  print('══════════════════════════════════════════════════════');
  print('');
  print('✅ COMPTES DE TEST PRÊTS À UTILISER');
  print('');
  print('┌──────────────────────────────────┬──────────────┐');
  print('│ Email                            │ Mot de passe │');
  print('├──────────────────────────────────┼──────────────┤');
  print('│ restaurateur@bioaxe.test         │ Test1234!    │');
  print('│ collecteur@bioaxe.test           │ Test1234!    │');
  print('│ acheteur@bioaxe.test             │ Test1234!    │');
  print('│ admin@bioaxe.test                │ Test1234!    │');
  print('└──────────────────────────────────┴──────────────┘');
  print('');
  print('⚠️  Note : La vérification email est DÉSACTIVÉE pour ces');
  print('   comptes (ils passeront directement au tableau de bord).');
  print('');

  exit(0);
}
