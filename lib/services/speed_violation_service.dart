import 'package:logger/logger.dart';
import 'api_client.dart';
import '../config/constants.dart';

/// Posts speed-violation events to the backend.
/// Enforces a 30-second cooldown between successive reports for the same
/// route to avoid flooding the API.
class SpeedViolationService {
  static final SpeedViolationService _instance =
      SpeedViolationService._internal();
  factory SpeedViolationService() => _instance;
  SpeedViolationService._internal();

  static const int _cooldownSeconds = 30;

  final Logger _logger = Logger();
  final ApiClient _apiClient = ApiClient();

  DateTime? _lastReportedAt;

  bool get _isCoolingDown {
    if (_lastReportedAt == null) return false;
    return DateTime.now().difference(_lastReportedAt!).inSeconds <
        _cooldownSeconds;
  }

  /// Report a speed violation.  Will silently drop the call if still within
  /// the 30-second cooldown window.
  Future<void> reportViolation({
    required String routeId,
    required double speedKmph,
    required double speedLimitKmph,
    required double latitude,
    required double longitude,
  }) async {
    if (_isCoolingDown) {
      _logger.d(
          'SpeedViolation: cooldown active, skipping (${speedKmph.toStringAsFixed(1)} kmph)');
      return;
    }

    // Stamp the time before the async call so rapid concurrent invocations
    // all see the cooldown immediately.
    _lastReportedAt = DateTime.now();

    try {
      final payload = {
        'route_id': routeId,
        'speed_kmph': speedKmph,
        'speed_limit_kmph': speedLimitKmph,
        'latitude': latitude,
        'longitude': longitude,
        'recorded_at': _lastReportedAt!.toUtc().toIso8601String(),
      };

      final response = await _apiClient.client
          .post(ApiEndpoints.speedViolation, data: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.i(
            'SpeedViolation reported: ${speedKmph.toStringAsFixed(1)} kmph '
            '(limit: ${speedLimitKmph.toStringAsFixed(1)} kmph, route: $routeId)');
      } else {
        _logger.w(
            'SpeedViolation: unexpected HTTP ${response.statusCode}');
      }
    } catch (e) {
      // Keep _lastReportedAt set — still honour cooldown even on network error
      // to prevent hammering the server when offline.
      _logger.e('SpeedViolation: failed to report — $e');
    }
  }

  /// Reset the cooldown (e.g. when a new duty starts).
  void resetCooldown() {
    _lastReportedAt = null;
  }
}
