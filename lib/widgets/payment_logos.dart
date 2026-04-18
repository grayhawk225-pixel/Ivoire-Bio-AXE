import 'package:flutter/material.dart';

class PaymentLogos {
  static Widget getLogo(String operatorName, {double size = 40}) {
    String imagePath = '';
    if (operatorName.contains('Wave')) {
      imagePath = 'assets/images/wave.png';
    } else if (operatorName.contains('MTN')) {
      imagePath = 'assets/images/mtn.png';
    } else if (operatorName.contains('Orange')) {
      imagePath = 'assets/images/orange.png';
    } else if (operatorName.contains('Moov')) {
      imagePath = 'assets/images/moov.png';
    } else {
      return Icon(Icons.account_balance_wallet, size: size, color: Colors.grey);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.15),
      child: Image.asset(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Fallback en cas d'erreur de chargement (fichier introuvable)
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Erreur chargement asset: $imagePath');
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(size * 0.15),
            ),
            child: Icon(Icons.image_not_supported, size: size * 0.5, color: Colors.grey),
          );
        },
      ),
    );
  }
}
