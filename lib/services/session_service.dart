import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String sessionKey       = 'user_session';
  static const String tempSessionKey   = 'temp_login_session';
  static const String accessTokenKey   = 'access_token'; // Legacy support

  // SharedPreferences keys (read by Kotlin background service)
  static const String _bgTokenKey      = 'bg_access_token';
  static const String _bgRouteKey      = 'active_route_id';
  static const String _trackingEnabledKey = 'tracking_enabled';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Singleton
  
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Synchronize background tracking session parameters in SharedPreferences.
  Future<void> syncBackgroundSession({
    required String token,
    required String driverId,
    required String tenantId,
    required String vendorId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bgTokenKey, token);
    if (driverId.isNotEmpty) {
      await prefs.setString('driver_id', driverId);
    }
    if (tenantId.isNotEmpty) {
      await prefs.setString('tenant_id', tenantId);
    }
    if (vendorId.isNotEmpty) {
      await prefs.setString('vendor_id', vendorId);
    }
  }

  /// Save final authenticated session to secure storage.
  /// Also mirrors the access token into SharedPreferences so the Kotlin
  /// background service can read it without FlutterSecureStorage access.
  Future<void> setSession({
    required String accessToken,
    required Map<String, dynamic> userData,
    String? refreshToken,
  }) async {
    final session = {
      'access_token':  accessToken,
      'refresh_token': refreshToken,
      'user_data':     userData,
      'expiresAt':     _extractExpiry(accessToken),
      'login_time':    DateTime.now().millisecondsSinceEpoch,
    };

    await _storage.write(key: sessionKey, value: jsonEncode(session));
    await _storage.write(key: accessTokenKey, value: accessToken);

    if (refreshToken != null) {
      await _storage.write(key: 'refresh_token', value: refreshToken);
    }

    final driverId = _extractDriverId(userData)?.toString() ?? '';
    final tenantId = _extractTenantId(userData)?.toString() ?? '';
    final vendorId = _extractVendorId(userData)?.toString() ?? '';

    // Legacy keys in secure storage for backward compatibility
    if (driverId.isNotEmpty) {
      await _storage.write(key: 'driver_id', value: driverId);
    }
    if (tenantId.isNotEmpty) {
      await _storage.write(key: 'tenant_id', value: tenantId);
    }
    if (vendorId.isNotEmpty) {
      await _storage.write(key: 'vendor_id', value: vendorId);
    }

    // Mirror to background shared preferences
    await syncBackgroundSession(
      token: accessToken,
      driverId: driverId,
      tenantId: tenantId,
      vendorId: vendorId,
    );
  }

  /// Save temporary session (pre-confirmation / vendor selection stage)
  Future<void> setTempSession({
    required String tempToken,
    Map<String, dynamic>? driver,
    required List<dynamic> accounts,
  }) async {
    final session = {
      'temp_token': tempToken,
      'driver':     driver,
      'accounts':   accounts,
      'createdAt':  DateTime.now().millisecondsSinceEpoch,
    };
    await _storage.write(key: tempSessionKey, value: jsonEncode(session));
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Returns the full session map or null if no session exists.
  /// Validates that essential keys are present — returns null for corrupted sessions.
  Future<Map<String, dynamic>?> getSession() async {
    try {
      final raw = await _storage.read(key: sessionKey);
      if (raw == null) return null;
      final session = jsonDecode(raw) as Map<String, dynamic>;

      // Validate session integrity
      if (session['access_token'] == null || session['user_data'] == null) {
        debugPrint('⚠️ SessionService: Corrupted session detected — clearing');
        await clearSession();
        return null;
      }
      return session;
    } catch (e) {
      debugPrint('❌ SessionService.getSession error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getTempSession() async {
    try {
      final raw = await _storage.read(key: tempSessionKey);
      if (raw == null) return null;
      return jsonDecode(raw);
    } catch (e) {
      debugPrint('❌ SessionService.getTempSession error: $e');
      return null;
    }
  }

  // ── Convenience helpers ────────────────────────────────────────────────────

  /// Returns the stored access token, or null.
  Future<String?> getAccessToken() async {
    final session = await getSession();
    return session?['access_token'] as String?;
  }

  /// Returns the stored refresh token, or null.
  Future<String?> getRefreshToken() async {
    final session = await getSession();
    return session?['refresh_token'] as String?;
  }

  /// Returns stored user data map, or null.
  Future<Map<String, dynamic>?> getUserData() async {
    final session = await getSession();
    return session?['user_data'] as Map<String, dynamic>?;
  }

  /// Returns true if a valid, non-null session with access token exists.
  Future<bool> hasValidSession() async {
    final session = await getSession();
    if (session == null) return false;
    final token = session['access_token'];
    final user  = session['user_data'];
    return token != null && token.toString().isNotEmpty && user != null;
  }

  /// Returns true if the access token has expired or will expire within
  /// [thresholdMinutes] minutes (default 10 min).
  /// Returns false if expiry cannot be determined (safe assumption = still valid).
  Future<bool> shouldRefreshToken({int thresholdMinutes = 10}) async {
    try {
      final session   = await getSession();
      final expiresAt = session?['expiresAt'] as int?;
      if (expiresAt == null) return false; // Can't determine — assume OK

      final nowMs       = DateTime.now().millisecondsSinceEpoch;
      final thresholdMs = thresholdMinutes * 60 * 1000;
      final needsRefresh = nowMs >= expiresAt - thresholdMs;
      if (needsRefresh) {
        debugPrint(
          '⏰ SessionService: Token expires at ${DateTime.fromMillisecondsSinceEpoch(expiresAt)} — refresh needed');
      }
      return needsRefresh;
    } catch (e) {
      debugPrint('❌ SessionService.shouldRefreshToken error: $e');
      return false;
    }
  }

  /// Returns true if the token is already expired (past expiry).
  Future<bool> isTokenExpired() async {
    try {
      final session   = await getSession();
      final expiresAt = session?['expiresAt'] as int?;
      if (expiresAt == null) return false;
      return DateTime.now().millisecondsSinceEpoch >= expiresAt;
    } catch (e) {
      return false;
    }
  }

  // ── Active Route helpers (SharedPreferences bridge for Kotlin) ─────────────

  Future<void> saveActiveRoute(String routeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bgRouteKey, routeId);
  }

  Future<String?> getActiveRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_bgRouteKey);
    return (id == null || id.isEmpty) ? null : id;
  }

  Future<void> clearActiveRoute() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bgRouteKey);
  }

  // ── Tracking flag (used by BootReceiver to decide if service should restart) ─

  Future<void> setTrackingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trackingEnabledKey, enabled);
  }

  Future<bool> isTrackingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_trackingEnabledKey) ?? false;
  }

  // ── Clear ──────────────────────────────────────────────────────────────────

  Future<void> clearSession() async {
    await _storage.delete(key: sessionKey);
    await _storage.delete(key: accessTokenKey);
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'driver_id');
    await _storage.delete(key: 'tenant_id');
    await _storage.delete(key: 'vendor_id');

    // Clear Kotlin bridge keys — use remove() not setString('')
    // to avoid treating empty strings as valid values.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bgTokenKey);
    await prefs.remove(_bgRouteKey);
    await prefs.remove(_trackingEnabledKey);
    await prefs.remove('driver_id');
    await prefs.remove('tenant_id');
    await prefs.remove('vendor_id');
  }

  Future<void> clearTempSession() async {
    await _storage.delete(key: tempSessionKey);
  }

  // ── JWT helpers ────────────────────────────────────────────────────────────

  /// Extracts the `exp` claim from a JWT and returns it as milliseconds epoch.
  int? _extractExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64.normalize(parts[1]))));
      final exp = payload['exp'];
      return exp != null ? (exp as int) * 1000 : null;
    } catch (e) {
      debugPrint('⚠️ SessionService: Could not parse JWT expiry: $e');
      return null;
    }
  }

  // ── ID extraction helpers ──────────────────────────────────────────────────

  dynamic _extractDriverId(Map<String, dynamic> ud) =>
      ud['driver_id'] ??
      ud['user']?['driver']?['driver_id'] ??
      ud['user']?['driver_id'] ??
      ud['driver']?['driver_id'];

  dynamic _extractTenantId(Map<String, dynamic> ud) =>
      ud['tenant_id'] ??
      ud['account']?['tenant_id'] ??
      ud['user']?['tenant_id'] ??
      ud['user']?['driver']?['tenant_id'] ??
      ud['user']?['tenant']?['tenant_id'];

  dynamic _extractVendorId(Map<String, dynamic> ud) =>
      ud['vendor_id'] ??
      ud['account']?['vendor_id'] ??
      ud['user']?['driver']?['vendor_id'];
}
