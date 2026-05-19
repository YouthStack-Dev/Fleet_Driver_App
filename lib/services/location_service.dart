import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import '../config/constants.dart';
import 'firebase_service.dart';
import 'session_service.dart';
import 'driver_config_service.dart';
import 'speed_violation_service.dart';

class LocationService {
  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();
  final SessionService _sessionService = SessionService();
  final DriverConfigService _driverConfigService = DriverConfigService();
  final SpeedViolationService _speedViolationService = SpeedViolationService();

  // Singleton
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;
  // Guard against concurrent async calls to startTracking() racing past the
  // `if (_isTracking) return;` check before the flag is set.
  bool _startingTracking = false;

  // Throttle Firebase writes — GPS ticks every 1 s but Firebase only needs 30 s
  DateTime? _lastFirebaseUpdate;

  // Track whether driver was previously over the limit so we can detect when
  // they slow back down and reset the violation cooldown.
  bool _wasOverLimit = false;

  // Broadcast stream — consumed by LocationProvider for live speed display
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  // Broadcast stream — lets LocationProvider know the moment tracking starts/stops
  final StreamController<bool> _trackingStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get trackingStateStream => _trackingStateController.stream;

  /// The currently-active route ID for speed-violation reporting.
  /// Set via LocationProvider.setActiveRoute(); null disables checks.
  String? _activeRouteId;
  String? get activeRouteId => _activeRouteId;
  set activeRouteId(String? value) {
    _activeRouteId = value;
    if (value != null) {
      _speedViolationService.resetCooldown();
      _wasOverLimit = false;
    }
  }

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
      _logger.w('Location permissions permanently denied.');
      return false;
    }

    return true;
  }

  Future<void> startTracking() async {
    if (_isTracking || _startingTracking) return;
    _startingTracking = true;

    final hasPermission = await checkPermission();
    if (!hasPermission) {
      _startingTracking = false;
      return;
    }

    _logger.i('🚀 Starting location tracking');
    _isTracking = true;
    _startingTracking = false;
    _lastFirebaseUpdate = null;
    _wasOverLimit = false;
    _trackingStateController.add(true); // HUD appears immediately in UI

    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      // distanceFilter 0 = emit on every interval tick regardless of movement
      distanceFilter: LocationConfig.distanceFilterMeters, // 0
      // GPS ticks every 1 second — live speed display
      intervalDuration:
          const Duration(milliseconds: LocationConfig.updateIntervalMs), // 1 s
      // ForegroundNotificationConfig re-enabled after patching
      // GeolocatorLocationService.java to call:
      //   startForeground(id, notification, FOREGROUND_SERVICE_TYPE_LOCATION)
      // on API 29+ (Android 10+). Without the type flag, Android 14 blocks
      // all location delivery from the foreground service.
      // enableWakeLock keeps the CPU awake for reliable GPS delivery.
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Location Tracking Active',
        notificationText: 'Driver app is monitoring your speed.',
        enableWakeLock: true,
      ),
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        final kmh = (position.speed < 0 ? 0.0 : position.speed) * 3.6;
        _logger.d('📍 New location: ${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)} | '
            '${kmh.toStringAsFixed(1)} km/h | acc: ${position.accuracy.toStringAsFixed(0)} m');

        // 1. Push to UI (live speed HUD updates every ~1 s)
        _positionController.add(position);

        // 2. Write to Firebase RTDB — throttled to once every 30 s
        _maybeUpdateFirebase(position);

        // 3. Speed-limit check — trigger / reset violation as needed
        _checkSpeedViolation(position);
      },
      onError: (e) {
        _logger.e('Location stream error: $e');
        // Reset tracking state so the next startTracking() call can retry.
        _isTracking = false;
        _trackingStateController.add(false);
      },
      onDone: () {
        // Stream closed (e.g., geolocator service restarted or permission revoked).
        // Reset so callers can restart.
        _logger.w('Location stream closed unexpectedly — resetting tracking state');
        _isTracking = false;
        _trackingStateController.add(false);
      },
    );
    _logger.i('✅ GPS stream subscription created');
  }

  Future<void> stopTracking() async {
    _logger.i('🛑 Stopping location tracking');
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isTracking = false;
    _activeRouteId = null;
    _wasOverLimit = false;
    _trackingStateController.add(false);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _checkSpeedViolation(Position position) {
    if (_activeRouteId == null) return;

    // position.speed is -1.0 when GPS fix not yet acquired — clamp to 0
    final speedKmph = (position.speed < 0 ? 0.0 : position.speed) * 3.6;
    final limit = _driverConfigService.config.speedLimitKmph;

    if (speedKmph > limit) {
      // OVER the limit
      // reportViolation() internally handles the 30-second repeat window:
      //   - First call while over limit  → fires immediately
      //   - Subsequent calls within 30 s → silently dropped
      //   - After 30 s of continuous speeding → fires again
      _speedViolationService.reportViolation(
        routeId: _activeRouteId!,
        speedKmph: speedKmph,
        speedLimitKmph: limit,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _wasOverLimit = true;
    } else {
      // UNDER the limit
      if (_wasOverLimit) {
        // Driver just slowed down — reset cooldown so the NEXT overspeed
        // triggers a fresh immediate alert rather than waiting out the old timer
        _speedViolationService.resetCooldown();
        _logger.d('Speed back under limit — violation cooldown reset');
      }
      _wasOverLimit = false;
    }
  }

  /// Write location to Firebase at most once every 30 seconds.
  void _maybeUpdateFirebase(Position position) {
    final now = DateTime.now();
    if (_lastFirebaseUpdate != null &&
        now.difference(_lastFirebaseUpdate!).inMilliseconds <
            LocationConfig.firebaseUpdateIntervalMs) {
      return; // Too soon — skip this tick
    }
    _lastFirebaseUpdate = now;
    _updateFirebase(position); // fire-and-forget
  }

  Future<void> _updateFirebase(Position position) async {
    try {
      final session = await _sessionService.getSession();
      if (session == null) {
        _logger.w('Skipping Firebase update: No active session');
        return;
      }

      final userData = session['user_data'];
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
            'provider': 'geolocator_flutter',
          },
        );
      } else {
        _logger.w(
            'Skipping Firebase update: Missing IDs (D:$driverId, T:$tenantId, V:$vendorId)');
      }
    } catch (e) {
      _logger.e('Error in _updateFirebase', error: e);
    }
  }
}
