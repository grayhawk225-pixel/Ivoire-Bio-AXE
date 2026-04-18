import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize(String userId) async {
    // 0. Le Web nécessite un setup spécifique (VAPID key + Service Worker)
    // Non requis pour le moment pour le fonctionnement de l'app de démo sur Chrome.
    if (kIsWeb) {
      print('PushNotificationService: Notifications désactivées sur Web.');
      return;
    }

    // 1. Demande de permission
    NotificationSettings settings = await _fcm.requestPermission(

      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Récupération du token
      String? token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToFirestore(userId, token);
      }
    }

    // 3. Configuration Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    // Correction API v21.0.0 : Paramètres nommés requis
    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {},
    );

    // 4. Ecoute des messages en premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

  Future<void> _saveTokenToFirestore(String userId, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'fcmToken': token,
    });
  }

  void _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'chat_messages',
      'Messages de Chat',
      channelDescription: 'Notifications pour les nouveaux messages de chat',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      id: 0,
      title: message.notification?.title ?? 'Nouveau message',
      body: message.notification?.body ?? '',
      notificationDetails: platformChannelSpecifics,
    );
  }
}
