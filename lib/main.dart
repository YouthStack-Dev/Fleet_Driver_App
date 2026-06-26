import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/chat_provider.dart';
import 'services/firebase_service.dart';
import 'screens/login_screen.dart';

import 'screens/rides_screen.dart';
import 'screens/schedules_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/switch_account_screen.dart';
import 'screens/vendor_select_screen.dart';
import 'screens/location_test_screen.dart';
import 'screens/chat_screen.dart';
import 'services/navigation_service.dart';
import 'services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:page_transition/page_transition.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Register the background FCM handler BEFORE Firebase is initialised.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Firebase (mock or real if configured)
  await FirebaseService().initialize();
  
  // Initialize Push Notifications (FCM + Local Notifications + tap handlers)
  await PushNotificationService().initialize();

  // Handle tap on notification that launched the app from terminated state.
  // Must run after initialize() so the navigator is ready.
  PushNotificationService().handleInitialMessage();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'Driver App',
        navigatorKey: NavigationService.navigatorKey, // Add global key
        theme: ThemeData(
          scaffoldBackgroundColor: Colors.white, // Pure White Background
          primarySwatch: Colors.deepPurple,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white, // White Header
            foregroundColor: Colors.black, // Black Text/Icons
            elevation: 0,
            titleTextStyle: TextStyle(
              color: Colors.black,
              fontSize: 24, // Larger
              fontWeight: FontWeight.w900, // Extra Bold
              letterSpacing: 0.8,
            ),
            // Removed rounded shape for glass effect compatibility
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        home: const AuthWrapper(),
        onGenerateRoute: (settings) {
          Widget page;
          switch (settings.name) {
            case '/login':
              page = const LoginScreen();
              break;
            case '/home':
              page = const RidesScreen();
              break;
            case '/schedules':
              page = const SchedulesScreen();
              break;
            case '/profile':
              page = const ProfileScreen();
              break;
            case '/switch-account':
              page = const SwitchAccountScreen();
              break;
            case '/vendor-select':
              page = VendorSelectScreen(licenseNumber: settings.arguments as String);
              break;
            case '/location-test':
              page = const LocationTestScreen();
              break;
            case '/chat':
              final args =
                  settings.arguments as Map<String, dynamic>? ?? {};
              page = ChatScreen(
                bookingId: args['booking_id'] as int,
                passengerName: args['passenger_name'] as String?,
                firebasePath: args['firebase_path'] as String?,
              );
              break;
            default:
              page = const LoginScreen();
          }
          return PageTransition(
            child: page,
            type: PageTransitionType.fade, // Smooth fade for all global routes
            settings: settings,
            duration: const Duration(milliseconds: 300),
            reverseDuration: const Duration(milliseconds: 300),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.unknown:
            return const Scaffold(
              backgroundColor: Color(0xFF051424),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2E7CFF),
                  strokeWidth: 3,
                ),
              ),
            );
          case AuthStatus.authenticated:
            return const RidesScreen();
          case AuthStatus.tempAuthenticated:
            final licenseNumber = auth.currentUser?['driver']?['license_number'] ?? 
                                  auth.currentUser?['user']?['driver']?['license_number'] ?? 
                                  auth.currentUser?['license_number'] ??
                                  auth.driver?['license_number'] ?? 'LC123456';
            return VendorSelectScreen(licenseNumber: licenseNumber);
          case AuthStatus.unauthenticated:
            return const LoginScreen();
        }
      },
    );
  }
}
