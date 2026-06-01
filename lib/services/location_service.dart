import 'dart:async';
import 'dart:math'; // sin, cos, sqrt, atan2, pi — Haversine formula
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

  // FIX-5 / FIX-6: last position the server successfully received.
  // Used to compute per-ping Haversine delta distance and to suppress
  // stationary drift pings. Reset on every route change (start + end).
  Position? _lastSentPosition;

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

  // FIX-6: Reset BOTH the time throttle and the Haversine anchor on every
  // route change — whether starting a new duty (value != null) or clearing
  // after duty ends (value == null).  Previously _lastPingTime was only reset
  // when value != null, which meant the residual timer from the previous duty
  // could delay the first ping of the next duty start.
  set activeRouteId(String? value) {
    _activeRouteId = value;
    _lastPingTime = null;
    _lastSentPosition = null;
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
    _lastSentPosition = null;
    _trackingStateController.add(true); // HUD appears immediately in UI

    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      // distanceFilter 0 = emit on every interval tick regardless of movement.
      // Stationary drift filtering is handled in _maybeSendLocationPing so
      // the live speed HUD still refreshes every second while parked.
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
        //    only while a route is ONGOING, with stationary drift guard)
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
    _activeRouteId = null; // triggers setter → resets _lastPingTime + _lastSentPosition
    _trackingStateController.add(false);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Throttle + drift guard gate.
  ///
  /// Rules applied in order:
  ///   1. Suppress if no active route.
  ///   2. Suppress if < 7 s since the last sent ping (time throttle).
  ///   3. Suppress if speed < 5 km/h AND moved < 15 m since last sent ping
  ///      (stationary GPS-drift guard — FIX-1).
  ///   4. Otherwise: stamp _lastPingTime, compute Haversine delta, send.
  void _maybeSendLocationPing(Position position) {
    if (_activeRouteId == null) return; // Not on an active route — suppress

    final now = DateTime.now();

    // --- Gate 1: time throttle (7 s) ---
    if (_lastPingTime != null &&
        now.difference(_lastPingTime!).inMilliseconds <
            LocationConfig.locationPingIntervalMs) {
      return; // Too soon — skip this tick
    }

    // Separate speed values:
    //   speedKmhForGuard — clamped to 0 for the drift-guard comparison
    //   speedKmhForApi   — null when GPS has no Doppler fix (position.speed < 0)
    //                      so the server knows the value is unavailable
    final rawSpeedMs = position.speed;
    final speedKmhForGuard = rawSpeedMs < 0 ? 0.0 : rawSpeedMs * 3.6;
    final speedKmhForApi = rawSpeedMs < 0 ? null : rawSpeedMs * 3.6;

    // --- FIX-5: Haversine delta from last successfully sent position ---
    double? deltaDistanceM;
    if (_lastSentPosition != null) {
      deltaDistanceM = _haversineDistanceM(
        _lastSentPosition!.latitude,
        _lastSentPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // --- Gate 2: stationary drift guard (FIX-1) ---
      // When the device reports near-zero speed, require minimum real movement
      // before sending. This stops GPS jitter (±5–15 m while parked) from
      // accumulating as phantom distance in the server-side calculation.
      if (speedKmhForGuard < LocationConfig.stationarySpeedThresholdKmh &&
          deltaDistanceM < LocationConfig.minimumPingDistanceM) {
        _logger.d(
          '📍 Ping suppressed — stationary drift '
          '(moved ${deltaDistanceM.toStringAsFixed(1)} m, '
          '${speedKmhForGuard.toStringAsFixed(1)} km/h)',
        );
        // Do NOT update _lastPingTime here — keep the timer ticking so we
        // re-evaluate on every subsequent 7 s window until real movement occurs.
        return;
      }
    }

    // All gates passed — stamp the send time and fire the ping.
    _lastPingTime = now;

    _sendLocationPing(
      position: position,
      routeId: _activeRouteId!,
      speedKmh: speedKmhForApi,
      capturedAt: now, // FIX-2: server receives capture time, not arrival time
      deltaDistanceM: deltaDistanceM,
    );
  }

  /// Sends POST /driver/location with all enhanced fields.
  ///
  /// FIX-2: [capturedAt] is the moment the GPS fix was used, not the moment
  ///        the HTTP request arrives. The server can sort breadcrumbs by this
  ///        field and reject out-of-order points.
  ///
  /// FIX-3: [position.accuracy] (metres) is forwarded so the server can
  ///        weight or discard low-quality GPS fixes.
  ///
  /// FIX-4: Stale retry guard — if a retry fires more than
  ///        [LocationConfig.stalePingThresholdSeconds] after the original
  ///        capture time, the stale coordinate is silently discarded instead
  ///        of being delivered out of order to the server.
  ///
  /// FIX-5: [deltaDistanceM] is the device-computed Haversine distance from
  ///        the last successfully sent coordinate. The server uses this as a
  ///        cross-check against its own breadcrumb-sum; anomalous jumps can
  ///        be detected and filtered before being added to total_distance_km.
  ///
  /// On network failure retries with exponential back-off (2 s → 4 s → 8 s,
  /// up to 3 retries). [_lastSentPosition] is only updated on success.
  Future<void> _sendLocationPing({
    required Position position,
    required String routeId,
    double? speedKmh,
    required DateTime capturedAt,
    double? deltaDistanceM,
    int retryCount = 0,
  }) async {
    // FIX-4: Stale guard — discard if too much time has passed since capture.
    // Retrying a stale ping would insert an old coordinate at the wrong
    // timeline position, producing a spurious distance spike on the server.
    final ageSeconds = DateTime.now().difference(capturedAt).inSeconds;
    if (ageSeconds > LocationConfig.stalePingThresholdSeconds) {
      _logger.w(
        '⏱ Ping discarded — stale by ${ageSeconds}s '
        '(max ${LocationConfig.stalePingThresholdSeconds}s, '
        'retry $retryCount, route $routeId)',
      );
      return;
    }

    try {
      await _routeService.sendLocation(
        routeId: routeId,
        latitude: position.latitude,
        longitude: position.longitude,
        speedKmh: speedKmh,
        accuracyM: position.accuracy, // FIX-3
        capturedAt: capturedAt, // FIX-2
        deltaDistanceM: deltaDistanceM, // FIX-5
      );

      // FIX-5: Update the Haversine anchor ONLY on confirmed success.
      // This guarantees delta is always computed from the last coordinate
      // the server actually received — not from a point that may have been
      // lost to a network error.
      _lastSentPosition = position;

      _logger.d(
        '✅ Location ping sent: '
        '(${position.latitude.toStringAsFixed(5)}, '
        '${position.longitude.toStringAsFixed(5)})'
        '${speedKmh != null ? " @ ${speedKmh.toStringAsFixed(1)} km/h" : ""}'
        '${deltaDistanceM != null ? " Δ${deltaDistanceM.toStringAsFixed(0)} m" : ""}'
        ' acc:${position.accuracy.toStringAsFixed(0)} m',
      );
    } catch (e) {
      _logger.w('⚠️ Location ping failed (attempt ${retryCount + 1}): $e');
      if (retryCount < 3) {
        final delaySeconds = 2 << retryCount; // 2 s, 4 s, 8 s
        Future.delayed(Duration(seconds: delaySeconds), () {
          // Only retry if tracking is still active on the same route.
          // FIX-4: The stale guard inside _sendLocationPing will also reject
          // this if capturedAt is too old by the time the retry fires.
          if (_isTracking && _activeRouteId == routeId) {
            _sendLocationPing(
              position: position,
              routeId: routeId,
              speedKmh: speedKmh,
              capturedAt: capturedAt,
              deltaDistanceM: deltaDistanceM,
              retryCount: retryCount + 1,
            );
          }
        });
      } else {
        _logger.e(
          '❌ Location ping dropped after ${retryCount + 1} attempts: '
          '(${position.latitude}, ${position.longitude})',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // FIX-5: Haversine distance formula
  // ---------------------------------------------------------------------------

  /// Calculates the great-circle distance in metres between two WGS-84
  /// coordinates using the Haversine formula.
  ///
  /// Accuracy: within ~0.5% for distances < 1 000 km, which is more than
  /// sufficient for inter-ping segments of a few hundred metres.
  double _haversineDistanceM(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return earthRadiusM * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
