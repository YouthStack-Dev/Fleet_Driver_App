class AppConstants {
  static const String baseUrl = 'https://api.mltcorporate.com';
}

class ApiEndpoints {
  // Auth - Driver (2-step: device verify → select tenant)
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
  
  static const String bookings = '/api/v1/bookings/employee';
  static const String bookingDetails = '/api/v1/bookings'; 
  static const String weekoffConfig = '/api/v1/weekoff-configs';
  static const String shifts = '/api/v1/shifts';
  static const String createBooking = '/api/v1/bookings';
  static const String cancelBooking = '/api/v1/bookings/cancel';

  // Driver Config & Speed Monitoring
  static const String driverConfig = '/api/v1/driver/config';
  static const String speedViolation = '/api/v1/speed-violations/';

  // Driver Location Ping (IMP-1 / IMP-2 / IMP-9)
  /// POST — send GPS ping every 5–10 s while route is ONGOING.
  /// Query params: route_id, latitude, longitude, speed (km/h, optional).
  static const String driverLocation = '/api/v1/driver/location';

  // Escort
  /// POST — board the escort before any employee pickup on escort routes.
  /// Query params: route_id, otp.
  static const String escortBoard = '/api/v1/driver/escort/board';

  // Chat — Driver endpoints
  /// GET  /api/v1/driver/chat/{booking_id}          → open / retrieve session
  /// POST /api/v1/driver/chat/{booking_id}/send     → send message
  /// GET  /api/v1/driver/chat/{booking_id}/messages → paginated history
  /// POST /api/v1/driver/chat/{booking_id}/language → set language
  static String driverChatSession(int bookingId) =>
      '/api/v1/driver/chat/$bookingId';
  static String driverChatSend(int bookingId) =>
      '/api/v1/driver/chat/$bookingId/send';
  static String driverChatMessages(int bookingId) =>
      '/api/v1/driver/chat/$bookingId/messages';
  static String driverChatLanguage(int bookingId) =>
      '/api/v1/driver/chat/$bookingId/language';

  // Chat — public utility
  static const String chatSupportedLanguages =
      '/api/v1/chat/supported-languages';

  // Push notifications
  /// POST — register / update the driver's FCM token with the backend.
  /// Must be called after every login and whenever Firebase rotates the token.
  static const String fcmTokenRegister =
      '/api/v1/push-notifications/register-token';
}

class FirebaseConfig {
  static const String databaseUrl = 'https://ets-1-ccb71-default-rtdb.firebaseio.com';
}

class LocationConfig {
  /// How often the GPS stream ticks — 1 s for live speed display on screen.
  static const int updateIntervalMs = 1000;

  /// Minimum movement before a GPS event fires (0 = always fire on interval).
  /// Kept at 0 so the speed HUD refreshes every second regardless of movement.
  /// Stationary drift is filtered inside _maybeSendLocationPing instead.
  static const int distanceFilterMeters = 0;

  /// How often a location ping is sent to POST /driver/location while ONGOING.
  /// Spec: every 5–10 s. Using 7 s as the midpoint.
  static const int locationPingIntervalMs = 7000;

  /// Speed (km/h) below which the stationary-drift guard is applied.
  /// When device GPS reports a speed below this value, a ping is only sent
  /// if the device has actually moved at least [minimumPingDistanceM] metres
  /// since the last successful ping — preventing GPS jitter (±5–15 m while
  /// parked) from accumulating as phantom distance on the server.
  static const double stationarySpeedThresholdKmh = 5.0;

  /// Minimum physical movement (metres) required before a ping fires while the
  /// vehicle is stationary (speed < [stationarySpeedThresholdKmh]).
  static const double minimumPingDistanceM = 15.0;

  /// Maximum age (seconds) of a location ping before a retry is discarded.
  /// Retries older than this would deliver stale coordinates with a wrong
  /// timeline position, corrupting the server-side distance calculation.
  static const int stalePingThresholdSeconds = 15;
}
