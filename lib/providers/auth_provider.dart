import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/location_service.dart';
import '../services/device_service.dart';

enum AuthStatus { unknown, unauthenticated, tempAuthenticated, authenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SessionService _sessionService = SessionService();
  final DeviceService _deviceService = DeviceService();

  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;

  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get currentUser => _currentUser;
  
  // Temp session data
  String? _tempToken;
  List<dynamic> _accounts = []; // Now used as 'vendors'
  Map<String, dynamic>? _driver;
  List<dynamic> get vendors => _accounts; // Alias for clarity

  List<dynamic> get accounts => _accounts;
  Map<String, dynamic>? get driver => _driver;

  // Robust getters for IDs
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

  Future<void> init() async {
    // Check for existing session
    final session = await _sessionService.getSession();
    if (session != null) {
      _currentUser = session['user_data'];
      if (_currentUser != null) {
        final rawAccounts = _currentUser!['accounts'] is List ? _currentUser!['accounts'] : [];
        _accounts = rawAccounts.where((a) {
           // Filter by device_active if present
           final isActive = a['device_active'];
           if (isActive == null) return true; // Keep if unknown (backward compatibility)
           return isActive == true || isActive == 1;
        }).toList();
        
        _driver = _currentUser!['driver'] ?? _currentUser!['user']?['driver'];
      }
      
      // Restore persistence: If session exists, user is authenticated.
      _status = AuthStatus.authenticated; 
      
      // Auto-start tracking on session restore
      print('🚀 AuthProvider: Restoring session, starting location tracking...');
      LocationService().startTracking(); 
    } else {
      // Check for temp session
      final tempSession = await _sessionService.getTempSession();
      if (tempSession != null) {
        _tempToken = tempSession['temp_token'];
        _accounts = tempSession['accounts'] ?? [];
        _driver = tempSession['driver'];
        _status = AuthStatus.tempAuthenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> verifyDevice(String license) async {
    final deviceData = await _deviceService.getDeviceData();
    
    final result = await _authService.verifyDevice(
      dlNumber: license, 
      deviceData: deviceData
    );
    
    if (result['success'] == true) {
      _accounts = result['vendors'] ?? [];
      _status = AuthStatus.tempAuthenticated; // Valid device, pending vendor selection
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>> selectTenant(dynamic vendor, String license) async {
    final deviceData = await _deviceService.getDeviceData();
    
    final vendorId = vendor['vendor_id']?.toString();
    final tenantId = vendor['tenant_id']?.toString();

    if (vendorId == null || tenantId == null) {
       return {'success': false, 'error': 'Invalid vendor data'};
    }

    final result = await _authService.selectTenant(
      dlNumber: license, // Need to pass this through or store it temp
      deviceData: deviceData,
      vendorId: vendorId,
      tenantId: tenantId,
    );

    if (result['success'] == true) {
      _currentUser = result['user_data'];
      
      final token = result['access_token'];
      final userData = result['user_data'];

      final prefs = await SharedPreferences.getInstance();
      if (token != null) await prefs.setString('token', token);
      if (userData != null) await prefs.setString('user_data', json.encode(userData));
      
      if (userData != null) {
        if (userData['driver_id'] != null) await prefs.setString('driver_id', userData['driver_id'].toString());
        if (userData['tenant_id'] != null) await prefs.setString('tenant_id', userData['tenant_id'].toString());
        if (userData['vendor_id'] != null) await prefs.setString('vendor_id', userData['vendor_id'].toString());
      }
      
      _status = AuthStatus.authenticated;
      
      print('🚀 AuthProvider: Tenant selected, starting location tracking...');
      LocationService().startTracking();
      
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>> switchCompany(dynamic account) async {
    final session = await _sessionService.getSession();
    final token = session?['access_token'];
    
    if (token == null) return {'success': false, 'error': 'No active session'};

    final vendorId = account['vendor_id']?.toString() ?? account['vendor']?['id']?.toString();
    final tenantId = account['tenant_id']?.toString() ?? account['tenant']?['id']?.toString();

    if (vendorId == null || tenantId == null) {
       return {'success': false, 'error': 'Invalid account data'};
    }

    try {
       print('🔄 AuthProvider: calling authService.switchCompany');
       final result = await _authService.switchCompany(
         accessToken: token,
         vendorId: vendorId,
         tenantId: tenantId,
       );
       print('🔄 AuthProvider: switch result: $result');

       if (result['success'] == true) {
          // AuthService has already updated the session in SecureStorage.
          // We just need to refresh our local state.
          print('🔄 AuthProvider: Switch success, calling init()');
          await init();
          print('🔄 AuthProvider: init() complete');
          return result;
       } else {
          print('🔄 AuthProvider: Switch failed at service level');
          return result;
       }
    } catch (e, stack) {
       print('❌ Error processing switch success: $e');
       print(stack);
       return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> refreshToken() async {
    final result = await _authService.refreshToken();
    if (result['success'] == true) {
      // Session is already updated by AuthService
      await init(); // Refresh local state
    }
    return result;
  }
  Future<void> logout() async {
    // TODO: Call logout API if needed
    await _sessionService.clearSession();
    await _sessionService.clearTempSession();
    _currentUser = null;
    _tempToken = null;
    _status = AuthStatus.unauthenticated;
    
    // Stop tracking on logout
    print('🛑 AuthProvider: Logging out, stopping location tracking...');
    LocationService().stopTracking();
    
    notifyListeners();
  }
}
