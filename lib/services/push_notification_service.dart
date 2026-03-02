import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'dart:io';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final Logger _logger = Logger();

  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _fcm.setAutoInitEnabled(true);
      
      // 1. Request Permission (Required for iOS, good practice for Android 13+)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      _logger.d('User granted permission: ${settings.authorizationStatus}');

      // 2. Initialize Local Notifications (For Foreground)
      const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
      const InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
      
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Create Android Channel
      if (Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'high_importance_channel', // id
          'High Importance Notifications', // title
          description: 'This channel is used for important notifications.', // description
          importance: Importance.max,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      // 3. Listen to Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _logger.i('Got a message whilst in the foreground!');
        _logger.i('Message data: ${message.data}');

        if (message.notification != null) {
          _logger.i('Message also contained a notification: ${message.notification}');
          _showLocalNotification(message);
        }
      });

      _initialized = true;
      _logger.i('✅ Push Notification Service Initialized');
    } catch (e) {
      _logger.e('❌ Failed to initialize push notifications: $e');
    }
  }

  Future<String?> getToken() async {
    for (int i = 0; i < 3; i++) {
      try {
        if (i > 0) {
          _logger.w('Retrying FCM Token fetch... (attempt ${i + 1})');
          await Future.delayed(const Duration(seconds: 2));
        }
        String? token = await _fcm.getToken();
        if (token != null) return token;
      } catch (e) {
        _logger.e('Failed to get FCM token on attempt ${i + 1}: $e');
      }
    }
    return null;
  }

  void _showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null && Platform.isAndroid) {
      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    } else if (notification != null && Platform.isIOS) {
       _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle tap if needed (e.g. navigate to trips screen)
    _logger.i('Notification tapped: ${response.payload}');
  }
}
