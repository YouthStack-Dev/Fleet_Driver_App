import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../config/constants.dart';
import 'api_client.dart';

class RouteService {
  final Dio _dio = ApiClient().client;
  final Logger _logger = Logger();

  // Singleton
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;
  RouteService._internal();

  /// Fetch Driver Trips
  Future<Map<String, dynamic>> getDriverTrips({String statusFilter = 'upcoming', String? bookingDate}) async {
    try {
      final queryParams = <String, dynamic>{
        'status_filter': statusFilter,
      };

      if (bookingDate != null) {
        queryParams['booking_date'] = bookingDate;
      } else if (statusFilter == 'upcoming') {
        final now = DateTime.now();
        final formatted = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        queryParams['booking_date'] = formatted;
      }

      _logger.i('Fetching trips: $queryParams');

      final response = await _dio.get(ApiEndpoints.driverTrips, queryParameters: queryParams);
      
      // RN: result.routes = res.data.data.routes
      final data = response.data['data'];
      final routes = (data is Map<String, dynamic> && data.containsKey('routes')) 
          ? data['routes'] 
          : (data is List ? data : []); // Fallback if API changes
          
      return {
        'success': true,
        'routes': routes is List ? routes : []
      };

    } on DioException catch (e) {
      _logger.e('Failed to fetch trips', error: e);
      return {'success': false, 'error': e.message};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetch Employee Bookings (My Schedules for Employee/Driver)
  Future<Map<String, dynamic>> getEmployeeBookings({required Map<String, dynamic> params}) async {
    try {
      _logger.i('Fetching bookings: $params');
      final response = await _dio.get(ApiEndpoints.bookings, queryParameters: params);
      
      final data = response.data['data']; // Assuming standard response structure
      // RN app expects result.bookings
      return {
        'success': true,
        'bookings': data is List ? data : (data['bookings'] is List ? data['bookings'] : [])
      };
    } on DioException catch (e) {
      _logger.e('Failed to fetch bookings', error: e);
      return {'success': false, 'error': e.message};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Start Duty
  Future<Map<String, dynamic>> startDuty(String routeId) async {
    try {
      _logger.i('Starting duty for route: $routeId');
      // Fix: Use query params, not body
      final response = await _dio.post(
        ApiEndpoints.dutyStart,
        queryParameters: {'route_id': routeId},
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// End Duty
  Future<Map<String, dynamic>> endDuty(String routeId, String? reason) async {
    try {
      _logger.i('Ending duty for route: $routeId');
      
      final params = {'route_id': routeId};
      if (reason != null) params['reason'] = reason;

      // Fix: Use PUT and query params
      final response = await _dio.put(
        ApiEndpoints.dutyEnd,
        queryParameters: params,
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Start Pickup (Start Trip)
  Future<Map<String, dynamic>> startTrip({
    required String routeId,
    required String bookingId,
    String? otp,
    required double latitude,
    required double longitude,
  }) async {
    try {
      _logger.i('Starting trip (Pickup) for booking: $bookingId');
      
      final params = {
        'route_id': routeId,
        'booking_id': bookingId,
        'current_latitude': latitude,
        'current_longitude': longitude,
      };
      if (otp != null) params['otp'] = otp;

      // Fix: Use query params
      final response = await _dio.post(
        ApiEndpoints.tripStart,
        queryParameters: params,
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Drop Passenger (End Trip)
  Future<Map<String, dynamic>> dropTrip({
    required String routeId,
    required String bookingId,
    String? otp,
    required double latitude,
    required double longitude,
  }) async {
    try {
      _logger.i('Dropping passenger for booking: $bookingId');
      
      final params = {
        'route_id': routeId,
        'booking_id': bookingId,
        'current_latitude': latitude,
        'current_longitude': longitude,
      };
      if (otp != null) params['otp'] = otp;

      // Fix: Use PUT and query params
      final response = await _dio.put(
        ApiEndpoints.tripEnd,
        queryParameters: params,
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Mark No Show
  Future<Map<String, dynamic>> markNoShow({
    required String routeId,
    required String bookingId,
    String? reason,
  }) async {
    try {
      _logger.i('Marking No Show for booking: $bookingId');
      
      final params = {
        'route_id': routeId,
        'booking_id': bookingId,
        'reason': reason ?? 'Passenger did not show up',
      };

      // Fix: Use PUT and query params
      final response = await _dio.put(
        ApiEndpoints.noShow,
        queryParameters: params,
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Send a GPS location ping for an ONGOING route — POST /driver/location.
  /// Called every ~7 s while duty is active.
  ///
  /// [speedKmh]       – Speed in km/h; null when GPS has no Doppler fix.
  ///                    Server uses it for ETA recalc and speed enforcement.
  /// [accuracyM]      – Horizontal accuracy radius in metres reported by the
  ///                    GPS chip. Server can weight/discard low-quality fixes.
  /// [capturedAt]     – UTC timestamp of when the GPS fix was captured on the
  ///                    device. Sent as ISO-8601 so the server can sort
  ///                    breadcrumbs by capture time rather than arrival time,
  ///                    preventing out-of-order retries from corrupting the
  ///                    distance calculation.
  /// [deltaDistanceM] – Haversine distance (metres) from the last successfully
  ///                    sent coordinate to this one, computed on the device.
  ///                    The server cross-checks this against its own segment
  ///                    sum to detect anomalous GPS jumps before they inflate
  ///                    total_distance_km.
  ///
  /// Throws on non-2xx so the caller can apply retry logic.
  Future<void> sendLocation({
    required String routeId,
    required double latitude,
    required double longitude,
    double? speedKmh,
    double? accuracyM,
    DateTime? capturedAt,
    double? deltaDistanceM,
  }) async {
    final params = <String, dynamic>{
      'route_id': routeId,
      'latitude': latitude,
      'longitude': longitude,
    };
    if (speedKmh != null) params['speed'] = speedKmh;
    // Round accuracy to the nearest metre — sub-metre precision is noise.
    if (accuracyM != null) params['accuracy_m'] = accuracyM.round();
    if (capturedAt != null) {
      params['captured_at'] = capturedAt.toUtc().toIso8601String();
    }
    // Round to 2 decimal places (cm precision) to keep payload compact.
    if (deltaDistanceM != null) {
      params['delta_distance_m'] =
          double.parse(deltaDistanceM.toStringAsFixed(2));
    }
    await _dio.post(ApiEndpoints.driverLocation, queryParameters: params);
  }

  /// Board the escort — POST /driver/escort/board.
  /// Must be called (with the escort's OTP) before any employee pickup on
  /// routes that have an assigned escort.
  Future<Map<String, dynamic>> escortBoard({
    required String routeId,
    required String otp,
  }) async {
    try {
      _logger.i('Boarding escort for route: $routeId');
      final response = await _dio.post(
        ApiEndpoints.escortBoard,
        queryParameters: {
          'route_id': routeId,
          'otp': int.tryParse(otp) ?? otp, // spec says otp is int
        },
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Cancel Booking
  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      _logger.i('Cancelling booking: $bookingId');
      final response = await _dio.post(ApiEndpoints.cancelBooking, data: {
        'booking_id': bookingId,
      });
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  Map<String, dynamic> _handleError(DioException e) {
    String error = 'Network error';
    String? errorCode;
    
    if (e.response?.data != null) {
      final data = e.response?.data;
      if (data is Map) {
         if (data.containsKey('detail')) {
           final detail = data['detail'];
           if (detail is List) {
             // Handle list of validation errors
             error = detail.map((e) => "${e['loc']?.last}: ${e['msg']}").join(', ');
           } else if (detail is Map) {
             error = detail['message'] ?? 'Validation error';
           } else {
             error = detail.toString();
           }
         } else {
           error = data['message'] ?? 'Server error';
         }
         errorCode = data['code'] ?? data['error_code'];
      }
    }
    return {'success': false, 'error': error, 'errorCode': errorCode};
  }
}
