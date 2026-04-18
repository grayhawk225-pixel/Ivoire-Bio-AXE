import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/foundation.dart';

class EmailService {
  // ==========================================
  // TODO: GESTIONNAIRE ! MODIFIEZ CECI !
  // Il faut utiliser un Mot de passe d'application Gmail 
  // (Pas le vrai mot de passe de votre compte email)
  // ==========================================
  static const String _username = 'ivoire.bioaxe@gmail.com'; 
  static const String _password = 'fywz nijc gsad asbq';

  static Future<bool> sendWelcomeEmail({required String toEmail, required String role}) async {
    try {
      final smtpServer = gmail(_username, _password);
      
      String roleTitle = "Utilisateur";
      if (role.toLowerCase() == "restaurateur") roleTitle = "Générateur";
      if (role.toLowerCase() == "collecteur") roleTitle = "Collecteur";
      if (role.toLowerCase() == "acheteur") roleTitle = "Acheteur";

      final htmlContent = """
        <div style="font-family: Arial, sans-serif; text-align: center; color: #333; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 12px; background-color: #ffffff;">
          <div style="background-color: #4CAF50; padding: 20px; border-radius: 10px 10px 0 0;">
             <h1 style="color: white; margin: 0;">Ivoire Bio-Axe 🌱</h1>
          </div>
          <h2 style="color: #2E7D32; margin-top: 24px;">🎉 Bienvenue parmi nous !</h2>
          <p style="font-size: 16px;">Bonjour,</p>
          <p style="font-size: 16px; line-height: 1.5;">Nous sommes ravis de vous compter parmi nos membres. Votre profil <strong>$roleTitle</strong> a été créé avec succès et est maintenant actif sur l'application.</p>
          
          <div style="margin: 30px 0; padding: 15px; background-color: #E8F5E9; border-radius: 8px;">

            <p style="font-size: 14px; margin: 0; color: #2E7D32;">Ensemble, transformons nos déchets cellulaires en ressources vertes ♻️ pour une Côte d'Ivoire plus propre !</p>
          </div>
          
          <p style="font-size: 14px; color: #777;">Si vous n'êtes pas l'auteur de cette inscription, veuillez ignorer et supprimer ce message.</p>
          <hr style="border: 0; height: 1px; background: #ddd; margin: 30px 0;" />
          <p style="font-size: 12px; color: #999;">L'équipe Ivoire Bio-Axe<br>Abidjan, Côte d'Ivoire</p>
        </div>
      """;

      final message = Message()
        ..from = const Address(_username, 'Ivoire Bio-Axe')
        ..recipients.add(toEmail)
        ..subject = 'Bienvenue sur Ivoire Bio-Axe 🌱'
        ..html = htmlContent;

      await send(message, smtpServer);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print("Erreur critique d'envoi SMTP : \$e");
      }
      return false;
    }
  }
  static Future<bool> sendPasswordResetCode({required String toEmail, required String code}) async {
    try {
      final smtpServer = gmail(_username, _password);
      
      final htmlContent = """
        <div style="font-family: Arial, sans-serif; text-align: center; color: #333; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 12px; background-color: #ffffff;">
          <div style="background-color: #2196F3; padding: 20px; border-radius: 10px 10px 0 0;">
             <h1 style="color: white; margin: 0;">Sécurité Compte 🌱</h1>
          </div>
          <h2 style="color: #1976D2; margin-top: 24px;">Code de Réinitialisation</h2>
          <p style="font-size: 16px;">Bonjour,</p>
          <p style="font-size: 16px; line-height: 1.5;">Vous avez demandé la réinitialisation de votre mot de passe pour votre compte Ivoire Bio-Axe.</p>
          
          <div style="margin: 30px 0; padding: 20px; background-color: #E3F2FD; border-radius: 8px;">
            <p style="font-size: 32px; font-weight: bold; margin: 0; color: #1976D2; letter-spacing: 10px;">$code</p>
          </div>
          
          <p style="font-size: 14px; color: #777;">Ce code est valable pendant 15 minutes. Si vous n'avez pas demandé ce code, veuillez ignorer ce message de sécurité.</p>
          <hr style="border: 0; height: 1px; background: #ddd; margin: 30px 0;" />
          <p style="font-size: 12px; color: #999;">L'équipe Sécurité Ivoire Bio-Axe<br>Abidjan, Côte d'Ivoire</p>
        </div>
      """;

      final message = Message()
        ..from = const Address(_username, 'Ivoire Bio-Axe')
        ..recipients.add(toEmail)
        ..subject = 'Votre code de réinitialisation Ivoire Bio-Axe'
        ..html = htmlContent;

      await send(message, smtpServer);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print("Erreur critique d'envoi SMTP (Reset) : $e");
      }
      return false;
    }
  }
}
