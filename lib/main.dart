import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/booking_provider.dart';
import 'services/firebase_service.dart';
import 'screens/login_screen.dart';

import 'screens/rides_screen.dart';
import 'screens/schedules_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/switch_account_screen.dart';
import 'screens/vendor_select_screen.dart';
import 'screens/location_test_screen.dart';
import 'services/navigation_service.dart';
import 'services/push_notification_service.dart';
import 'package:page_transition/page_transition.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (mock or real if configured)
  await FirebaseService().initialize();
  
  // Initialize Push Notifications (FCM + Local Notifications)
  await PushNotificationService().initialize();

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
        home: const LoginScreen(),
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
