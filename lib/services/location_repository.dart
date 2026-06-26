import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'location_service.dart';
import 'route_service.dart';
import 'driver_config_service.dart';

class QueuedLocation {
  final String routeId;
  final double latitude;
  final double longitude;
  final double? speedKmh;
  final int timestamp;

  QueuedLocation({
    required this.routeId,
    required this.latitude,
    required this.longitude,
    this.speedKmh,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'routeId': routeId,
        'latitude': latitude,
        'longitude': longitude,
        'speedKmh': speedKmh,
        'timestamp': timestamp,
      };

  factory QueuedLocation.fromJson(Map<String, dynamic> json) => QueuedLocation(
        routeId: json['routeId'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        speedKmh: json['speedKmh'] != null ? (json['speedKmh'] as num).toDouble() : null,
        timestamp: json['timestamp'] as int,
      );
}

class LocationRepository {
  static const String _queueKey = 'offline_location_queue';
  final Logger _logger = Logger();
  final RouteService _routeService = RouteService();

  static final LocationRepository _instance = LocationRepository._internal();
  factory LocationRepository() => _instance;

  StreamSubscription<Position>? _gpsSubscription;
  DateTime? _lastUploadTime;
  bool _isProcessing = false;
  Timer? _retryTimer;

  LocationRepository._internal() {
    _logger.i('📦 Initializing LocationRepository');
    // Start listening to the GPS stream from LocationService
    _startGpsListener();
    // Start periodic background queue processor
    _startQueueProcessor();
  }

  void _startGpsListener() {
    _gpsSubscription?.cancel();
    _gpsSubscription = LocationService().positionStream.listen(
      (position) {
        _handleNewPosition(position);
      },
      onError: (e) {
        _logger.w('⚠️ LocationRepository: error in positionStream: $e');
      },
    );
    _logger.i('✅ LocationRepository: Subscribed to LocationService positionStream');
  }

  void _handleNewPosition(Position position) {
    final routeId = LocationService().activeRouteId;
    if (routeId == null || routeId.isEmpty) {
      // Not on an active route — suppress uploads/queueing
      return;
    }

    final now = DateTime.now();
    // Fetch dynamic interval from DriverConfig (defaulting to 60s during active trips)
    final intervalSeconds = DriverConfigService().config.uploadIntervalSeconds;

    if (_lastUploadTime == null ||
        now.difference(_lastUploadTime!).inSeconds >= intervalSeconds) {
      _lastUploadTime = now;
      final speedKmh = position.speed < 0 ? null : position.speed * 3.6;

      _logger.i('📍 GPS trigger: Queueing location for route: $routeId '
          '(${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}) '
          'at dynamic interval: ${intervalSeconds}s');

      queueLocation(
        routeId: routeId,
        latitude: position.latitude,
        longitude: position.longitude,
        speedKmh: speedKmh,
      );
    }
  }

  /// Adds a location to the persistent offline queue and triggers processing.
  Future<void> queueLocation({
    required String routeId,
    required double latitude,
    required double longitude,
    double? speedKmh,
  }) async {
    final location = QueuedLocation(
      routeId: routeId,
      latitude: latitude,
      longitude: longitude,
      speedKmh: speedKmh,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawQueue = prefs.getStringList(_queueKey) ?? [];
      rawQueue.add(jsonEncode(location.toJson()));
      await prefs.setStringList(_queueKey, rawQueue);
      _logger.d('📝 Location queued. Queue size: ${rawQueue.length}');

      // Try to upload immediately
      processQueue();
    } catch (e) {
      _logger.e('❌ LocationRepository: Failed to queue location: $e');
    }
  }

  /// Processes the queue: uploads all queued locations in FIFO order.
  /// Stops processing on network/upload error to preserve order.
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawQueue = prefs.getStringList(_queueKey) ?? [];
      if (rawQueue.isEmpty) {
        _isProcessing = false;
        return;
      }

      _logger.i('📤 Processing offline location queue with ${rawQueue.length} items...');
      final List<String> remainingItems = [];
      bool stopProcessing = false;

      for (var itemStr in rawQueue) {
        if (stopProcessing) {
          remainingItems.add(itemStr);
          continue;
        }

        QueuedLocation loc;
        try {
          loc = QueuedLocation.fromJson(jsonDecode(itemStr));
        } catch (e) {
          _logger.w('⚠️ Corrupted location item in queue — skipping: $e');
          continue;
        }

        try {
          await _routeService.sendLocation(
            routeId: loc.routeId,
            latitude: loc.latitude,
            longitude: loc.longitude,
            speedKmh: loc.speedKmh,
          );
          _logger.i('✅ Location upload succeeded: (${loc.latitude}, ${loc.longitude}) for route ${loc.routeId}');
        } catch (e) {
          _logger.w('⚠️ Location upload failed: $e. Retaining in queue.');
          remainingItems.add(itemStr);
          stopProcessing = true; // Stop processing subsequent items to maintain order
        }
      }

      await prefs.setStringList(_queueKey, remainingItems);
    } catch (e) {
      _logger.e('❌ LocationRepository: Error processing queue: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _startQueueProcessor() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      processQueue();
    });
  }

  /// Reset helper (e.g. for testing)
  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
    _logger.i('🧹 LocationRepository: Queue cleared');
  }

  void dispose() {
    _gpsSubscription?.cancel();
    _retryTimer?.cancel();
  }
}
