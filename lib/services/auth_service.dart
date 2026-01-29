import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../config/constants.dart';
import 'api_client.dart';
import 'session_service.dart';

class AuthService {
  final Dio _dio = ApiClient().client;
  final SessionService _sessionService = SessionService();
  final Logger _logger = Logger();

  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  /// Step 1: Initial Login to get Temp Token
  Future<Map<String, dynamic>> login(String licenseNumber, String password) async {
    try {
      _logger.i('Attempting login for: $licenseNumber');
      print('🔐 Calling Login Endpoint: ${ApiEndpoints.newLogin}');
      final response = await _dio.post(ApiEndpoints.newLogin, data: {
        'license_number': licenseNumber,
        'password': password,
      });
      print('🔐 Login Response: ${response.data}');

      final data = response.data['data'] ?? {};
      final tempToken = data['temp_token'] ?? data['token'];
      final accounts = data['accounts'] ?? [];
      final driver = data['driver'];

      if (tempToken != null) {
        await _sessionService.setTempSession(
          tempToken: tempToken,
          driver: driver,
          accounts: accounts is List ? accounts : [],
        );
        return {
          'success': true,
          'temp_token': tempToken,
          'accounts': accounts,
          'driver': driver
        };
      }

      return {'success': false, 'error': 'Token missing in response'};
    } on DioException catch (e) {
      _logger.e('Login failed', error: e);
      return _handleError(e);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Step 2: Confirm Login with Tenant/Vendor selection
  Future<Map<String, dynamic>> confirmLogin({
    required String tempToken,
    required String vendorId,
    required String tenantId,
  }) async {
    try {
      _logger.i('Confirming login for V: $vendorId, T: $tenantId');
      
      print('🔐 Calling Confirm Login Endpoint: ${ApiEndpoints.loginConfirm}');
      final response = await _dio.post(ApiEndpoints.loginConfirm, data: {
        'temp_token': tempToken,
        'vendor_id': vendorId,
        'tenant_id': tenantId,
      });
      print('🔐 Confirm Login Response: ${response.data}');

      final data = response.data['data'] ?? {};
      final accessToken = data['access_token'] ?? data['token'];

      if (accessToken != null) {
        // Merge accounts from temp session
        final tempSession = await _sessionService.getTempSession();
        final accounts = tempSession?['accounts'] ?? [];

        final finalUserData = {
          ...data,
          'accounts': accounts,
        };

        await _sessionService.setSession(
          accessToken: accessToken,
          userData: Map<String, dynamic>.from(finalUserData),
        );
        
        await _sessionService.clearTempSession();
        
        // TODO: Start location tracking here (via callback or separate call)
        
        return {
          'success': true,
          'access_token': accessToken,
          'user_data': data
        };
      }

      return {'success': false, 'error': 'Access token missing'};
    } on DioException catch (e) {
      _logger.e('Confirm login failed', error: e);
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
        error = data['detail']?['message'] ?? 
                data['message'] ?? 
                data['error'] ?? 
                data['detail'] ?? 
                'Server error: ${e.response?.statusCode}';
      }
    }
    return {'success': false, 'error': error};
  }

  /// Step 3: Switch Company
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
