import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import '../config/constants.dart';

/// Immutable value object representing the driver config returned by
/// GET /api/v1/driver/config
class DriverConfig {
  final double speedLimitKmph;
  final bool isBoardingOtpRequired;
  final bool isDeboardingOtpRequired;
  final bool isSafetyEnabled;

  const DriverConfig({
    required this.speedLimitKmph,
    required this.isBoardingOtpRequired,
    required this.isDeboardingOtpRequired,
    required this.isSafetyEnabled,
  });

  factory DriverConfig.fromJson(Map<String, dynamic> json) {
    final speed = json['speed'] as Map<String, dynamic>? ?? {};
    final otp = json['otp'] as Map<String, dynamic>? ?? {};
    final safety = json['safety'] as Map<String, dynamic>? ?? {};
    return DriverConfig(
      speedLimitKmph:
          (speed['effective_speed_limit_kmph'] as num?)?.toDouble() ?? 60.0,
      isBoardingOtpRequired:
          otp['is_boarding_otp_required'] as bool? ?? false,
      isDeboardingOtpRequired:
          otp['is_deboarding_otp_required'] as bool? ?? false,
      isSafetyEnabled: safety['is_enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'speed_limit_kmph': speedLimitKmph,
        'is_boarding_otp_required': isBoardingOtpRequired,
        'is_deboarding_otp_required': isDeboardingOtpRequired,
        'is_safety_enabled': isSafetyEnabled,
      };

  static DriverConfig get defaults => const DriverConfig(
        speedLimitKmph: 60.0,
        isBoardingOtpRequired: false,
        isDeboardingOtpRequired: false,
        isSafetyEnabled: false,
      );
}

/// Singleton service that fetches and caches the driver config.
/// Call [fetchConfig] once after successful auth; [config] always returns
/// the latest known value (falls back to cached → defaults).
class DriverConfigService {
  static final DriverConfigService _instance = DriverConfigService._internal();
  factory DriverConfigService() => _instance;
  DriverConfigService._internal();

  static const String _prefsKey = 'driver_config_cache';

  final Logger _logger = Logger();
  final ApiClient _apiClient = ApiClient();

  DriverConfig _config = DriverConfig.defaults;
  DriverConfig get config => _config;

  /// Load from local cache first for instant availability, then refresh
  /// from the API and persist the result.
  Future<void> fetchConfig() async {
    await _loadFromPrefs();

    try {
      final response =
          await _apiClient.client.get(ApiEndpoints.driverConfig);

      if (response.statusCode == 200) {
        final body = response.data as Map<String, dynamic>?;
        final data = body?['data'] as Map<String, dynamic>?;
        if (data != null) {
          _config = DriverConfig.fromJson(data);
          await _saveToPrefs(_config);
          _logger.i(
              'DriverConfig refreshed: speedLimit=${_config.speedLimitKmph} kmph');
        } else {
          _logger.w('DriverConfig: unexpected response shape: $body');
        }
      } else {
        _logger.w('DriverConfig: HTTP ${response.statusCode}');
      }
    } catch (e) {
      _logger.w(
          'DriverConfig: failed to fetch from API, using cached/defaults — $e');
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      _config = DriverConfig(
        speedLimitKmph:
            (json['speed_limit_kmph'] as num?)?.toDouble() ?? 60.0,
        isBoardingOtpRequired:
            json['is_boarding_otp_required'] as bool? ?? false,
        isDeboardingOtpRequired:
            json['is_deboarding_otp_required'] as bool? ?? false,
        isSafetyEnabled: json['is_safety_enabled'] as bool? ?? false,
      );
      _logger.d(
          'DriverConfig loaded from cache: speedLimit=${_config.speedLimitKmph} kmph');
    } catch (e) {
      _logger.w('DriverConfig: failed to load cache — $e');
    }
  }

  Future<void> _saveToPrefs(DriverConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(config.toJson()));
    } catch (e) {
      _logger.w('DriverConfig: failed to save cache — $e');
    }
  }
}
