import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as io;
import 'dart:convert';

/// Service gérant le stockage des fichiers sur Firebase Storage.
/// Optimisé pour être robuste face aux coupures réseau (Retries & Timeouts).
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload une photo et retourne son URL de téléchargement.
  Future<String> uploadWastePhoto({
    required XFile file,
    required String restaurateurId,
  }) async {
    final String path = 'waste_photos/$restaurateurId/${const Uuid().v4()}.jpg';
    return await _uploadGeneric(file: file, path: path);
  }

  Future<List<String>> uploadMultiplePhotos({
    required List<XFile> files,
    required String userId,
    required String folder,
  }) async {
    final List<String> urls = [];
    for (var file in files) {
      final url = await _uploadGeneric(file: file, path: '$folder/$userId/${const Uuid().v4()}.jpg');
      urls.add(url);
    }
    return urls;
  }

  /// Upload spécifique pour le chat
  Future<String> uploadChatPhoto({required XFile file, required String requestId}) async {
    final String path = 'chat_photos/$requestId/${const Uuid().v4()}.jpg';
    return await _uploadGeneric(file: file, path: path);
  }

  /// Upload spécifique pour le support
  Future<String> uploadSupportPhoto({required XFile file, required String userId}) async {
    final String path = 'support_photos/$userId/${const Uuid().v4()}.jpg';
    return await _uploadGeneric(file: file, path: path);
  }

  /// Méthode générique d'upload avec retries
  Future<String> _uploadGeneric({required XFile file, required String path}) async {
    final ref = _storage.ref().child(path);
    int attempts = 0;
    const int maxAttempts = 3;

    while (attempts < maxAttempts) {
      attempts++;
      try {
        final metadata = SettableMetadata(contentType: 'image/jpeg');
        debugPrint('️[Storage] DEBUT Tentative $attempts/3: $path');
        
        final List<int> bytes = await file.readAsBytes();
        final uploadTask = kIsWeb 
          ? ref.putString(base64Encode(bytes), format: PutStringFormat.base64, metadata: metadata)
          : ref.putFile(io.File(file.path), metadata);

        // Monitoring du progrès
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = 100.0 * (snapshot.bytesTransferred / snapshot.totalBytes);
          debugPrint('️[Storage] Progrès: ${progress.toStringAsFixed(1)}%');
        }, onError: (e) => debugPrint('❌ [Storage] Erreur Stream: $e'));

        await uploadTask;
        
        debugPrint('️[Storage] Upload fini, récupération URL...');
        await Future.delayed(const Duration(seconds: 2));
        
        final url = await ref.getDownloadURL();
        debugPrint('🚀 [Storage] URL OK: $url');
        return url;
      } on FirebaseException catch (fe) {
        debugPrint('❌ [Storage] FirebaseError [${fe.code}]: ${fe.message}');
        if (attempts >= maxAttempts) rethrow;
      } catch (e) {
        debugPrint('❌ [Storage] Erreur fatale: $e');
        if (attempts >= maxAttempts) rethrow;
      }
      await Future.delayed(Duration(seconds: 2 * attempts));
    }
    throw Exception('Échec après plusieurs tentatives.');
  }
}
