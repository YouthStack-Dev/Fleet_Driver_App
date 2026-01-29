import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/route_service.dart';
import 'auth_provider.dart';
import '../services/overlay_service.dart';

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
      if (result['success'] == true) {
        await OverlayService().hideOverlay();
        // Refresh to upcoming
        await fetchTrips(status: 'upcoming');
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
