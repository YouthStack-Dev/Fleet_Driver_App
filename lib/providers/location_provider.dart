import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/driver_config_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final DriverConfigService _driverConfigService = DriverConfigService();

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<bool>? _trackingStateSubscription;

  double _currentSpeedKmh = 0.0;
  bool _isSpeedLimitExceeded = false;
  Position? _lastPosition; // Cache for instant use in OTP actions

  double get currentSpeedKmh => _currentSpeedKmh;
  bool get isSpeedLimitExceeded => _isSpeedLimitExceeded;

  /// The effective speed limit from the last-fetched driver config.
  double get speedLimitKmh => _driverConfigService.config.speedLimitKmph;

  bool get isTracking => _locationService.isTracking;

  LocationProvider() {
    // Listen to GPS positions
    _positionSubscription =
        _locationService.positionStream.listen(_onPosition);

    // Listen to tracking start/stop so the HUD appears immediately when
    // AuthProvider starts tracking (without waiting for first GPS fix)
    _trackingStateSubscription =
        _locationService.trackingStateStream.listen((_) {
      notifyListeners();
    });

    // Fix race condition: AuthProvider calls startTracking() before
    // LocationProvider is created in MultiProvider, so the trackingStateStream
    // event fires before this subscriber exists and is silently dropped.
    // If tracking is already active at construction time, notify immediately.
    if (_locationService.isTracking) {
      Future.microtask(notifyListeners);
    }
  }

  void _onPosition(Position position) {
    _lastPosition = position;
    // position.speed returns -1.0 when GPS fix is not yet acquired — clamp to 0
    final speedMs = position.speed < 0 ? 0.0 : position.speed;
    _currentSpeedKmh = speedMs * 3.6; // m/s → km/h
    _isSpeedLimitExceeded = _currentSpeedKmh > speedLimitKmh;
    notifyListeners();
  }

  Future<bool> toggleTracking() async {
    if (_locationService.isTracking) {
      await _locationService.stopTracking();
    } else {
      await _locationService.startTracking();
    }
    notifyListeners();
    return _locationService.isTracking;
  }

  /// Returns a position as fast as possible:
  /// 1. Use cached last-known position if available (instant — already tracking)
  /// 2. Fall back to getLastKnownPosition() (fast, system-cached)
  /// 3. Final fallback: getCurrentPosition() with 10-second timeout
  Future<Position?> getCurrentLocation() async {
    // Fast path — already have a recent fix from the tracking stream
    if (_lastPosition != null) return _lastPosition;

    // Second path — ask the OS for its cached last-known position
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
    } catch (_) {}

    // Slow path — request a fresh fix with a hard timeout
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      return null;
    }
  }

  /// Tells LocationService which route is currently active so that speed
  /// violations are tagged with the correct route_id.
  /// Pass null when duty ends.
  void setActiveRoute(String? routeId) {
    _locationService.activeRouteId = routeId;
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _trackingStateSubscription?.cancel();
    super.dispose();
  }
}
