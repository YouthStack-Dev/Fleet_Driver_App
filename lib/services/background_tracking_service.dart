import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_service.dart';

/// Flutter ↔ Kotlin bridge for the background location foreground service.
///
/// Key design: all state that the Kotlin service needs (route ID + token) is
/// written to SharedPreferences BEFORE the MethodChannel call so the Kotlin
/// side always reads a consistent value even if the Flutter engine dies.
class BackgroundTrackingService {
  static const _channel = MethodChannel('mlt_driver/tracking');

  // SharedPreferences keys — must match constants in LocationForegroundService.kt
  static const _keyRouteId  = 'active_route_id';
  static const _keyToken     = 'bg_access_token';
  static const _keyDriverId  = 'driver_id';
  static const _keyTenantId  = 'tenant_id';
  static const _keyVendorId  = 'vendor_id';

  final Logger _log = Logger();

  // Singleton
  static final BackgroundTrackingService _instance = BackgroundTrackingService._internal();
  factory BackgroundTrackingService() => _instance;
  BackgroundTrackingService._internal();

  /// Call when duty starts. Writes route ID + token to SharedPreferences,
  /// then signals the Kotlin service to start.
  Future<void> startBackgroundTracking({
    required String routeId,
    required String accessToken,
    String? driverId,
    String? tenantId,
    String? vendorId,
  }) async {
    try {
      _log.i('🟢 BackgroundTracking: starting for route=$routeId');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRouteId, routeId);
      await prefs.setString(_keyToken, accessToken);
      if (driverId != null) await prefs.setString(_keyDriverId, driverId);
      if (tenantId != null) await prefs.setString(_keyTenantId, tenantId);
      if (vendorId != null) await prefs.setString(_keyVendorId, vendorId);

      await _channel.invokeMethod('startBackgroundTracking');
      _log.i('✅ BackgroundTracking: Kotlin service started');
    } catch (e) {
      _log.e('❌ BackgroundTracking start error: $e');
      // Non-fatal — geolocator stream still runs as fallback
    }
  }

  /// Call when duty ends or trip is cancelled.
  /// Clears route ID so the Kotlin service stops itself.
  Future<void> stopBackgroundTracking() async {
    try {
      _log.i('🔴 BackgroundTracking: stopping');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRouteId, '');  // Empty → service stops itself

      await _channel.invokeMethod('stopBackgroundTracking');
      _log.i('✅ BackgroundTracking: Kotlin service stopped');
    } catch (e) {
      _log.e('❌ BackgroundTracking stop error: $e');
    }
  }

  /// Update the access token in SharedPreferences (called after silent token refresh).
  /// The Kotlin service reads this on next ping, so it stays authenticated.
  Future<void> updateToken(String newToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, newToken);
      _log.d('🔑 BackgroundTracking: token updated in SharedPrefs');
      // Tell native side if running
      await _channel.invokeMethod('updateToken', {'token': newToken});
    } catch (e) {
      _log.w('⚠️ BackgroundTracking updateToken error: $e');
    }
  }

  /// Update the active route in SharedPreferences.
  Future<void> updateRoute(String routeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRouteId, routeId);
      _log.d('📍 BackgroundTracking: route updated in SharedPrefs');
      // Tell native side if running
      await _channel.invokeMethod('updateRoute', {'routeId': routeId});
    } catch (e) {
      _log.w('⚠️ BackgroundTracking updateRoute error: $e');
    }
  }

  /// Returns the currently persisted active route ID, or null if none.
  Future<String?> getActiveRouteId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_keyRouteId);
    return (id == null || id.isEmpty) ? null : id;
  }

  /// Returns true if the native foreground service is running.
  Future<bool> isTrackingRunning() async {
    try {
      final bool running = await _channel.invokeMethod('isTrackingRunning') ?? false;
      return running;
    } catch (e) {
      _log.e('❌ BackgroundTracking isTrackingRunning error: $e');
      return false;
    }
  }

  /// Synchronize the current session credentials and driver context
  /// from SessionService to the SharedPreferences keys read by the native service.
  Future<void> syncSession({
    String? token,
    String? driverId,
    String? tenantId,
    String? vendorId,
  }) async {
    try {
      _log.i('🔄 BackgroundTracking: syncing session data');
      final session = (token == null) ? await SessionService().getSession() : null;
      
      final actualToken = token ?? session?['access_token'] as String?;
      final userData = session?['user_data'] as Map<String, dynamic>?;
      
      if (actualToken != null) {
        final actualDriverId = driverId ?? userData?['driver_id'] ?? userData?['user']?['driver']?['driver_id'] ?? userData?['driver']?['driver_id'];
        final actualTenantId = tenantId ?? userData?['tenant_id'] ?? userData?['account']?['tenant_id'] ?? userData?['user']?['tenant_id'] ?? userData?['user']?['tenant']?['tenant_id'];
        final actualVendorId = vendorId ?? userData?['vendor_id'] ?? userData?['account']?['vendor_id'] ?? userData?['user']?['driver']?['vendor_id'];

        await SessionService().syncBackgroundSession(
          token: actualToken,
          driverId: actualDriverId?.toString() ?? '',
          tenantId: actualTenantId?.toString() ?? '',
          vendorId: actualVendorId?.toString() ?? '',
        );

        // Also update token on the native side if active
        await _channel.invokeMethod('updateToken', {'token': actualToken});

        _log.i('✅ BackgroundTracking: session synced successfully');
      }
    } catch (e) {
      _log.e('❌ BackgroundTracking syncSession error: $e');
    }
  }
}
