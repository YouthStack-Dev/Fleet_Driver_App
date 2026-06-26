import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/location_service.dart';
import '../services/device_service.dart';
import '../services/driver_config_service.dart';
import '../services/push_notification_service.dart';
import '../services/background_tracking_service.dart';

enum AuthStatus { unknown, unauthenticated, tempAuthenticated, authenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService    _authService    = AuthService();
  final SessionService _sessionService = SessionService();
  final DeviceService  _deviceService  = DeviceService();

  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;

  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get currentUser => _currentUser;

  // Temp session data
  String? _tempToken;
  List<dynamic> _accounts = [];
  Map<String, dynamic>? _driver;
  List<dynamic> get vendors  => _accounts;
  List<dynamic> get accounts => _accounts;
  Map<String, dynamic>? get driver => _driver;

  // ── ID getters ─────────────────────────────────────────────────────────────

  String get tenantId {
    if (_currentUser == null) return 'N/A';
    final val = _currentUser!['tenant_id'] ??
                _currentUser!['account']?['tenant_id'] ??
                _currentUser!['user']?['tenant_id'] ??
                _currentUser!['user']?['driver']?['tenant_id'] ??
                _currentUser!['user']?['tenant']?['tenant_id'];
    return val?.toString() ?? 'N/A';
  }

  String get vendorId {
    if (_currentUser == null) return 'N/A';
    final val = _currentUser!['vendor_id'] ??
                _currentUser!['account']?['vendor_id'] ??
                _currentUser!['user']?['driver']?['vendor_id'];
    return val?.toString() ?? 'N/A';
  }

  // ── init() ─────────────────────────────────────────────────────────────────
  /// Called once at app startup. Restores session, refreshes token if needed,
  /// and kicks off background services. Calls notifyListeners() exactly once
  /// at the very end to minimise UI rebuilds.
  Future<void> init() async {
    // Validate session integrity before trusting it
    final hasValid = await _sessionService.hasValidSession();
    if (!hasValid) {
      // No valid session — fall back to temp or unauthenticated
      await _resolveUnauthenticated();
      notifyListeners();
      return;
    }

    final session = await _sessionService.getSession();
    if (session == null) {
      await _resolveUnauthenticated();
      notifyListeners();
      return;
    }

    // Restore user data
    _currentUser = session['user_data'];
    if (_currentUser != null) {
      _accounts = _currentUser!['accounts'] is List
          ? List.from(_currentUser!['accounts'])
          : [];
      _driver = _currentUser!['driver'] ?? _currentUser!['user']?['driver'];
    }
    _status = AuthStatus.authenticated;

    // Proactively refresh if token is expired or near expiry (10 min window)
    await _proactiveTokenRefresh();

    // Start location tracking only if not already running (avoid duplicate streams)
    if (!LocationService().isTracking) {
      debugPrint('🚀 AuthProvider: Starting location tracking');
      LocationService().startTracking();
    } else {
      debugPrint('✅ AuthProvider: Location tracking already active');
    }

    // Background fire-and-forget tasks — don't block the UI
    unawaited(DriverConfigService().fetchConfig());
    unawaited(PushNotificationService().registerWithBackend());

    // Single notifyListeners at the end — after all state is ready
    notifyListeners();
  }

  // ── Proactive token refresh ────────────────────────────────────────────────
  /// Uses SessionService.shouldRefreshToken() — single source of truth
  /// for expiry logic. Never throws; any failure is logged and swallowed
  /// so the app always opens.
  Future<void> _proactiveTokenRefresh() async {
    try {
      final needsRefresh = await _sessionService.shouldRefreshToken(thresholdMinutes: 10);
      if (!needsRefresh) return;

      debugPrint('⏰ AuthProvider: Refreshing token silently...');
      final result = await _authService.refreshToken();
      if (result['success'] == true) {
        debugPrint('✅ AuthProvider: Token refreshed OK');
        await BackgroundTrackingService().syncSession();
      } else {
        debugPrint('⚠️ AuthProvider: Proactive refresh failed — will retry on next 401');
        // Don't logout — ApiClient interceptor handles actual 401 with retry
      }
    } catch (e) {
      debugPrint('⚠️ AuthProvider: Proactive refresh exception: $e');
    }
  }

