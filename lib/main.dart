import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/booking_provider.dart';
import 'services/firebase_service.dart';
import 'screens/login_screen.dart';
import 'screens/select_account_screen.dart';
import 'screens/rides_screen.dart';
import 'screens/schedules_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/switch_account_screen.dart';
import 'screens/location_test_screen.dart';
import 'services/navigation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (mock or real if configured)
  await FirebaseService().initialize();

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
        routes: {
          '/login': (context) => const LoginScreen(),
          '/select-account': (context) => const SelectAccountScreen(),
          '/home': (context) => const RidesScreen(),
          '/schedules': (context) => const SchedulesScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/switch-account': (context) => const SwitchAccountScreen(),
          '/location-test': (context) => const LocationTestScreen(),
        },
      ),
    );
  }
}
