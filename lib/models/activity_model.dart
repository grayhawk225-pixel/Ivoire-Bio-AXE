import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityType {
  collection, // Collecte de déchets
  purchase,   // Achat de compost/frais
  payout,     // Retrait de fonds
}

enum ActivityStatus {
  pending,
  success,
  cancelled,
  failed,
}

class Activity {
  final String id;
  final String userId;
  final ActivityType type;
  final ActivityStatus status;
  final String title;
  final String description;
  final double amount;
  final DateTime timestamp;
  final Map<String, dynamic> metadata; // Infos spécifiques (ID transaction, Photo, Opérateur)

  Activity({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.title,
    required this.description,
    required this.amount,
    required this.timestamp,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.name,
      'status': status.name,
      'title': title,
      'description': description,
      'amount': amount,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }

  factory Activity.fromMap(Map<String, dynamic> data, String docId) {
    return Activity(
      id: docId,
      userId: data['userId'] ?? '',
      type: ActivityType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () {
          final str = data['type']?.toString() ?? '';
          return ActivityType.values.firstWhere(
            (e) => e.toString() == 'ActivityType.$str' || e.name == str,
            orElse: () => ActivityType.collection,
          );
        },
      ),
      status: ActivityStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () {
          final str = data['status']?.toString() ?? '';
          return ActivityStatus.values.firstWhere(
            (e) => e.toString() == 'ActivityStatus.$str' || e.name == str,
            orElse: () => ActivityStatus.success,
          );
        },
      ),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] ?? {},
    );
  }
}

