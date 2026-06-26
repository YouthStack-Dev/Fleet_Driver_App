import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../config/constants.dart';
import 'api_client.dart';
import 'session_service.dart';
import 'background_tracking_service.dart';

class AuthService {
  final Dio _dio = ApiClient().client;
  final SessionService _sessionService = SessionService();
  final Logger _logger = Logger();
  Future<Map<String, dynamic>>? _ongoingRefresh;

  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  /// Step 1: Device Verification
  Future<Map<String, dynamic>> verifyDevice({
    required String dlNumber,
    required Map<String, dynamic> deviceData,
  }) async {
    try {
      final cleanDl = dlNumber.trim().toUpperCase();
      _logger.i('Attempting device verification for: $cleanDl');
      _logger.d('🔐 Calling Verify Device: ${ApiEndpoints.deviceVerify}');
      
      final payload = {
        'dl_number': cleanDl,
        ...deviceData,
      };
      
      final response = await _dio.post(ApiEndpoints.deviceVerify, data: payload);
      _logger.d('🔐 Verify Response: ${response.data}');
      final responseData = response.data;
      _logger.d('🔐 Verify Response Type: ${responseData.runtimeType}');

      if (responseData is! Map) {
         _logger.e('❌ Error: Expected Map for response body, got ${responseData.runtimeType}');
         return {'success': false, 'error': 'Invalid server response format'};
      }

      final data = responseData['data'];
      _logger.d('🔐 Data Type: ${data.runtimeType}');
      
      if (data is List) {
         _logger.e('❌ Error: Expected Map for "data", got List');
         return {'success': false, 'error': 'Invalid server response (Data is List)'};
      }
      
      final Map<String, dynamic> dataMap = (data is Map) ? Map<String, dynamic>.from(data) : {};
      
      // Validate Status
      if (dataMap['status'] != 'approved') {
         _logger.w('⛔ Device Not Approved: ${dataMap['status']}');
         return {
           'success': false, 
           'error': responseData['message'] ?? 'Device status is ${dataMap['status']}. Please contact support.',
           'vendors': [] 
         };
      }

      final rawVendors = dataMap['vendors'] as List? ?? [];
      final vendors = rawVendors; // Return all vendors, UI will handle status display

      return {
        'success': true,
        'vendors': vendors,
        'message': responseData['message'],
      };

    } on DioException catch (e) {
      _logger.e('Verify failed', error: e);
      return _handleError(e);
    } catch (e, stack) {
      _logger.e('Verify unexpected error', error: e, stackTrace: stack);
      return {'success': false, 'error': 'App Error: ${e.toString()}'};
    }
  }

