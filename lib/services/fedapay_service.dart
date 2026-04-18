import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Service de paiement FedaPay
/// Documentation : https://docs.fedapay.com
/// FedaPay ne nécessite PAS de Site ID, uniquement la clé secrète.
/// 
/// ⚠️  SÉCURITÉ : Ne jamais écrire votre clé LIVE ici si le code est partagé.
/// En production, utiliser des variables d'environnement ou Firebase Remote Config.
class FedaPayService {
  // ⚠️ SÉCURITÉ : Mode SANDBOX pour les tests.
  // Collez votre clé sk_sandbox ci-dessous.
  static const String _secretKey = "sk_sandbox_pb1JPxfGFD5Z20LTTmBBiqRl";
  static const String _baseUrl = "https://sandbox-api.fedapay.com/v1";

  /// Fonction générant un paiement vers le compte du Collecteur (Payout / Virement)
  Future<bool> sendPayout({
    required double amount,
    required String currency,
    required String operatorName,
    required String phoneNumber,
    required String collectorEmail,
  }) async {
    try {
      String mode = 'wave_ci';
      if (operatorName.toLowerCase().contains('mtn')) mode = 'mtn_ci';
      if (operatorName.toLowerCase().contains('moov')) mode = 'moov_ci';
      if (operatorName.toLowerCase().contains('orange')) mode = 'orange_ci';

      final response = await http.post(
        Uri.parse('$_baseUrl/payouts'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "amount": amount.toInt(),
          "currency": {"iso": currency},
          "mode": mode,
          "customer": {
            "email": collectorEmail,
            "phone_number": {"number": phoneNumber, "country": "CI"}
          }
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final payoutId = data['v1/payout']?['id']?.toString();
        
        if (payoutId != null) {
          // Envoyer l'ordre de virement
          final sendResp = await http.put(
             Uri.parse('$_baseUrl/payouts/$payoutId/send'),
             headers: {'Authorization': 'Bearer $_secretKey'},
          );
          return (sendResp.statusCode == 200);
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

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

  /// Simulation d'un paiement réussi pour la démonstration
  Future<bool> processPayment({
    required BuildContext context,
    required int amount,
    required String description,
    required String customerEmail,
    required String customerName,
  }) async {
    // Simulation d'une attente réseau
    await Future.delayed(const Duration(seconds: 2));
    return true; // Simule toujours un succès
  }
}
