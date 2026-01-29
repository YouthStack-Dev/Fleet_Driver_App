import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import '../config/constants.dart';
import 'firebase_service.dart';
import 'session_service.dart';

class LocationService {
  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();
  final SessionService _sessionService = SessionService();
  
  // Singleton
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;

  bool get isTracking => _isTracking;

  Future<bool> checkPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _logger.w('Location services are disabled.');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _logger.w('Location permissions are denied');
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      _logger.w('Location permissions are permanently denied, we cannot request permissions.');
      return false;
    }

    return true;
  }

  Future<void> startTracking() async {
    if (_isTracking) return;
    
    final hasPermission = await checkPermission();
    if (!hasPermission) return;

    _logger.i('🚀 Starting location tracking');
    _isTracking = true;

    // Configure location settings
    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: LocationConfig.distanceFilterMeters, // 10m
      intervalDuration: const Duration(milliseconds: LocationConfig.updateIntervalMs), // 30s
      // Background config
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: "Driver App Running",
        notificationText: "Tracking location in background",
        enableWakeLock: true,
      ),
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
          _logger.d('📍 New location: ${position.latitude}, ${position.longitude}');
          _updateFirebase(position);
        }, onError: (e) {
          _logger.e('Location stream error: $e');
        });
  }

  Future<void> stopTracking() async {
    _logger.i('🛑 Stopping location tracking');
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isTracking = false;
  }

  Future<void> _updateFirebase(Position position) async {
    try {
      final session = await _sessionService.getSession();
      if (session == null) {
        _logger.w('Skipping Firebase update: No active session');
        return;
      }

      final userData = session['user_data'];
      // Extract IDs (ported logic from original sessionService)
      final String? driverId = userData['driver_id']?.toString() ?? 
                            userData['user']?['driver']?['driver_id']?.toString() ?? 
                            userData['driver']?['driver_id']?.toString();
                            
      final String? tenantId = userData['tenant_id']?.toString() ?? 
                            userData['account']?['tenant_id']?.toString() ??
                            userData['user']?['tenant_id']?.toString() ??
                            userData['user']?['tenant']?['tenant_id']?.toString();
                            
      final String? vendorId = userData['vendor_id']?.toString() ?? 
                            userData['account']?['vendor_id']?.toString() ??
                            userData['user']?['driver']?['vendor_id']?.toString();

      if (driverId != null && tenantId != null && vendorId != null) {
        await _firebaseService.updateDriverLocation(
          tenantId: tenantId,
          vendorId: vendorId,
          driverId: driverId,
          latitude: position.latitude,
          longitude: position.longitude,
          additionalData: {
            'accuracy': position.accuracy,
            'speed': position.speed,
            'heading': position.heading,
            'provider': 'geolocator_flutter'
          }
        );
      } else {
         _logger.w('Skipping Firebase update: Missing IDs (D:$driverId, T:$tenantId, V:$vendorId)');
      }
    } catch (e) {
      _logger.e('Error in _updateFirebase', error: e);
    }
  }
}
