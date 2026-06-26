import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/navigation_service.dart';
import 'package:dio/io.dart';
import '../config/constants.dart';
import 'auth_service.dart';
import 'session_service.dart';
import 'location_service.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late Dio _dio;

  factory ApiClient() => _instance;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      // Mobile networks can be slow — 10 s is too short for a driver app.
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Allow self-signed certificates (Fix for HandshakeException)
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
      return client;
    };

    _dio.interceptors.add(InterceptorsWrapper(
      // ── Request ────────────────────────────────────────────────────────────
      onRequest: (options, handler) async {
        // 1. Proactive Refresh (avoid most 401s completely)
        if (options.path != ApiEndpoints.driverRefresh) {
          final session = SessionService();
          final needsRefresh = await session.shouldRefreshToken();
          if (needsRefresh) {
            final result = await _refreshTokenOnce();
            if (result?['errorCode'] == 'INVALID_REFRESH') {
              final bool isOngoingRide = LocationService().activeRouteId != null;
              if (isOngoingRide) {
                debugPrint('🛡️ Active ride — suppressing logout on proactive refresh error.');
                return handler.next(options);
              }
              await _safeLogout();
              return handler.reject(
                DioException(
                  requestOptions: options,
                  error: 'Session expired',
                  type: DioExceptionType.badResponse,
                ),
              );
            }
          }
        }

        // 2. Don't read SecureStorage directly - delegate to SessionService
        if (options.path != ApiEndpoints.driverRefresh) {
          final token = await SessionService().getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            debugPrint('🔑 Authorization token injected: ...${token.substring(token.length > 10 ? token.length - 10 : 0)}');
          }
        } else {
          debugPrint('🔑 Skipping Authorization header for refresh request');
        }
        _logRequest(options);
        return handler.next(options);
      },

      // ── Response ───────────────────────────────────────────────────────────
      onResponse: (response, handler) {
        _logResponse(response);
        return handler.next(response);
      },

      // ── Error ──────────────────────────────────────────────────────────────
      onError: (DioException e, handler) async {
        final status = e.response?.statusCode;
        _logError(e);

        // 3. Retry Temporary Server Errors (502, 503, 504) — maximum 2 retries
        final bool isRetryableServer = status != null && (status == 502 || status == 503 || status == 504);
        if (isRetryableServer) {
          final serverRetryCount = (e.requestOptions.extra['serverRetryCount'] as int?) ?? 0;
          if (serverRetryCount < 2) {
            final delay = Duration(seconds: 2 * (serverRetryCount + 1));
            debugPrint('⚠️ Server error $status — retrying in ${delay.inSeconds} seconds (Attempt ${serverRetryCount + 1}/2)...');
            await Future.delayed(delay);
            final opts = e.requestOptions;
            opts.extra['serverRetryCount'] = serverRetryCount + 1;
            try {
              final retryResponse = await _dio.fetch(opts);
              return handler.resolve(retryResponse);
            } catch (retryErr) {
              debugPrint('❌ Retry after server error failed: $retryErr');
              if (retryErr is DioException) {
                return handler.next(retryErr);
              }
              return handler.next(e);
            }
          }
        }

        // ── Transient network errors — never treat as logout ─────────────────
        // SocketException, timeout, 502, 503, 504 etc. are network hiccups.
        // We pass them through without touching the session.
        final isNetworkError = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError ||
            (status != null && (status == 502 || status == 503 || status == 504));

        if (isNetworkError) {
          debugPrint('🌐 Network error — keeping session intact');
          return handler.next(e);
        }

        // ── 401 handling ─────────────────────────────────────────────────────
        if (status == 401) {
          final bool isOngoingRide = LocationService().activeRouteId != null;

          // Avoid infinite refresh loop: if the refresh endpoint itself 401s
          if (e.requestOptions.path == ApiEndpoints.driverRefresh) {
            debugPrint('🔒 Refresh token rejected by server.');
            if (isOngoingRide) {
              debugPrint('🛡️ Active ride — suppressing logout.');
              return handler.next(e);
            }
            // Refresh token is truly invalid — only safe time to logout
            await _safeLogout();
            return handler.next(e);
          }

          // Prevent retry loop: allow each request only ONE retry
          final retryCount = (e.requestOptions.extra['retryCount'] as int?) ?? 0;
          if (retryCount >= 1) {
            debugPrint('⚠️ Already retried once — not retrying again');
            return handler.next(e);
          }

          debugPrint('🔒 401 — attempting silent token refresh...');
          final refreshResult = await _refreshTokenOnce();
          final newToken = refreshResult?['access_token'] as String?;

          if (newToken != null) {
            // Retry original request with new token
            final opts = e.requestOptions;
            opts.headers['Authorization'] = 'Bearer $newToken';
            opts.extra['retryCount'] = retryCount + 1;
            try {
              final retryResponse = await _dio.fetch(opts);
              return handler.resolve(retryResponse);
            } catch (retryErr) {
              debugPrint('❌ Retry after refresh also failed: $retryErr');
              if (retryErr is DioException) {
                return handler.next(retryErr);
              }
              return handler.next(e);
            }
          }

          // Refresh failed — only logout if NOT on an active ride and it's not a network error
          final errorCode = refreshResult?['errorCode'];
          if (errorCode == 'NETWORK_ERROR' || errorCode == 'TIMEOUT') {
            debugPrint('🌐 Refresh failed due to network error/timeout — keeping session intact');
            return handler.next(e);
          }

          if (isOngoingRide) {
            debugPrint('🛡️ Active ride — suppressing logout after failed refresh.');
          } else {
            await _safeLogout();
          }
        }

        return handler.next(e);
      },
    ));
  }

  // ── Refresh token wrapper ──────────────────────────────────────────────────
  // Calls the single-coordination refreshToken() in AuthService.
  Future<Map<String, dynamic>?> _refreshTokenOnce() async {
    try {
      final result = await AuthService().refreshToken();
      if (result['success'] == true) {
        debugPrint('✅ Token refreshed successfully');
      } else {
        debugPrint('⚠️ Refresh failed: ${result['error']}');
      }
      return result;
    } catch (e) {
      debugPrint('❌ Refresh exception: $e');
      String errorCode = 'UNKNOWN';
      if (e is DioException) {
        final isTimeout = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout;
        final isNetwork = e.type == DioExceptionType.connectionError;
        final status = e.response?.statusCode;
        if (isTimeout) {
          errorCode = 'TIMEOUT';
        } else if (isNetwork) {
          errorCode = 'NETWORK_ERROR';
        } else if (status != null) {
          if (status == 400 || status == 401 || status == 403) {
            errorCode = 'INVALID_REFRESH';
          } else if (status >= 500) {
            errorCode = 'SERVER_ERROR';
          }
        }
      }
      return {'success': false, 'error': e.toString(), 'errorCode': errorCode};
    }
  }

  // ── Safe logout — only clears managed session keys, never deleteAll() ────
  // deleteAll() would wipe FCM tokens, device IDs, and any future secure keys.
  // We only ever clear what SessionService owns.
  Future<void> _safeLogout() async {
    debugPrint('🔒 Session invalid — logging out safely');
    await SessionService().clearSession();
    // Navigate to login — ApiClient delegates navigation via NavigationService
    // so the UI layer remains in control.
    NavigationService.navigateTo('/login');
  }

  // ── Logging Helpers ────────────────────────────────────────────────────────

  void _logRequest(RequestOptions options) {
    debugPrint('╔══ 🌐 HTTP REQUEST ══════════════════════════════════════════');
    debugPrint('║ Method: ${options.method.toUpperCase()}');
    debugPrint('║ URL: ${options.uri}');
    if (options.headers.isNotEmpty) {
      debugPrint('║ Headers:');
      options.headers.forEach((key, value) {
        if (key.toLowerCase() == 'authorization' && value is String && value.length > 20) {
          debugPrint('║   $key: Bearer ...${value.substring(value.length - 10)}');
        } else {
          debugPrint('║   $key: $value');
        }
      });
    }
    if (options.queryParameters.isNotEmpty) {
      debugPrint('║ Query Parameters: ${options.queryParameters}');
    }
    if (options.data != null) {
      debugPrint('║ Payload: ${options.data}');
    }
    debugPrint('╚═════════════════════════════════════════════════════════════');
  }

  void _logResponse(Response response) {
    debugPrint('╔══ ✅ HTTP RESPONSE ═════════════════════════════════════════');
    debugPrint('║ Status: ${response.statusCode} ${response.statusMessage ?? ""}');
    debugPrint('║ URL: ${response.requestOptions.uri}');
    if (response.headers.map.isNotEmpty) {
      debugPrint('║ Headers:');
      response.headers.map.forEach((key, value) {
        debugPrint('║   $key: $value');
      });
    }
    if (response.data != null) {
      debugPrint('║ Body: ${response.data}');
    }
    debugPrint('╚═════════════════════════════════════════════════════════════');
  }

  void _logError(DioException e) {
    final response = e.response;
    debugPrint('╔══ ❌ HTTP ERROR ════════════════════════════════════════════');
    debugPrint('║ Message: ${e.message}');
    debugPrint('║ Type: ${e.type}');
    debugPrint('║ URL: ${e.requestOptions.uri}');
    if (response != null) {
      debugPrint('║ Status: ${response.statusCode} ${response.statusMessage ?? ""}');
      if (response.headers.map.isNotEmpty) {
        debugPrint('║ Headers:');
        response.headers.map.forEach((key, value) {
          debugPrint('║   $key: $value');
        });
      }
      if (response.data != null) {
        debugPrint('║ Response Body: ${response.data}');
      }
    }
    debugPrint('╚═════════════════════════════════════════════════════════════');
  }

  Dio get client => _dio;
}