  /// Step 2: Select Tenant (Complete Login)
  Future<Map<String, dynamic>> selectTenant({
    required String dlNumber,
    required Map<String, dynamic> deviceData,
    required String vendorId,
    required String tenantId,
  }) async {
    try {
      final cleanDl = dlNumber.trim().toUpperCase();
      _logger.i('Selecting Tenant: V:$vendorId, T:$tenantId for DL: $cleanDl');
      _logger.d('🔐 Calling Select Tenant: ${ApiEndpoints.selectTenant}');
      
      final payload = {
        'dl_number': cleanDl,
        'android_id': deviceData['android_id'],
        'vendor_id': int.tryParse(vendorId) ?? vendorId,
        'tenant_id': tenantId,
      };

      final response = await _dio.post(ApiEndpoints.selectTenant, data: payload);
      _logger.d('🔐 Select Tenant Response received');

      final data = response.data['data'] ?? {};
      final accessToken = data['access_token'] ?? data['token'];

      if (accessToken != null) {
        // Fix: Always prioritize the existing full list of accounts.
        // The selectTenant API might return a partial list (just the active one) or none.
        // We trust the session (populated by verifyDevice) as the master list.
        final currentSession = await _sessionService.getSession();
        final tempSession = await _sessionService.getTempSession();
        
        final existingAccounts = currentSession?['user_data']?['accounts'] ?? tempSession?['accounts']; // Master list
        final newAccounts = data['accounts'];

        var accountsToSave = newAccounts;
        
        // If we have an existing list, usage logic:
        // 1. If new list is null/empty -> Use existing.
        // 2. If new list is smaller than existing -> Use existing (assume new is partial).
        // 3. Just force use existing to be safe, as verifyDevice is the source of truth.
        if (existingAccounts != null && (existingAccounts is List && existingAccounts.isNotEmpty)) {
            accountsToSave = existingAccounts;
        }

        final finalUserData = Map<String, dynamic>.from(data);
        // Explicitly set the preserved list
        if (accountsToSave != null) {
           finalUserData['accounts'] = accountsToSave;
        }

        // Inject license_number if missing (critical for switching)
        if (finalUserData['license_number'] == null) {
          finalUserData['license_number'] = dlNumber;
        }
        
        // Also inject into 'driver' object if it exists
        if (finalUserData['driver'] is Map) {
           finalUserData['driver']['license_number'] = dlNumber;
        } else {
           // Maybe create driver obj? For now, top level is good enough
        }

        await _sessionService.setSession(
          accessToken: accessToken,
          refreshToken: data['refresh_token'],
          userData: finalUserData,
        );
        
        await _sessionService.clearTempSession();
        
        return {
          'success': true,
          'access_token': accessToken,
          'user_data': data
        };
      }

      return {'success': false, 'error': 'Access token missing'};

    } on DioException catch (e) {
      _logger.e('Select Tenant failed', error: e);
      return _handleError(e);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Step 3: Refresh Token
  Future<Map<String, dynamic>> refreshToken() async {
    if (_ongoingRefresh != null) {
      _logger.i('🔑 Token refresh already in progress, awaiting...');
      return _ongoingRefresh!;
    }

    _ongoingRefresh = _performTokenRefresh();
    try {
      final result = await _ongoingRefresh!;
      return result;
    } finally {
      _ongoingRefresh = null;
    }
  }

  Future<Map<String, dynamic>> _performTokenRefresh() async {
    try {
      final session = await _sessionService.getSession();
      final refreshToken = session?['refresh_token'];
      
      if (refreshToken == null) {
        return {
          'success': false, 
          'error': 'No refresh token available',
          'errorCode': 'EXPIRED_REFRESH_TOKEN'
        };
      }

      _logger.i('Refreshing Token...');
      
      final response = await _dio.post(ApiEndpoints.driverRefresh, data: {
        'refresh_token': refreshToken
      });
      
      _logger.i('🔄 Refresh Response Body: ${response.data}');
      final data = response.data['data'] ?? {};
      final newAccessToken = data['access_token'] ?? data['token'];
      final newRefreshToken = data['refresh_token']; // Might be rotated
      _logger.i('🔑 New Access Token generated: ${newAccessToken != null ? "...${newAccessToken.substring(newAccessToken.length > 10 ? newAccessToken.length - 10 : 0)}" : "null"}');

      if (newAccessToken != null) {
         final refreshedUser = (data['user_data'] ??
             data['user'] ??
             session?['user_data']) as Map<String, dynamic>? ?? {};

         await _sessionService.setSession(
           accessToken: newAccessToken,
           refreshToken: newRefreshToken ?? refreshToken, // Update if new one provided
           userData: refreshedUser,
         );
         
         // Trigger BackgroundTrackingService().syncSession() immediately after a successful token refresh
         await BackgroundTrackingService().syncSession();

         return {'success': true, 'access_token': newAccessToken};
      }
      
      return {
        'success': false, 
        'error': 'Token missing in refresh response',
        'errorCode': 'SERVER_ERROR'
      };
    } on DioException catch (e) {
      _logger.e('Refresh failed', error: e);
      return _handleError(e);
    } catch (e) {
      return {
        'success': false, 
        'error': e.toString(),
        'errorCode': 'UNKNOWN'
      };
    }
  }

  Map<String, dynamic> _handleError(DioException e) {
    String error = 'Server error';
    String errorCode = 'UNKNOWN';

    final isTimeout = e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout;
    final isNetwork = e.type == DioExceptionType.connectionError;
    final status = e.response?.statusCode;

    if (isTimeout) {
      errorCode = 'TIMEOUT';
      error = 'Connection timed out';
    } else if (isNetwork) {
      errorCode = 'NETWORK_ERROR';
      error = 'Network connection error';
    } else if (status != null) {
      if (status == 400 || status == 401 || status == 403) {
        errorCode = 'INVALID_REFRESH';
        error = 'Session expired';
      } else if (status >= 500) {
        errorCode = 'SERVER_ERROR';
        error = 'Server error ($status)';
      }
    }

    if (e.response?.data != null) {
      final data = e.response?.data;
      if (data is Map) {
         // Handle nested detail object (common in 403/401)
         if (data['detail'] is Map) {
            final detail = data['detail'];
            error = detail['message'] ?? detail['error'] ?? error;
            if (detail['error_code'] != null) {
              error += ' (${detail['error_code']})';
              errorCode = detail['error_code'].toString();
            }
         } else {
            error = data['detail'] ?? 
                   data['message'] ?? 
                   data['error'] ?? 
                   error;
         }
      }
    }
    return {'success': false, 'error': error, 'errorCode': errorCode};
  }

  /// Step 4: Switch Company (Reuses Select Tenant)
  Future<Map<String, dynamic>> switchCompany({
    required String vendorId,
    required String tenantId,
  }) async {
    try {
      _logger.i('Switching Company -> V: $vendorId, T: $tenantId');
      
      // We need device data and DL number to use selectTenant endpoint.
      // Fetch from session or device service.
      final session = await _sessionService.getSession();
      final userData = session?['user_data'];
      final dlNumber = userData?['driver']?['license_number'] ?? userData?['license_number'];
      
      if (dlNumber == null) {
        return {'success': false, 'error': 'Driver license not found in session'};
      }

      // We need to get device data again to ensure android_id is present
      // We can't import DeviceService here easily if it causes circular dep, 
      // but AuthService is low level. Let's assume we can pass it or fetch it.
      // Better to use the public selectTenant method if we can source the data.
      
      // However, since we are inside AuthService, let's just use the endpoint directly 
      // with the data we have.
      
      // NOTE: The caller (AuthProvider) has easy access to DeviceService.
      // It might be cleaner to update AuthProvider to just call selectTenant directly.
      // But to keep the API surface clean for the UI, let's implement the logic here 
      // by fetching what we need if possible, OR fail if we cant.
      
      // Let's rely on the AuthProvider to pass the data, OR update this method signature.
      // Updating signature is safer. But let's look at AuthProvider usage.
      // AuthProvider.switchCompany calls this.
      
      return {'success': false, 'error': 'Please use selectTenant for switching'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Step 5: Logout
  Future<Map<String, dynamic>> logout() async {
    try {
      _logger.i('Attempting backend logout: ${ApiEndpoints.logout}');
      final response = await _dio.post(ApiEndpoints.logout);
      _logger.i('Backend logout response: ${response.data}');
      return {'success': true};
    } on DioException catch (e) {
      _logger.e('Backend logout failed', error: e);
      return _handleError(e);
    } catch (e) {
      _logger.e('Backend logout unexpected error', error: e);
      return {'success': false, 'error': e.toString()};
    }
  }
}
