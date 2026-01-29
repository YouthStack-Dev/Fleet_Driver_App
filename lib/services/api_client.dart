import 'dart:io';
import 'package:dio/dio.dart';
import '../services/navigation_service.dart';
import 'package:dio/io.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Allow self-signed certificates (Fix for HandshakeException)
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
       final client = HttpClient();
       client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
       return client;
    };

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        print('🌐 Starting Request: ${options.method} ${options.baseUrl}${options.path}');
        print('   Headers: ${options.headers}');
        print('   Data: ${options.data}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('✅ Response [${response.statusCode}]: ${response.data}');
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        print('❌ Error [${e.response?.statusCode}]: ${e.message}');
        print('   Error Data: ${e.response?.data}');
        
        if (e.response?.statusCode == 401) {
          print('🔒 401 Unauthorized - Redirecting to Login');
          // Clear session securely
          await _storage.deleteAll(); 
          // Redirect
          NavigationService.navigateTo('/login');
        }
        
        return handler.next(e);
      },
    ));
  }

  Dio get client => _dio;
}
