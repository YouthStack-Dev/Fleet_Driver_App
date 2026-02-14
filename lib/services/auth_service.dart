import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../config/constants.dart';
import 'api_client.dart';
import 'session_service.dart';
import 'dart:convert';

class AuthService {
  final Dio _dio = ApiClient().client;
  final SessionService _sessionService = SessionService();
  final Logger _logger = Logger();

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
      _logger.i('Attempting device verification for: $dlNumber');
      print('🔐 Calling Verify Device: ${ApiEndpoints.deviceVerify}');
      
      final payload = {
        'dl_number': dlNumber,
        ...deviceData,
      };
      
      final response = await _dio.post(ApiEndpoints.deviceVerify, data: payload);
      print('🔐 Verify Response: ${response.data}');
      final responseData = response.data;
      print('🔐 Verify Response Type: ${responseData.runtimeType}');

      if (responseData is! Map) {
         print('❌ Error: Expected Map for response body, got ${responseData.runtimeType}');
         return {'success': false, 'error': 'Invalid server response format'};
      }

      final data = responseData['data'];
      print('🔐 Data Type: ${data.runtimeType}');
      
      if (data is List) {
         print('❌ Error: Expected Map for "data", got List');
         return {'success': false, 'error': 'Invalid server response (Data is List)'};
      }
      
      final Map<String, dynamic> dataMap = (data is Map) ? Map<String, dynamic>.from(data) : {};
      
      // Validate Status
      if (dataMap['status'] != 'approved') {
         print('⛔ Device Not Approved: ${dataMap['status']}');
         return {
           'success': false, 
           'error': responseData['message'] ?? 'Device status is ${dataMap['status']}. Please contact support.',
           'vendors': [] 
         };
      }

      final rawVendors = dataMap['vendors'] as List? ?? [];
      final vendors = rawVendors.where((v) {
        return v['device_active'] == true || v['device_active'] == 1; // Handle bool or int
      }).toList();

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
      _logger.i('Selecting Tenant: V:$vendorId, T:$tenantId');
      print('🔐 Calling Select Tenant: ${ApiEndpoints.selectTenant}');
      
      final payload = {
        'dl_number': dlNumber,
        'android_id': deviceData['android_id'],
        'vendor_id': vendorId,
        'tenant_id': tenantId,
      };

      final response = await _dio.post(ApiEndpoints.selectTenant, data: payload);
      print('🔐 Select Tenant Response: ${response.data}');

      final data = response.data['data'] ?? {};
      final accessToken = data['access_token'] ?? data['token'];

      if (accessToken != null) {
        await _sessionService.setSession(
          accessToken: accessToken,
          userData: Map<String, dynamic>.from(data),
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
    try {
      final session = await _sessionService.getSession();
      final token = session?['access_token'];
      
      if (token == null) return {'success': false, 'error': 'No token to refresh'};

      _logger.i('Refreshing Token...');
      // Note: check if endpoint requires token in header (handled by interceptor) or body
      final response = await _dio.post(ApiEndpoints.driverRefresh);
      
      final data = response.data['data'] ?? {};
      final newAccessToken = data['access_token'] ?? data['token'];

      if (newAccessToken != null) {
         await _sessionService.setSession(
           accessToken: newAccessToken,
           userData: session?['user_data'], // Keep existing user data or update if provided
         );
         return {'success': true, 'access_token': newAccessToken};
      }
      
      return {'success': false, 'error': 'Token missing in refresh response'};
    } on DioException catch (e) {
      _logger.e('Refresh failed', error: e);
      return _handleError(e);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Map<String, dynamic> _handleError(DioException e) {
    String error = 'Network error';
    if (e.response?.data != null) {
      final data = e.response?.data;
      if (data is Map) {
         // Handle nested detail object (common in 403/401)
         if (data['detail'] is Map) {
           final detail = data['detail'];
           error = detail['message'] ?? detail['error'] ?? 'Unknown error';
           // Append error code if available for UI logic
           if (detail['error_code'] != null) {
             error += ' (${detail['error_code']})';
           }
         } else {
           error = data['detail'] ?? 
                  data['message'] ?? 
                  data['error'] ?? 
                  'Server error: ${e.response?.statusCode}';
         }
      }
    }
    return {'success': false, 'error': error};
  }

  /// Step 4: Switch Company
  Future<Map<String, dynamic>> switchCompany({
    required String accessToken,
    required String vendorId,
    required String tenantId,
  }) async {
    try {
      _logger.i('Switching to V: $vendorId, T: $tenantId');
      
      final response = await _dio.post(ApiEndpoints.switchCompany, data: {
        'access_token': accessToken, // It seems the endpoint might take token in body or header. Assuming body based on RN.
        'vendor_id': vendorId,
        'tenant_id': tenantId,
      });

      final data = response.data['data'] ?? {};
      final newAccessToken = data['access_token'] ?? data['token'];

      if (newAccessToken != null) {
         // Update session with new token and user data
         final tempSession = await _sessionService.getSession();
         final oldAccounts = tempSession?['user_data']?['accounts'] ?? [];
         
         final finalUserData = {
           ...data,
           'accounts': oldAccounts, // Preserve accounts list
         };

         await _sessionService.setSession(
           accessToken: newAccessToken,
           userData: Map<String, dynamic>.from(finalUserData),
         );
         
         return {'success': true, 'access_token': newAccessToken};
      }
      
      return {'success': false, 'error': 'Token missing in switch response'};
    } on DioException catch (e) {
      return _handleError(e);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