  // ── Unauthenticated fallback ───────────────────────────────────────────────
  Future<void> _resolveUnauthenticated() async {
    final tempSession = await _sessionService.getTempSession();
    if (tempSession != null) {
      _tempToken = tempSession['temp_token'];
      _accounts  = tempSession['accounts'] ?? [];
      _driver    = tempSession['driver'];
      _status    = AuthStatus.tempAuthenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
  }

  // ── verifyDevice ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> verifyDevice(String license) async {
    final deviceData = await _deviceService.getDeviceData();
    final cleanDl = license.trim().toUpperCase();
    final result = await _authService.verifyDevice(
        dlNumber: cleanDl, deviceData: deviceData);

    if (result['success'] == true) {
      _accounts = result['vendors'] ?? [];
      _driver   = {'license_number': cleanDl};
      _status   = AuthStatus.tempAuthenticated;
      await _sessionService.setTempSession(
        tempToken: 'verify_stage',
        accounts:  _accounts,
        driver:    _driver,
      );
      notifyListeners();
    }
    return result;
  }

  // ── selectTenant ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> selectTenant(dynamic vendor, String license) async {
    final deviceData = await _deviceService.getDeviceData();
    final vId = vendor['vendor_id']?.toString();
    final tId = vendor['tenant_id']?.toString();

    if (vId == null || tId == null) {
      return {'success': false, 'error': 'Invalid vendor data'};
    }

    final result = await _authService.selectTenant(
      dlNumber:   license,
      deviceData: deviceData,
      vendorId:   vId,
      tenantId:   tId,
    );

    if (result['success'] == true) {
      _currentUser = result['user_data'];

      final token    = result['access_token'];
      final userData = result['user_data'];

      // Also write to SharedPreferences for legacy screens that read from prefs
      final prefs = await SharedPreferences.getInstance();
      if (token    != null) await prefs.setString('token', token);
      if (userData != null) await prefs.setString('user_data', json.encode(userData));
      if (userData != null) {
        if (userData['driver_id'] != null) await prefs.setString('driver_id', userData['driver_id'].toString());
        if (userData['tenant_id'] != null) await prefs.setString('tenant_id', userData['tenant_id'].toString());
        if (userData['vendor_id'] != null) await prefs.setString('vendor_id', userData['vendor_id'].toString());
      }

      _status = AuthStatus.authenticated;

      debugPrint('🚀 AuthProvider: Tenant selected, starting location tracking');
      // Stop first to avoid duplicate stream from init()
      await LocationService().stopTracking();
      LocationService().startTracking();

      unawaited(DriverConfigService().fetchConfig());
      unawaited(PushNotificationService().registerWithBackend());

      notifyListeners();
    }
    return result;
  }

  // ── switchCompany ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> switchCompany(dynamic account) async {
    final session  = await _sessionService.getSession();
    final userData = session?['user_data'];
    final dlNumber = userData?['driver']?['license_number'] ?? userData?['license_number'];

    if (dlNumber == null) return {'success': false, 'error': 'Driver license not found'};

    final vId = account['vendor_id']?.toString() ?? account['vendor']?['id']?.toString();
    final tId = account['tenant_id']?.toString() ?? account['tenant']?['id']?.toString();

    if (vId == null || tId == null) return {'success': false, 'error': 'Invalid account data'};

    final deviceData = await _deviceService.getDeviceData();

    try {
      debugPrint('🔄 AuthProvider: Switching company V:$vId T:$tId');
      final result = await _authService.selectTenant(
        dlNumber:   dlNumber,
        deviceData: deviceData,
        vendorId:   vId,
        tenantId:   tId,
      );

      if (result['success'] == true) {
        // Refresh token first so init() starts with a valid token
        await _proactiveTokenRefresh();
        await init();
        debugPrint('✅ AuthProvider: Company switch complete');
        return result;
      }
      debugPrint('⚠️ AuthProvider: Company switch failed: ${result['error']}');
      return result;
    } catch (e, stack) {
      debugPrint('❌ AuthProvider.switchCompany error: $e\n$stack');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── refreshToken ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> refreshToken() async {
    final result = await _authService.refreshToken();
    if (result['success'] == true) {
      await init();
    }
    return result;
  }

  // ── logout ─────────────────────────────────────────────────────────────────
  /// Only called on explicit driver action (Logout button).
  /// Stops background tracking service BEFORE clearing session so the
  /// Kotlin service has a chance to read the stop signal.
  Future<void> logout() async {
    debugPrint('🛑 AuthProvider: Driver initiated logout');

    // Call backend logout to invalidate session in Redis/memory
    try {
      final res = await _authService.logout();
      debugPrint('🚪 AuthProvider: Backend logout status: ${res['success']}');
    } catch (e) {
      debugPrint('⚠️ AuthProvider: Backend logout API call failed: $e');
    }

    // Stop Kotlin background service first
    await BackgroundTrackingService().stopBackgroundTracking();

    // Stop Flutter GPS stream
    await LocationService().stopTracking();

    // Clear all session data
    await _sessionService.clearSession();
    await _sessionService.clearTempSession();

    _currentUser = null;
    _tempToken   = null;
    _status      = AuthStatus.unauthenticated;

    notifyListeners();
  }
}
