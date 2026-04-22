import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

/// Service de paiement FedaPay
/// Documentation : https://docs.fedapay.com
/// FedaPay ne nécessite PAS de Site ID, uniquement la clé secrète.
/// 
/// ⚠️  SÉCURITÉ : Ne jamais écrire votre clé LIVE ici si le code est partagé.
/// En production, utiliser des variables d'environnement ou Firebase Remote Config.
class FedaPayService {
  // La clé est maintenant stockée dans lib/config/secrets.dart (ignoré par Git)
  static const String _secretKey = Secrets.fedapaySecretKey;
  static const String _baseUrl = "https://api.fedapay.com/v1";

  /// Crée une transaction et retourne l'URL de paiement (redirection vers Wave, MTN, etc.)
  Future<String?> createPaymentLink({
    required double amount,
    required String currency,     // 'XOF' pour le Franc CFA
    required String description,
    required String customerEmail,
    required String customerName,
    String returnUrl = "https://ivoire-bio-axe.ci/paiement/retour",
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/transactions'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "description": description,
          "amount": amount.toInt(),
          "currency": {"iso": currency},
          "callback_url": returnUrl,
          "customer": {
            "email": customerEmail,
            "lastname": customerName,
          },
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final transactionId = data['v1/transaction']?['id']?.toString();
        
        if (transactionId != null) {
          // Générer le lien de paiement depuis l'ID de transaction
          final tokenResponse = await http.post(
            Uri.parse('$_baseUrl/transactions/$transactionId/token'),
            headers: {'Authorization': 'Bearer $_secretKey'},
          );

          if (tokenResponse.statusCode == 200 || tokenResponse.statusCode == 201) {
            final tokenData = jsonDecode(tokenResponse.body);
            return tokenData['url']; // URL de redirection vers Wave/MTN/Orange
          }
        }
      }
      return null;
    } catch (e) {
      throw Exception('Erreur FedaPay: $e');
    }
  }

  /// Vérifie le statut d'une transaction
  Future<String?> checkTransactionStatus(String transactionId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/transactions/$transactionId'),
        headers: {'Authorization': 'Bearer $_secretKey'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['v1/transaction']?['status']; // 'approved', 'declined', 'pending'
      }
      return null;
    } catch (e) {
      throw Exception('Erreur vérification: $e');
    }
  }

  /// [Simulation Démo] Gère le processus de paiement complet
  /// Cette méthode permet de simuler un paiement réussi sans redirection réelle
  /// pour faciliter les tests et démonstrations.
  Future<bool> processPayment({
    required dynamic context,
    required int amount,
    required String description,
    required String customerEmail,
    required String customerName,
  }) async {
    try {
      // Simulation d'un délai réseau/traitement
      await Future.delayed(const Duration(seconds: 2));
      
      // On retourne toujours vrai pour la démonstration
      return true;
    } catch (e) {
      throw Exception('Erreur simulation paiement: $e');
    }
  }
}
