import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'api_client.dart';

/// All driver-side chat REST calls.
///
/// Endpoints used:
///   GET  /api/v1/driver/chat/{booking_id}            → open / retrieve session
///   POST /api/v1/driver/chat/{booking_id}/send       → send message
///   GET  /api/v1/driver/chat/{booking_id}/messages   → paginated history
///   POST /api/v1/driver/chat/{booking_id}/language   → set preferred language
///   GET  /api/v1/chat/supported-languages            → public, no token needed
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final Dio _dio = ApiClient().client;
  final Logger _logger = Logger();

  // ---------------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------------

  /// Opens (or retrieves) the chat session for [bookingId].
  /// On the first call the backend creates the session and injects the
  /// warning system message into Postgres + Firebase RTDB.
  Future<Map<String, dynamic>> openSession(int bookingId) async {
    try {
      final response = await _dio.get('/api/v1/driver/chat/$bookingId');
      return {'success': true, 'data': response.data['data']};
    } on DioException catch (e) {
      _logger.e('ChatService.openSession', error: e);
      return {'success': false, 'error': _extractError(e)};
    }
  }

  // ---------------------------------------------------------------------------
  // Messaging
  // ---------------------------------------------------------------------------

  /// Sends [text] to the employee assigned to [bookingId].
  /// Returns the saved message object (includes [firebase_message_id]).
  Future<Map<String, dynamic>> sendMessage(int bookingId, String text) async {
    try {
      final response = await _dio.post(
        '/api/v1/driver/chat/$bookingId/send',
        data: {'text': text},
      );
      return {'success': true, 'data': response.data['data']};
    } on DioException catch (e) {
      _logger.e('ChatService.sendMessage', error: e);
      return {'success': false, 'error': _extractError(e)};
    }
  }

  /// Returns paginated message history for [bookingId].
  /// [translated_text] is pre-selected for the driver's language.
  Future<Map<String, dynamic>> getMessages(
    int bookingId, {
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/driver/chat/$bookingId/messages',
        queryParameters: {'skip': skip, 'limit': limit},
      );
      return {'success': true, 'data': response.data['data']};
    } on DioException catch (e) {
      _logger.e('ChatService.getMessages', error: e);
      return {'success': false, 'error': _extractError(e)};
    }
  }

  // ---------------------------------------------------------------------------
  // Language
  // ---------------------------------------------------------------------------

  /// Sets the driver's preferred display language for this chat session.
  /// Valid values: any ISO 639-1 code returned by [getSupportedLanguages].
  Future<Map<String, dynamic>> setLanguage(
    int bookingId,
    String language,
  ) async {
    try {
      final response = await _dio.post(
        '/api/v1/driver/chat/$bookingId/language',
        data: {'language': language},
      );
      return {'success': true, 'data': response.data['data']};
    } on DioException catch (e) {
      _logger.e('ChatService.setLanguage', error: e);
      return {'success': false, 'error': _extractError(e)};
    }
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  /// Returns the 21 supported ISO 639-1 language codes + human-readable names.
  /// This endpoint is public — no auth token is required.
  Future<Map<String, dynamic>> getSupportedLanguages() async {
    try {
      final response =
          await _dio.get('/api/v1/chat/supported-languages');
      return {'success': true, 'data': response.data['data']};
    } on DioException catch (e) {
      _logger.e('ChatService.getSupportedLanguages', error: e);
      return {'success': false, 'error': _extractError(e)};
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return (data['detail'] ?? data['message'] ?? data['error'] ?? '')
          .toString()
          .trim()
          .isNotEmpty
          ? (data['detail'] ?? data['message'] ?? data['error']).toString()
          : 'HTTP ${e.response?.statusCode ?? 'error'}';
    }
    return e.message ?? 'Network error';
  }
}
