import 'package:cloud_firestore/cloud_firestore.dart';

enum TicketStatus {
  open,
  inProgress,
  closed,
}

class SupportTicket {
  final String id;
  final String userId; // L'utilisateur qui demande de l'aide
  final String subject;
  final String message;
  final TicketStatus status;
  final DateTime createdAt;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory SupportTicket.fromMap(Map<String, dynamic> data, String documentId) {
    return SupportTicket(
      id: documentId,
      userId: data['userId'] ?? '',
      subject: data['subject'] ?? '',
      message: data['message'] ?? '',
      status: TicketStatus.values.firstWhere(
        (e) => e.toString() == 'TicketStatus.${data['status']}',
        orElse: () => TicketStatus.open,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'subject': subject,
      'message': message,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
