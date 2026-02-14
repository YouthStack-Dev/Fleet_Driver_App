class AppConstants {
  static const String baseUrl = 'https://api.gocab.tech';
}

class ApiEndpoints {
  static const String login = '/api/v1/auth/driver/login';
  static const String newLogin = '/api/v1/auth/driver/new/login';
  static const String loginConfirm = '/api/v1/auth/driver/login/confirm';
  static const String switchCompany = '/api/v1/auth/driver/switch-company';
  static const String deviceVerify = '/api/v1/auth/driver/device/verify';
  static const String selectTenant = '/api/v1/auth/driver/select-tenant';
  static const String driverRefresh = '/api/v1/auth/driver/refresh';
  static const String driverTrips = '/api/v1/driver/trips';
  
  // Duty Management
  static const String dutyStart = '/api/v1/driver/duty/start';
  static const String dutyEnd = '/api/v1/driver/duty/end';
  
  // Trip Operations
  static const String tripStart = '/api/v1/driver/trip/start';
  static const String tripEnd = '/api/v1/driver/trip/drop'; // Fix: consistent naming
  static const String noShow = '/api/v1/driver/trip/no-show';
  static const String tripDrop = '/api/v1/driver/trip/drop'; // Duplicate but keep for safety if used elsewhere
  
  static const String bookings = '/api/v1/bookings/employee';
  static const String bookingDetails = '/api/v1/bookings'; 
  static const String weekoffConfig = '/api/v1/weekoff-configs';
  static const String shifts = '/api/v1/shifts';
  static const String createBooking = '/api/v1/bookings';
  static const String cancelBooking = '/api/v1/bookings/cancel';
}

class FirebaseConfig {
  static const String databaseUrl = 'https://ets-1-ccb71-default-rtdb.firebaseio.com';
}

class LocationConfig {
  static const int updateIntervalMs = 30000;
  static const int distanceFilterMeters = 10;
}
