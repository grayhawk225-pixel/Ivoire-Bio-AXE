import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload une photo de déchets et retourne l'URL de téléchargement
  /// [file]           : fichier image local
  /// [restaurateurId] : UID du restaurateur (pour organiser le stockage)
  Future<String> uploadWastePhoto({
    required File file,
    required String restaurateurId,
  }) async {
    final String fileName = '${const Uuid().v4()}.jpg';
    final String path = 'waste_photos/$restaurateurId/$fileName';

    final ref = _storage.ref().child(path);

    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final downloadUrl = await uploadTask.ref.getDownloadURL();
    return downloadUrl;
  }
}
