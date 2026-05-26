import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'api_client.dart';
import 'navigation_service.dart';
import '../config/constants.dart';

/// Background message handler — must be a top-level function.
///
/// Firebase requires this to be annotated and top-level (not a class method).
/// It runs in a separate Dart isolate; no UI or provider access is possible here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised before this runs.
  // The OS shows the notification automatically when the message contains a
  // notification payload — no extra work is needed here.
  Logger().d('Background FCM message received: ${message.messageId}');
}

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final Logger _logger = Logger();

  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Initialise
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _fcm.setAutoInitEnabled(true);

      // 1. Request permission (required on iOS; good practice on Android 13+).
      final NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _logger.d('FCM permission: ${settings.authorizationStatus}');

      // 2. Set up local notifications (used for foreground messages).
      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosInit =
          DarwinInitializationSettings();
      const InitializationSettings initSettings =
          InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Create the high-importance Android notification channel.
      if (Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'Used for important notifications.',
          importance: Importance.max,
        );
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      // 3. Foreground message handler.
      //    Only acts on chat_message type.
      //    Suppresses the banner if the driver already has that chat screen open
      //    (the RTDB listener delivers the message instantly — no banner needed).
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _logger.i('Foreground FCM: ${message.data}');

        final type = message.data['type'] as String?;
        if (type == 'chat_message') {
          final rawId = message.data['booking_id'];
          final bookingId =
              rawId != null ? int.tryParse(rawId.toString()) : null;

          if (bookingId != null && NavigationService.isChatOpen(bookingId)) {
            _logger.i(
                'Chat screen open for booking $bookingId — suppressing banner.');
            return;
          }
        }

        // Show a local banner for all other cases (non-chat or chat with screen closed).
        if (message.notification != null) {
          _showLocalNotification(message);
        }
      });

      // 4. Background → foreground tap handler.
      //    Fires when the driver taps an OS notification while the app is running
      //    in the background but not terminated.
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _logger.i('App foregrounded via notification tap: ${message.data}');
        _navigateToChatFromData(message.data);
      });

      // 5. Token-refresh listener.
      //    Firebase periodically rotates the FCM token. Re-register it so the
      //    backend always has a valid token to send push notifications to.
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        _logger.i('🔄 FCM token refreshed — re-registering with backend');
        await _doRegisterToken(newToken);
      });

      _initialized = true;
      _logger.i('✅ PushNotificationService initialised');
    } catch (e) {
      _logger.e('❌ PushNotificationService init failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Token registration
  // ---------------------------------------------------------------------------

  /// Registers the current FCM token with the backend.
  ///
  /// Call this:
  ///   • Immediately after a successful login (selectTenant).
  ///   • When restoring a saved session on app start.
  ///
  /// Token-refresh is handled automatically via the [onTokenRefresh] listener
  /// set up in [initialize].
  Future<void> registerWithBackend() async {
    try {
      final token = await getToken();
      if (token == null) {
        _logger.w('registerWithBackend: FCM token unavailable — skipping');
        return;
      }
      await _doRegisterToken(token);
    } catch (e) {
      // Non-fatal — log and continue.  The next login will retry.
      _logger.e('registerWithBackend failed: $e');
    }
  }

  /// Internal helper — POSTs [token] to the backend registration endpoint.
  Future<void> _doRegisterToken(String token) async {
    try {
      await ApiClient().client.post(
        ApiEndpoints.fcmTokenRegister,
        data: {
          'fcm_token': token,
          'platform': 'app',
          'device_type': Platform.isAndroid ? 'android' : 'ios',
        },
      );
      _logger.i('✅ FCM token registered with backend');
    } on Exception catch (e) {
      // Non-fatal — token will be re-registered on next login/refresh.
      _logger.w('_doRegisterToken failed (will retry on next login): $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Initial-message (terminated-state launch)
  // ---------------------------------------------------------------------------

  /// Call once after [runApp] to handle a notification tap that cold-launched
  /// the app from a terminated state.
  Future<void> handleInitialMessage() async {
    final RemoteMessage? initial = await _fcm.getInitialMessage();
    if (initial != null) {
      _logger.i('App cold-launched via notification: ${initial.data}');
      // Small delay to let the navigator settle after startup.
      await Future.delayed(const Duration(milliseconds: 500));
      _navigateToChatFromData(initial.data);
    }
  }

  // ---------------------------------------------------------------------------
  // FCM token retrieval
  // ---------------------------------------------------------------------------

  Future<String?> getToken() async {
    for (int i = 0; i < 3; i++) {
      try {
        if (i > 0) {
          _logger.w('Retrying FCM token fetch (attempt ${i + 1})');
          await Future.delayed(const Duration(seconds: 2));
        }
        final token = await _fcm.getToken();
        if (token != null) return token;
      } catch (e) {
        _logger.e('FCM token fetch attempt ${i + 1} failed: $e');
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Local notification display
  // ---------------------------------------------------------------------------

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;

    // Encode booking_id / passenger_name so _onNotificationTap can navigate
    // to the correct chat screen.
    final payloadMap = <String, dynamic>{};
    final bookingId = message.data['booking_id'];
    final passengerName = message.data['passenger_name'];
    if (bookingId != null) payloadMap['booking_id'] = bookingId;
    if (passengerName != null) payloadMap['passenger_name'] = passengerName;
    final payload = payloadMap.isNotEmpty ? jsonEncode(payloadMap) : null;

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
        payload: payload,
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
        payload: payload,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Notification tap handling
  // ---------------------------------------------------------------------------

  void _onNotificationTap(NotificationResponse response) {
    _logger.i('Notification tapped: ${response.payload}');
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateToChatFromData(data);
      } catch (e) {
        _logger.e('Failed to parse notification payload: $e');
      }
    }
  }

  /// Pushes the `/chat` route using the global navigator key.
  /// Works from any context — including background isolates that have been
  /// brought to the foreground.
  void _navigateToChatFromData(Map<String, dynamic> data) {
    final rawId = data['booking_id'];
    if (rawId == null) return;

    final bookingId = rawId is int ? rawId : int.tryParse(rawId.toString());
    if (bookingId == null) return;

    final passengerName = data['passenger_name'] as String?;

    _logger.i('Navigating to /chat for booking $bookingId');
    NavigationService.navigatorKey.currentState?.pushNamed(
      '/chat',
      arguments: {
        'booking_id': bookingId,
        'passenger_name': passengerName,
      },
    );
  }
}
