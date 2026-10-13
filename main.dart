import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'start.dart';
import 'notification_page.dart';

// ============================================================
// GLOBALS
// ============================================================

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

// IMPORTANT: Dapat tugma ang channel IDs na ito sa Cloud Function.
const AndroidNotificationChannel level1Channel = AndroidNotificationChannel(
  'motoguard_level1',
  'MotoGuard Security Alerts',
  description: 'Notifications for suspicious motorcycle movement.',
  importance: Importance.high,
  playSound: false,
);

const AndroidNotificationChannel level2Channel = AndroidNotificationChannel(
  'motoguard_level2',
  'MotoGuard Emergency Alerts',
  description: 'Notifications for possible motorcycle accidents.',
  importance: Importance.max,
  playSound: true,
);

bool _notificationsInitialized = false;

// ============================================================
// BACKGROUND HANDLER
// ============================================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('[MotoGuard FCM] Background message: ${message.messageId}');
  // Kapag may "notification" payload, ang system na ang magpapakita nito.
}

// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await _initializeFirebase();

  if (Firebase.apps.isNotEmpty) {
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    await _initializeNotifications();

    // Start the real-time device and history listeners
    // even before the user opens NotificationPage.
    await NotificationService.instance.start();
  }

  runApp(const MyApp());
}

// ============================================================
// FIREBASE INITIALIZATION
// ============================================================

Future<void> _initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    debugPrint('[MotoGuard] Firebase initialized.');
  } catch (e) {
    debugPrint('[MotoGuard] Firebase initialization failed: $e');
  }
}

// ============================================================
// NOTIFICATION INITIALIZATION
// ============================================================

Future<void> _initializeNotifications() async {
  if (_notificationsInitialized) return;
  _notificationsInitialized = true;

  try {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    // Tap sa local notification (kapag nakabukas ang app).
    await localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[MotoGuard] Local notification tapped.');
        _openNotificationPage();
      },
    );

    final androidPlugin =
        localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(level1Channel);
    await androidPlugin?.createNotificationChannel(level2Channel);

    // Android 13+ permission.
    await androidPlugin?.requestNotificationsPermission();

    // iOS / general FCM permission.
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // FCM message received while the app is open.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('[MotoGuard FCM] Foreground message received.');
      await _showForegroundNotification(message);
    });

    // User tapped a push notification while the app was in background.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[MotoGuard FCM] Notification tapped: ${message.data}');
      _openNotificationPage();
    });

    // User opened the app by tapping a notification after termination.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      debugPrint(
        '[MotoGuard FCM] App opened from notification: '
        '${initialMessage.data}',
      );

      // Hintayin munang mag-build ang MaterialApp bago mag-navigate.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 800), () {
          _openNotificationPage();
        });
      });
    }

    // Save token for the current user, if already signed in.
    await _saveFcmTokenForCurrentUser();

    // Save refreshed tokens.
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _saveToken(token);
    });

    // Save token after login (hindi na kailangan i-restart ang app).
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await _saveFcmTokenForCurrentUser();
      }
    });

    debugPrint('[MotoGuard] FCM initialization complete.');
  } catch (e) {
    debugPrint('[MotoGuard] Notification initialization failed: $e');
  }
}

// ============================================================
// NAVIGATION
// ============================================================

void _openNotificationPage() {
  // Huwag mag-navigate kung hindi pa naka-login.
  if (FirebaseAuth.instance.currentUser == null) return;

  final nav = navigatorKey.currentState;
  if (nav == null) return;

  nav.push(
    MaterialPageRoute<void>(
      builder: (_) => const NotificationPage(),
    ),
  );
}

// ============================================================
// SAVE FCM TOKEN TO FIRESTORE
// ============================================================

Future<void> _saveFcmTokenForCurrentUser() async {
  try {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint('[MotoGuard FCM] Waiting for user login.');
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();

    if (token != null && token.isNotEmpty) {
      await _saveToken(token);
    } else {
      debugPrint('[MotoGuard FCM] FCM token is empty.');
    }
  } catch (e) {
    debugPrint('[MotoGuard FCM] Unable to get token: $e');
  }
}

Future<void> _saveToken(String token) async {
  try {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    // 1) Dito binabasa ng Cloud Function: users/{uid}/fcmTokens/{token}
    await userRef.collection('fcmTokens').doc(token).set({
      'token': token,
      'platform': defaultTargetPlatform.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2) Legacy field (para hindi masira ang ibang code mo).
    await userRef.set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('[MotoGuard FCM] Token saved for current user.');
  } catch (e) {
    debugPrint('[MotoGuard FCM] Token save failed: $e');
  }
}

// ============================================================
// SHOW FOREGROUND NOTIFICATION
// ============================================================

Future<void> _showForegroundNotification(
  RemoteMessage message,
) async {
  final data = message.data;

  final eventType =
      (data['eventType'] ?? data['type'] ?? '').toString().toUpperCase();

  final rawLevel = int.tryParse((data['level'] ?? '1').toString()) ?? 1;

  final isLevel2 = rawLevel >= 2 ||
      eventType.contains('ACCIDENT') ||
      eventType.contains('EMERGENCY') ||
      eventType == 'BUZZER_LEVEL2';

  final title = message.notification?.title ??
      (isLevel2 ? 'MotoGuard Emergency Alert' : 'MotoGuard Security Alert');

  final body = message.notification?.body ??
      (isLevel2
          ? 'Possible accident or strong impact detected. Check your motorcycle.'
          : 'Suspicious movement detected on your motorcycle.');

  final channel = isLevel2 ? level2Channel : level1Channel;

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: isLevel2 ? Importance.max : Importance.high,
      priority: isLevel2 ? Priority.max : Priority.high,
      playSound: isLevel2,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    ),
  );

  await localNotifications.show(
    DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
    title,
    body,
    details,
    payload: jsonEncode(data),
  );
}

// ============================================================
// APP
// ============================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'MotoGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050709),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F1318),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.orange),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const StartPage(),
    );
  }
}
