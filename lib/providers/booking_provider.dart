import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/route_service.dart';
import 'auth_provider.dart';
import '../services/overlay_service.dart';
import '../services/background_tracking_service.dart';
import '../services/session_service.dart';

class BookingProvider extends ChangeNotifier {
  final RouteService _routeService = RouteService();
  
  List<dynamic> _routes = [];
  List<dynamic> _bookings = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get routes => _routes;
  List<dynamic> get bookings => _bookings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void clearData() {
    _routes = [];
    _bookings = [];
    _error = null;
    notifyListeners();
  }

  Future<void> fetchTrips({String status = 'upcoming'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _routeService.getDriverTrips(statusFilter: status);
      if (result['success'] == true) {
        _routes = result['routes'] ?? [];
      } else {
        _error = result['error'];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBookings(BuildContext context, {int skip = 0, int limit = 100}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.currentUser;
      // Try to find employee_id in various places
      final employeeId = user?['employee_id'] ?? 
                         user?['user']?['employee_id'] ?? 
                         user?['employee']?['id'];

      final params = {
        'skip': skip,
        'limit': limit,
      };
      
      if (employeeId != null) {
        params['employee_id'] = employeeId;
      }
      
      final result = await _routeService.getEmployeeBookings(params: params);
      
      if (result['success'] == true) {
        _bookings = result['bookings'] ?? [];
      } else {
        _error = result['error'];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> cancelBooking(BuildContext context, String bookingId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _routeService.cancelBooking(bookingId);
      if (result['success'] == true) {
        await fetchBookings(context);
        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> startDuty(String routeId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _routeService.startDuty(routeId);
      if (result['success'] == true) {
        // Refresh routes
        await fetchTrips(status: 'ongoing');
        
        // Show overlay when duty starts
        await OverlayService().showOverlay();

        // Update the active route in SessionService when duty starts
        await SessionService().saveActiveRoute(routeId);
        await SessionService().setTrackingEnabled(true);

        // Start Kotlin background foreground service for persistent GPS tracking
        final token = await SessionService().getAccessToken() ?? '';
        
        final userData = await SessionService().getUserData();
        final driverId = userData?['driver_id'] ?? userData?['user']?['driver']?['driver_id'] ?? userData?['driver']?['driver_id'];
        final tenantId = userData?['tenant_id'] ?? userData?['account']?['tenant_id'] ?? userData?['user']?['tenant_id'] ?? userData?['user']?['tenant']?['tenant_id'];
        final vendorId = userData?['vendor_id'] ?? userData?['account']?['vendor_id'] ?? userData?['user']?['driver']?['vendor_id'];

        await BackgroundTrackingService().startBackgroundTracking(
          routeId: routeId,
          accessToken: token,
          driverId: driverId?.toString(),
          tenantId: tenantId?.toString(),
          vendorId: vendorId?.toString(),
        );

        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> startTrip(String routeId, String bookingId, String? otp, double lat, double lng) async {
    return _performAction(() => _routeService.startTrip(
      routeId: routeId, 
      bookingId: bookingId, 
      otp: otp, 
      latitude: lat, 
      longitude: lng
    ));
  }

  Future<Map<String, dynamic>> dropTrip(String routeId, String bookingId, String? otp, double lat, double lng) async {
     return _performAction(() => _routeService.dropTrip(
      routeId: routeId,
      bookingId: bookingId,
      otp: otp,
      latitude: lat,
      longitude: lng
    ));
  }

  /// Board the escort on an ONGOING route before any employee pickup.
  /// Calls POST /driver/escort/board with the escort's OTP.
  Future<Map<String, dynamic>> escortBoard(String routeId, String otp) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _routeService.escortBoard(routeId: routeId, otp: otp);
      if (result['success'] == true) {
        await fetchTrips(status: 'ongoing'); // Refresh so escort_boarded flag updates
      } else {
        _error = result['error'];
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> markNoShow(String routeId, String bookingId, String? reason) async {
    return _performAction(() => _routeService.markNoShow(
      routeId: routeId,
      bookingId: bookingId,
      reason: reason
    ));
  }

  Future<Map<String, dynamic>> endDuty(String routeId, String? reason) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _routeService.endDuty(routeId, reason);
      
      final bool success = result['success'] == true;
      final errorMsg = result['error']?.toString().toLowerCase() ?? '';
      final errorCode = result['errorCode']?.toString().toUpperCase() ?? '';
      
      final bool alreadyEnded = !success && (
        errorMsg.contains('already ended') || 
        errorMsg.contains('not active') || 
        errorMsg.contains('no active duty') ||
        errorCode.contains('ALREADY_ENDED') || 
        errorCode.contains('NOT_ACTIVE') ||
        errorCode.contains('DUTY_ENDED')
      );

      if (success || alreadyEnded) {
        await OverlayService().hideOverlay();
        
        // Clear active route when duty ends (or fails because it already ended)
        await SessionService().clearActiveRoute();
        await SessionService().setTrackingEnabled(false);
        
        // Stop Kotlin background service — trip is over
        await BackgroundTrackingService().stopBackgroundTracking();
        
        Map<String, dynamic>? summaryData;
        try {
          // Wait 2 seconds for backend to finish calculations
          await Future.delayed(const Duration(seconds: 2));
          final completedTrips = await _routeService.getDriverTrips(statusFilter: 'completed');
          if (completedTrips['success'] == true && completedTrips['routes'] is List && completedTrips['routes'].isNotEmpty) {
            final routes = completedTrips['routes'] as List;
            final endedRoute = routes.firstWhere(
              (r) => r['route_id']?.toString() == routeId,
              orElse: () => routes.first,
            );
            summaryData = {
              'actual_total_distance': endedRoute['actual_total_distance'],
              'actual_total_time': endedRoute['actual_total_time'],
              'estimated_total_distance': endedRoute['estimated_total_distance'],
              'estimated_total_time': endedRoute['estimated_total_time'],
              'route_code': endedRoute['route_code'] ?? endedRoute['route_id']?.toString() ?? routeId,
              'stops_count': endedRoute['stops'] is List ? (endedRoute['stops'] as List).length : 0,
              'boarded_count': endedRoute['stops'] is List
                  ? (endedRoute['stops'] as List).where((s) => s['status'] == 'Completed').length
                  : 0,
            };
          }
        } catch (e) {
          debugPrint('⚠️ Error fetching completed duty summary: $e');
        }

        // Refresh to upcoming
        await fetchTrips(status: 'upcoming');

        return {
          'success': true,
          if (summaryData != null) 'summary': summaryData,
        };
      } else {
        _error = result['error'];
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _performAction(Future<Map<String, dynamic>> Function() action) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await action();
      if (result['success'] == true) {
        await fetchTrips(status: 'ongoing'); // Refresh
      } else {
        _error = result['error'];
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
