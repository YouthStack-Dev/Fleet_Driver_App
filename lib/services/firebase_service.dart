import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logger/logger.dart';

class FirebaseService {
  final Logger _logger = Logger();

  // Singleton
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  DatabaseReference? _dbRef;
  bool _isSdkAvailable = false;

  /// Call once during app startup (before any RTDB reads).
  Future<void> initialize() async {
    try {
      // Initialize Firebase without manual options.
      // This forces the use of google-services.json (Android) or
      // GoogleService-Info.plist (iOS).
      // Required for Firebase Cloud Messaging.
      await Firebase.initializeApp();
      _dbRef = FirebaseDatabase.instance.ref();
      _isSdkAvailable = true;
      _logger.i('✅ Firebase SDK initialized successfully from config files');
    } catch (e) {
      if (Firebase.apps.isNotEmpty) {
        _dbRef = FirebaseDatabase.instance.ref();
        _isSdkAvailable = true;
        _logger.i('✅ Firebase SDK already initialized');
      } else {
        _logger.w('⚠️ Firebase SDK init failed: $e');
        _isSdkAvailable = false;
      }
    }
  }

  /// Returns the root DatabaseReference for RTDB reads (e.g., chat listeners).
  /// Returns null if Firebase failed to initialise.
  DatabaseReference? get databaseRef => _isSdkAvailable ? _dbRef : null;
}
