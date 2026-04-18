import 'package:cloud_firestore/cloud_firestore.dart';

enum WasteType {
  frais, // Elevage
  vert,  // Compost
}

enum WasteStatus {
  pending,  // En attente d'un collecteur
  accepted, // En cours de collecte
  completed,// Collecté
  transformedToCompost, // Pour la logique "Frais non récupéré en 3h tourne au vert"
}

class WasteRequest {
  final String id;
  final String restaurateurId;
  final WasteType type;
  final WasteStatus status;
  final DateTime createdAt;
  final GeoPoint location;
  final String? collecteurId;
  final String? preuvePhotoUrl;

  WasteRequest({
    required this.id,
    required this.restaurateurId,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.location,
    this.collecteurId,
    this.preuvePhotoUrl,
  });

  // Logique métier : "Smart Logic"
  // Si le dechet FRAIS n'est pas récupéré en 3 heures, il passe en VERt/COMPOST
  WasteType get currentSmartType {
    if (type == WasteType.frais && status == WasteStatus.pending) {
      final difference = DateTime.now().difference(createdAt);
      if (difference.inHours >= 3) {
        return WasteType.vert; // Bascule en compost pour éviter les odeurs
      }
    }
    return type;
  }

  factory WasteRequest.fromMap(Map<String, dynamic> data, String documentId) {
    return WasteRequest(
      id: documentId,
      restaurateurId: data['restaurateurId'] ?? '',
      type: WasteType.values.firstWhere(
        (e) => e.toString() == 'WasteType.${data['type']}',
        orElse: () => WasteType.vert,
      ),
      status: WasteStatus.values.firstWhere(
        (e) => e.toString() == 'WasteStatus.${data['status']}',
        orElse: () => WasteStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: data['location'] ?? const GeoPoint(0, 0),
      collecteurId: data['collecteurId'],
      preuvePhotoUrl: data['preuvePhotoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'restaurateurId': restaurateurId,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'location': location,
      'collecteurId': collecteurId,
      'preuvePhotoUrl': preuvePhotoUrl,
    };
  }

  WasteRequest copyWith({
    String? id,
    String? restaurateurId,
    WasteType? type,
    WasteStatus? status,
    DateTime? createdAt,
    GeoPoint? location,
    String? collecteurId,
    String? preuvePhotoUrl,
  }) {
    return WasteRequest(
      id: id ?? this.id,
      restaurateurId: restaurateurId ?? this.restaurateurId,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      location: location ?? this.location,
      collecteurId: collecteurId ?? this.collecteurId,
      preuvePhotoUrl: preuvePhotoUrl ?? this.preuvePhotoUrl,
    );
  }
}
