import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import '../config/constants.dart';
import 'route_service.dart';

class LocationService {
  final Logger _logger = Logger();
  final RouteService _routeService = RouteService();

  // Singleton
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;
  // Guard against concurrent async calls to startTracking() racing past the
  // `if (_isTracking) return;` check before the flag is set.
  bool _startingTracking = false;

  // Throttle REST pings — GPS ticks every 1 s but the backend needs 7 s
  DateTime? _lastPingTime;

  // Broadcast stream — consumed by LocationProvider for live speed display
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  // Broadcast stream — lets LocationProvider know the moment tracking starts/stops
  final StreamController<bool> _trackingStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get trackingStateStream => _trackingStateController.stream;

  /// The currently-active route ID for location pings.
  /// Set via LocationProvider.setActiveRoute(); null suppresses all pings.
  String? _activeRouteId;
  String? get activeRouteId => _activeRouteId;
  set activeRouteId(String? value) {
    _activeRouteId = value;
    if (value != null) {
      // Reset timer so the first ping fires immediately when duty starts.
      _lastPingTime = null;
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
    _lastPingTime = null;
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

        // 2. Send location ping to backend (throttled to once every 7 s,
        //    only while a route is ONGOING)
        _maybeSendLocationPing(position);
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
    _trackingStateController.add(false);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Throttle gate: sends a location ping at most once every 7 s,
  /// and only when a route is actively ONGOING (_activeRouteId != null).
  void _maybeSendLocationPing(Position position) {
    if (_activeRouteId == null) return; // Not on an active route — suppress

    final now = DateTime.now();
    if (_lastPingTime != null &&
        now.difference(_lastPingTime!).inMilliseconds <
            LocationConfig.locationPingIntervalMs) {
      return; // Too soon — skip this tick
    }
    _lastPingTime = now;

    // Convert m/s → km/h; pass null if GPS hasn't acquired a valid speed fix
    final speedKmh = position.speed < 0 ? null : position.speed * 3.6;

    _sendLocationPing(
      routeId: _activeRouteId!,
      latitude: position.latitude,
      longitude: position.longitude,
      speedKmh: speedKmh,
    );
  }

  /// Sends POST /driver/location. On network failure retries with exponential
  /// back-off (2 s → 4 s → 8 s, up to 3 retries) so no GPS point is silently
  /// dropped. After 3 retries the point is logged and discarded.
  Future<void> _sendLocationPing({
    required String routeId,
    required double latitude,
    required double longitude,
    double? speedKmh,
    int retryCount = 0,
  }) async {
    try {
      await _routeService.sendLocation(
        routeId: routeId,
        latitude: latitude,
        longitude: longitude,
        speedKmh: speedKmh,
      );
      _logger.d('✅ Location ping sent: ($latitude, $longitude)'
          '${speedKmh != null ? " @ ${speedKmh.toStringAsFixed(1)} km/h" : ""}');
    } catch (e) {
      _logger.w('⚠️ Location ping failed (attempt ${retryCount + 1}): $e');
      if (retryCount < 3) {
        final delaySeconds = 2 << retryCount; // 2 s, 4 s, 8 s
        Future.delayed(Duration(seconds: delaySeconds), () {
          // Only retry if tracking is still active on the same route
          if (_isTracking && _activeRouteId == routeId) {
            _sendLocationPing(
              routeId: routeId,
              latitude: latitude,
              longitude: longitude,
              speedKmh: speedKmh,
              retryCount: retryCount + 1,
            );
          }
        });
      } else {
        _logger.e('❌ Location ping dropped after ${retryCount + 1} attempts');
      }
    }
  }
}
