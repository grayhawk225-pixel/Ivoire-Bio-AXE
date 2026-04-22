import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/waste_request_model.dart';
import '../models/support_ticket_model.dart';
import '../models/activity_model.dart';
import '../models/chat_message_model.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(FirebaseFirestore.instance);
});

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService(this._db);

  // ---------- USERS ----------

  Future<AppUser?> getUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Erreur lors de la récupération de l\'utilisateur: $e');
    }
  }

  Future<void> updateUser(AppUser user) async {
    await _db.collection('users').doc(user.id).update(user.toMap());
  }

  Stream<AppUser?> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return AppUser.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }


  // ---------- WASTE REQUESTS ----------

  Future<void> createWasteRequest(WasteRequest request) async {
    await _db.collection('waste_requests').doc().set(request.toMap());
  }

  Stream<List<WasteRequest>> getPendingWasteRequests() {
    return _db
        .collection('waste_requests')
        .where('status', isEqualTo: WasteStatus.pending.toString().split('.').last)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WasteRequest.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<WasteRequest>> getRestaurateurRequests(String restaurateurId) {
    return _db
        .collection('waste_requests')
        .where('restaurateurId', isEqualTo: restaurateurId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WasteRequest.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> updateWasteRequestStatus(String requestId, WasteStatus newStatus, {String? collecteurId, List<String>? photoUrls, WasteType? newType}) async {
    final Map<String, dynamic> updates = {
      'status': newStatus.toString().split('.').last,
    };
    if (collecteurId != null) updates['collecteurId'] = collecteurId;
    if (photoUrls != null) updates['preuvePhotosUrls'] = photoUrls;
    if (newType != null) updates['type'] = newType.toString().split('.').last;

    await _db.collection('waste_requests').doc(requestId).update(updates);
  }

  // ---------- SUPPORT TICKETS ----------

  Future<void> createSupportTicket(SupportTicket ticket) async {
    await _db.collection('support_tickets').doc().set(ticket.toMap());
  }

  Stream<List<SupportTicket>> getAdminSupportTickets() {
    return _db
        .collection('support_tickets')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SupportTicket.fromMap(doc.data(), doc.id))
            .toList());
  }
  // ---------- MISC / NOUVELLES OPTIONS ----------

  Future<void> saveResetCode(String email, String code) async {
    await _db.collection('password_resets').doc(email).set({
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> verifyResetCode(String email, String code) async {
    final doc = await _db.collection('password_resets').doc(email).get();
    if (!doc.exists) return false;
    
    final data = doc.data()!;
    final savedCode = data['code'];
    final createdAt = (data['createdAt'] as Timestamp).toDate();
    
    // Validité 15 minutes
    if (DateTime.now().difference(createdAt).inMinutes > 15) return false;
    
    return savedCode == code;
  }

  Future<void> updateCollectorLocation(String uid, double lat, double lng) async {
    await _db.collection('users').doc(uid).update({
      'currentLocation': GeoPoint(lat, lng),
      'lastLocationUpdate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelWasteRequest(String requestId, UserRole role, String userId) async {
    if (role == UserRole.restaurateur) {
      // Le générateur annule complètement sa demande
      await _db.collection('waste_requests').doc(requestId).delete();
    } else if (role == UserRole.collecteur) {
      // Le collecteur abandonne la mission, elle redevient "pending"
      await _db.collection('waste_requests').doc(requestId).update({
        'status': WasteStatus.pending.toString().split('.').last,
        'collecteurId': null,
      });
    }
  }

  Future<void> deleteUserAccountData(String uid) async {
    // Suppression des données dans Firestore
    await _db.collection('users').doc(uid).delete();
  }

  // ---------- HISTORIQUE D'ACTIVITÉS ----------

  Future<void> logActivity(Activity activity) async {
    await _db.collection('activities').add(activity.toMap());
  }

  Stream<List<Activity>> getUserActivities(String userId) {
    return _db.collection('activities')
      .where('userId', isEqualTo: userId)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => Activity.fromMap(doc.data(), doc.id))
        .toList());
  }

  // ---------- CHAT MESSAGES ----------

  Future<void> sendChatMessage(ChatMessage message) async {
    await _db.collection('chat_messages').add(message.toMap());
  }

  Stream<List<ChatMessage>> getChatMessages(String requestId) {
    return _db.collection('chat_messages')
      .where('requestId', isEqualTo: requestId)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
        .toList());
  }

  /// Retourne le nombre de messages non lus pour une requête donnée
  Stream<int> getUnreadChatCountStream(String requestId, String currentUserId) {
    return _db.collection('chat_messages')
      .where('requestId', isEqualTo: requestId)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .where((doc) => doc.data()['senderId'] != currentUserId)
        .length);
  }

  /// Marque les messages reçus comme lus
  Future<void> markChatMessagesAsRead(String requestId, String currentUserId) async {
    final snapshot = await _db.collection('chat_messages')
      .where('requestId', isEqualTo: requestId)
      .where('isRead', isEqualTo: false)
      .get();

    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      if (doc.data()['senderId'] != currentUserId) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }
}

