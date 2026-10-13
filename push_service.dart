import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Ang system na mismo ang magpapakita ng notification kapag background/terminated.
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'motoguard_alerts', // dapat kapareho ng channelId sa Cloud Function
    'MotoGuard Alerts',
    description: 'Security and accident alerts from your MotoGuard device',
    importance: Importance.max,
  );

  bool _inited = false;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenSub;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    // 1) Permission (Android 13+ / iOS)
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 2) Local notifications (para lumabas kahit nakabukas ang app)
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3) Foreground messages
    FirebaseMessaging.onMessage.listen(_showForeground);

    // 4) I-save ang token kapag naka-login
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _saveToken(user.uid);
    });

    _tokenSub = _fcm.onTokenRefresh.listen((token) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) _writeToken(uid, token);
    });
  }

  Future<void> _saveToken(String uid) async {
    try {
      final token = await _fcm.getToken();
      if (token != null) await _writeToken(uid, token);
    } catch (e) {
      debugPrint('[MotoGuard] FCM token error: $e');
    }
  }

  Future<void> _writeToken(String uid, String token) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .doc(token)
        .set({
      'token': token,
      'platform': defaultTargetPlatform.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[MotoGuard] FCM token saved');
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;

    await _local.show(
      message.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _tokenSub?.cancel();
  }
}
