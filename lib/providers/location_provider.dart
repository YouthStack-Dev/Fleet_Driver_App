import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  
  bool get isTracking => _locationService.isTracking;

  Future<bool> toggleTracking() async {
    if (_locationService.isTracking) {
      await _locationService.stopTracking();
    } else {
      await _locationService.startTracking();
    }
    notifyListeners();
    return _locationService.isTracking;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      return null;
    }
  }
}
