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
