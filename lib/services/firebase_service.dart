import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../config/constants.dart';

class FirebaseService {
  final Logger _logger = Logger();
  final Dio _dio = Dio(); // Separate Dio instance for raw Firebase calls
  
  // Singleton
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  DatabaseReference? _dbRef;
  bool _isSdkAvailable = false;

  Future<void> initialize() async { 
    try {
      // Initialize Firebase without manual options. 
      // This forces the use of google-services.json (Android) or GoogleService-Info.plist (iOS).
      // Required for Firebase Cloud Messaging.
      await Firebase.initializeApp(); 
      _dbRef = FirebaseDatabase.instance.ref();
      _isSdkAvailable = true;
      _logger.i('✅ Firebase SDK initialized successfully from config files');
    } catch (e) {
       // If init fails
       if (Firebase.apps.isNotEmpty) {
           _dbRef = FirebaseDatabase.instance.ref();
           _isSdkAvailable = true;
           _logger.i('✅ Firebase SDK already initialized');
       } else {
          _logger.w('⚠️ Firebase SDK init failed: $e. Using HTTP fallback.');
          _isSdkAvailable = false;
       }
    }
  }

  Future<Map<String, dynamic>> updateDriverLocation({
    required String tenantId,
    required String vendorId,
    required String driverId,
    required double latitude,
    required double longitude,
    Map<String, dynamic> additionalData = const {},
  }) async {
    final locationData = {
      'driver_id': driverId,
      'latitude': latitude,
      'longitude': longitude,
      'updated_at': DateTime.now().toIso8601String(),
      ...additionalData
    };

    final path = 'drivers/$tenantId/$vendorId/$driverId';

    // Try SDK First
    if (_isSdkAvailable && _dbRef != null) {
      try {
        await _dbRef!.child(path).set(locationData);
        _logger.d('✅ Location updated via SDK: $path');
        return {'success': true, 'method': 'SDK'};
      } catch (e) {
        _logger.w('⚠️ SDK update failed: $e. Switching to HTTP fallback.');
        // Proceed to fallback
      }
    }

    // HTTP Fallback
    try {
      final url = '${FirebaseConfig.databaseUrl}/$path.json';
      _logger.d('🔄 Attempting HTTP fallback: $url');
      
      await _dio.put(url, data: locationData);
      
      _logger.d('✅ Location updated via HTTP');
      return {'success': true, 'method': 'HTTP'};
    } catch (e) {
      _logger.e('❌ All Firebase update methods failed', error: e);
      return {'success': false, 'error': e.toString()};
    }
  }
}
