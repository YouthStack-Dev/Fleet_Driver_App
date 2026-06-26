import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import '../config/constants.dart';
import 'session_service.dart';
import 'background_tracking_service.dart';

class LocationService with WidgetsBindingObserver {
  final Logger _logger = Logger();

  // Singleton
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;

  LocationService._internal() {
    _logger.i('Initializing LocationService with WidgetsBindingObserver');
    WidgetsBinding.instance.addObserver(this);
  }

  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;
  // Guard against concurrent async calls to startTracking() racing past the
  // `if (_isTracking) return;` check before the flag is set.
  bool _startingTracking = false;

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
  /// Synchronizes across Memory, SessionService, and Native Foreground Service.
  String? _activeRouteId;
  String? get activeRouteId => _activeRouteId;
  set activeRouteId(String? value) {
    if (_activeRouteId == value) return;
    _activeRouteId = value;
    _logger.i('📍 Route ID updated in memory: $value');

    if (value != null && value.isNotEmpty) {
      // Sync with SessionService (SharedPreferences)
      SessionService().saveActiveRoute(value);
      // Sync with Native Foreground Service
      SessionService().getAccessToken().then((token) {
        if (token != null) {
          _logger.i('Starting background tracking service for route: $value');
          BackgroundTrackingService().startBackgroundTracking(
            routeId: value,
            accessToken: token,
          );
        } else {
          _logger.w('⚠️ Cannot start background tracking: access token is null');
        }
      });
    } else {
      // Clear route in SharedPreferences and stop background service
      _logger.i('Stopping background tracking service (route cleared)');
      SessionService().clearActiveRoute();
      BackgroundTrackingService().stopBackgroundTracking();
    }
  }

  bool get isTracking => _isTracking;

  bool _hasPermission = true;
  bool get hasPermission => _hasPermission;

  final StreamController<bool> _permissionStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get permissionStateStream => _permissionStateController.stream;

  void _updatePermission(bool value) {
    if (_hasPermission != value) {
      _hasPermission = value;
      _permissionStateController.add(value);
      _logger.i('🔑 GPS Permission state updated: $value');
    }
  }

  // ── App Lifecycle & Permission Recovery ──────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _logger.i('📱 App lifecycle state transitioned to: $state');
    if (state == AppLifecycleState.resumed) {
      _checkPermissionRecovery();
    }
  }

  Future<void> _checkPermissionRecovery() async {
    final permission = await Geolocator.checkPermission();
    final hasPerm = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    
    _updatePermission(hasPerm);

    if (hasPerm && _isTracking && _positionStreamSubscription == null) {
      _logger.i('🔄 GPS Permission restored. Automatically restarting location stream.');
      _subscribeToGpsStream();
    }
  }

  Future<bool> checkPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _logger.w('Location services are disabled.');
      _updatePermission(false);
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _logger.w('Location permissions are denied');
        _updatePermission(false);
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _logger.w('Location permissions permanently denied.');
      _updatePermission(false);
      return false;
    }

    _updatePermission(true);
    return true;
  }

  Future<bool> startTracking() async {
    if (_isTracking || _startingTracking) return _isTracking;
    _startingTracking = true;

    final hasPermission = await checkPermission();
    if (!hasPermission) {
      _startingTracking = false;
      return false;
    }

    _logger.i('🚀 Starting location tracking stream');
    _isTracking = true;
    _startingTracking = false;
    _trackingStateController.add(true); // HUD appears immediately in UI

    _subscribeToGpsStream();
    return true;
  }

  void _subscribeToGpsStream() {
    _positionStreamSubscription?.cancel();

    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: LocationConfig.distanceFilterMeters, // 0
      intervalDuration:
          const Duration(milliseconds: LocationConfig.updateIntervalMs), // 1 s
      // Geolocator's internal foreground service config is REMOVED.
      // The Native Kotlin Foreground Service handles the persistent notification.
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        final kmh = (position.speed < 0 ? 0.0 : position.speed) * 3.6;
        _logger.d('📍 GPS Location: (${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}) | '
            '${kmh.toStringAsFixed(1)} km/h | acc: ${position.accuracy.toStringAsFixed(0)} m');

        // Emit to UI stream
        _positionController.add(position);
      },
      onError: (e) {
        _logger.e('❌ Location stream error: $e. Retrying connection in 5s.');
        _handleStreamError();
      },
      onDone: () {
        _logger.w('⚠️ Location stream closed unexpectedly. Retrying connection in 5s.');
        _handleStreamError();
      },
    );
    _logger.i('✅ GPS stream subscription created');
  }

  void _handleStreamError() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    // Do NOT set _isTracking = false or stop tracking.
    // Instead, schedule an automatic reconnect.
    if (_isTracking) {
      Future.delayed(const Duration(seconds: 5), () {
        if (_isTracking && _positionStreamSubscription == null) {
          _logger.i('🔄 Re-subscribing to GPS stream...');
          _subscribeToGpsStream();
        }
      });
    }
  }

  Future<void> stopTracking() async {
    _logger.i('🛑 Stopping location tracking stream');
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isTracking = false;
    _activeRouteId = null;
    _trackingStateController.add(false);
  }
}
