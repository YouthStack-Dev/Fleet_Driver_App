import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionService {
  static const String sessionKey = 'user_session';
  static const String tempSessionKey = 'temp_login_session';
  static const String accessTokenKey = 'access_token'; // Legacy support
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // Singleton
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  /// Save final authenticated session
  Future<void> setSession({required String accessToken, required Map<String, dynamic> userData, String? refreshToken}) async {
    final session = {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user_data': userData,
      'expiresAt': _extractExpiry(accessToken),
    };
    
    await _storage.write(key: sessionKey, value: jsonEncode(session));
    await _storage.write(key: accessTokenKey, value: accessToken);
    
    // Save legacy keys for compatibility if needed elsewhere
    final driverId = _extractDriverId(userData);
    if (driverId != null) await _storage.write(key: 'driver_id', value: driverId.toString());
    
    final tenantId = _extractTenantId(userData);
    if (tenantId != null) await _storage.write(key: 'tenant_id', value: tenantId.toString());
    
    final vendorId = _extractVendorId(userData);
    if (vendorId != null) await _storage.write(key: 'vendor_id', value: vendorId.toString());
  }

  /// Save temporary session (pre-confirmation)
  Future<void> setTempSession({required String tempToken, Map<String, dynamic>? driver, required List<dynamic> accounts}) async {
    final session = {
      'temp_token': tempToken,
      'driver': driver,
      'accounts': accounts,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
    await _storage.write(key: tempSessionKey, value: jsonEncode(session));
  }

  Future<Map<String, dynamic>?> getTempSession() async {
    final raw = await _storage.read(key: tempSessionKey);
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  Future<void> clearTempSession() async {
    await _storage.delete(key: tempSessionKey);
  }

  Future<Map<String, dynamic>?> getSession() async {
    final raw = await _storage.read(key: sessionKey);
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: sessionKey);
    await _storage.delete(key: accessTokenKey);
    await _storage.delete(key: 'driver_id');
    await _storage.delete(key: 'tenant_id');
    await _storage.delete(key: 'vendor_id');
  }

  // Helper to decode JWT expiry (simple implementation)
  int? _extractExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64.normalize(parts[1]))));
      return payload['exp'] != null ? payload['exp'] * 1000 : null;
    } catch (e) {
      return null;
    }
  }

  // Helper to extract IDs from userData structure
  dynamic _extractDriverId(Map<String, dynamic> ud) {
    return ud['driver_id'] ?? 
           ud['user']?['driver']?['driver_id'] ?? 
           ud['user']?['driver_id'] ?? 
           ud['driver']?['driver_id'];
  }
  
  dynamic _extractTenantId(Map<String, dynamic> ud) {
    return ud['tenant_id'] ?? 
           ud['account']?['tenant_id'] ?? 
           ud['user']?['tenant_id'] ?? 
           ud['user']?['driver']?['tenant_id'] ??
           ud['user']?['tenant']?['tenant_id'];
  }

  dynamic _extractVendorId(Map<String, dynamic> ud) {
    return ud['vendor_id'] ?? 
           ud['account']?['vendor_id'] ??
           ud['user']?['driver']?['vendor_id'];
  }
}
