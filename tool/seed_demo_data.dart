// ============================================================
//  SCRIPT DE CRÉATION DE DONNÉES DE DÉMONSTRATION - Ivoire Bio-Axe
//  Usage: dart run tool/seed_demo_data.dart
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String firestoreBaseUrl = 'https://firestore.googleapis.com/v1/projects/ivoire-bio-axe/databases/(default)/documents';

Future<void> createDocument(String collection, Map<String, dynamic> data) async {
  final url = Uri.parse('$firestoreBaseUrl/$collection');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'fields': data}),
  );
  if (response.statusCode == 200) {
    print('✅ Document ajouté dans $collection');
  } else {
    print('❌ Erreur HTTP ${response.statusCode}: ${response.body}');
  }
}

void main() async {
  print('╔══════════════════════════════════════════════════════╗');
  print('║  🚀 Ivoire Bio-Axe — Injection de Données de Démo    ║');
  print('╚══════════════════════════════════════════════════════╝');
  print('');

  // Génération de Requêtes de Collecte (waste_requests)
  print('📦 Création des requêtes de collectes...');
  
  await createDocument('waste_requests', {
    'type': {'stringValue': 'Organique Frais'},
    'status': {'stringValue': 'pending'},
    'volume': {'doubleValue': 45.5},
    'restaurantName': {'stringValue': 'Maquis La Plage'},
    'createdAt': {'timestampValue': DateTime.now().subtract(const Duration(hours: 3)).toUtc().toIso8601String().replaceAll(RegExp(r'\.\d+Z'), 'Z')},
  });
  
  await createDocument('waste_requests', {
    'type': {'stringValue': 'Huile Usagée'},
    'status': {'stringValue': 'pending'},
    'volume': {'doubleValue': 15.0},
    'restaurantName': {'stringValue': 'Restaurant Le Cordon Bleu'},
    'createdAt': {'timestampValue': DateTime.now().subtract(const Duration(minutes: 45)).toUtc().toIso8601String().replaceAll(RegExp(r'\.\d+Z'), 'Z')},
  });

  await createDocument('waste_requests', {
    'type': {'stringValue': 'Compost'},
    'status': {'stringValue': 'completed'},
    'volume': {'doubleValue': 120.0},
    'restaurantName': {'stringValue': 'Hôtel Ivoire'},
    'createdAt': {'timestampValue': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String().replaceAll(RegExp(r'\.\d+Z'), 'Z')},
  });

  // Génération de Tickets de Support (support_tickets)
  print('🎧 Création des tickets de support...');
  
  await createDocument('support_tickets', {
    'userId': {'stringValue': 'user_demo_1'},
    'subject': {'stringValue': 'Problème de paiement Wave'},
    'message': {'stringValue': 'Mon transfert Wave est bloqué depuis hier matin, merci de m\'aider.'},
    'status': {'stringValue': 'open'},
    'createdAt': {'timestampValue': DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String().replaceAll(RegExp(r'\.\d+Z'), 'Z')},
  });

  await createDocument('support_tickets', {
    'userId': {'stringValue': 'user_demo_2'},
    'subject': {'stringValue': 'Changement de véhicule'},
    'message': {'stringValue': 'Je n\'ai plus mon Tricycle, j\'ai maintenant une Petite Camionnette.'},
    'status': {'stringValue': 'closed'},
    'createdAt': {'timestampValue': DateTime.now().subtract(const Duration(days: 2)).toUtc().toIso8601String().replaceAll(RegExp(r'\.\d+Z'), 'Z')},
  });

  print('');
  print('🎉 TERMINE ! Les graphiques de l\'admin sont maintenant remplis.');
  exit(0);
}
