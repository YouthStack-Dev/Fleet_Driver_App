import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/chat_service.dart';

/// Manages chat state for a single booking session.
///
/// Lifecycle:
///   1. Call [openSession] → retrieves (or creates) the session, sets
///      [session] and [currentBookingId].
///   2. Call [loadMessages] → fills [messages] from the REST history endpoint,
///      merging any Firebase-only messages that haven't been flushed to REST yet.
///   3. Call [listenToFirebase] → attaches RTDB childAdded / childChanged
///      listeners so new messages and translation patches arrive live.
///      Idempotent — calling again with the same path is a no-op.
///   4. Call [clearChat] only when switching to a *different* booking or
///      logging out. Do NOT call it (or [cancelFirebaseListener]) on ordinary
///      screen disposal — the listener intentionally stays alive so messages
///      received while the chat screen is in the background are not missed.
class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  Map<String, dynamic>? _session;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  Map<String, String> _supportedLanguages = {};

  Map<String, dynamic>? get session => _session;
  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  Map<String, String> get supportedLanguages => _supportedLanguages;

  /// Driver's currently selected language code (default 'en').
  String get driverLanguage => (_session?['driver_language'] as String?) ?? 'en';

  // ---------------------------------------------------------------------------
  // Booking / Firebase listener tracking
  // ---------------------------------------------------------------------------

  /// The booking ID currently loaded in this provider.
  /// Used by ChatScreen to decide whether a full reset is needed on re-open.
  int? _currentBookingId;
  String? _currentFirebasePath;

  int? get currentBookingId => _currentBookingId;
  String? get currentFirebasePath => _currentFirebasePath;

  StreamSubscription<DatabaseEvent>? _childAddedSub;
  StreamSubscription<DatabaseEvent>? _childChangedSub;

  /// Set to true when the RTDB subscription receives an error event.
  /// Forces a full re-subscription on the next [listenToFirebase] call even
  /// when the path hasn't changed — the most common cause is a Firebase
  /// security-rule denial or a stale connection that needs to be reset.
  bool _listenerHadError = false;

  /// Push-keys of messages already in [_messages], used for deduplication.
  /// The REST response returns each message's Firebase push-key as
  /// [firebase_message_id], so both sources share the same key space.
  final Set<String> _knownKeys = {};

  /// The millisecond-epoch timestamp of the most recent message returned by
  /// the last [loadMessages] call.  Passed to [listenToFirebase] as
  /// [startAfterTimestamp] so the RTDB query only delivers messages that are
  /// genuinely newer than the REST history — avoids re-delivering all 79+
  /// existing messages as [childAdded] events on every subscription.
  int _lastRestTimestamp = 0;
  int get lastRestTimestamp => _lastRestTimestamp;

  // ---------------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------------

  Future<bool> openSession(int bookingId) async {
    _setLoading(true);
    _error = null;
    try {
      final result = await _chatService.openSession(bookingId);
      if (result['success'] == true) {
        _session = _asMap(result['data']);
        _currentBookingId = bookingId;
        return true;
      }
      _error = result['error']?.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Message history (REST)
  // ---------------------------------------------------------------------------

  /// Loads (or refreshes) the message history from REST.
  ///
  /// Merges with any Firebase-only messages currently in [_messages] that
  /// haven't been flushed to REST yet, so live-arriving messages are never
  /// lost during a refresh.
  Future<void> loadMessages(int bookingId,
      {int skip = 0, int limit = 50}) async {
    _setLoading(true);
    _error = null;
    try {
      final result = await _chatService.getMessages(bookingId,
          skip: skip, limit: limit);
      if (result['success'] == true) {
        final data = _asMap(result['data']);
        final rawList = data['messages'] as List? ?? [];
        final restMessages =
            rawList.map((m) => _asMap(m)).toList();

        // Build a set of keys returned by REST.
        final restKeys = <String>{};
        for (final msg in restMessages) {
          final key = msg['firebase_message_id'] as String?;
          if (key != null && key.isNotEmpty) restKeys.add(key);
        }

        // Preserve Firebase-only messages not yet flushed to REST so that
        // messages received via the live listener aren't lost during a refresh.
        final firebaseOnly = _messages.where((m) {
          final key = m['firebase_message_id'] as String?;
          return key != null && key.isNotEmpty && !restKeys.contains(key);
        }).toList();

        // Merge REST history with any Firebase-only messages and sort by time.
        _messages = [...restMessages, ...firebaseOnly];
        _messages.sort((a, b) {
          final da = (a['created_at'] as String?) ?? '';
          final db = (b['created_at'] as String?) ?? '';
          return da.compareTo(db);
        });

        // Rebuild known-keys from the merged list.
        _knownKeys.clear();
        _knownKeys.addAll(restKeys);
        for (final msg in firebaseOnly) {
          final key = msg['firebase_message_id'] as String?;
          if (key != null && key.isNotEmpty) _knownKeys.add(key);
        }

        // Record the latest timestamp so listenToFirebase can use startAfter.
        _lastRestTimestamp = 0;
        for (final msg in _messages) {
          final tsStr = msg['created_at'] as String?;
          if (tsStr != null && tsStr.isNotEmpty) {
            try {
              final ms = DateTime.parse(tsStr).millisecondsSinceEpoch;
              if (ms > _lastRestTimestamp) _lastRestTimestamp = ms;
            } catch (_) {}
          }
        }

        // The REST /messages response also returns the session object.
        if (data['session'] != null) {
          _session = _asMap(data['session']);
        }
      } else {
        _error = result['error']?.toString();
      }
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Send message
  // ---------------------------------------------------------------------------

  Future<bool> sendMessage(int bookingId, String text) async {
    _isSending = true;
    notifyListeners();
    try {
      final result = await _chatService.sendMessage(bookingId, text);
      if (result['success'] == true) {
        final msg = _asMap(result['data']);
        // Add to list immediately (optimistic) if not already present.
        _addIfNew(msg);
        return true;
      }
      _error = result['error']?.toString();
      notifyListeners();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Language
  // ---------------------------------------------------------------------------

  Future<bool> setLanguage(int bookingId, String language) async {
    try {
      final result = await _chatService.setLanguage(bookingId, language);
      if (result['success'] == true) {
        // The response is the updated session object.
        if (result['data'] != null) {
          _session = _asMap(result['data']);
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Supported languages
  // ---------------------------------------------------------------------------

  Future<void> loadSupportedLanguages() async {
    try {
      final result = await _chatService.getSupportedLanguages();
      if (result['success'] == true) {
        final data = _asMap(result['data']);
        final langs = data['languages'] as Map? ?? {};
        _supportedLanguages =
            langs.map((k, v) => MapEntry(k.toString(), v.toString()));
        notifyListeners();
      }
    } catch (_) {
      // Non-fatal — the picker simply won't show options.
    }
  }

  // ---------------------------------------------------------------------------
  // Firebase RTDB real-time listener
  // ---------------------------------------------------------------------------

  /// Attaches live listeners to [firebasePath] (e.g.
  /// `chats/SAM001/booking_1/messages`).
  ///
  /// **Idempotent** — if already listening to the same path, this is a no-op.
  /// The listener is intentionally kept alive across screen dispose/remount
  /// so that messages sent while the chat screen is closed are not missed.
  ///
  /// • [childAdded]   → new messages arrive without polling.
  /// • [childChanged] → translation patches update [translated_text] in-place.
  ///
  /// [startAfterTimestamp] — millisecond-epoch timestamp (from
  /// [lastRestTimestamp]) used to tell Firebase to only deliver children with
  /// `timestamp > startAfterTimestamp`.  Eliminates duplicate delivery of the
  /// 79+ messages already loaded from REST on every fresh subscription.
  /// Pass 0 (default) to receive all children (used when there are no REST
  /// messages yet).
  ///
  /// Call this AFTER [loadMessages] so [_knownKeys] is populated and
  /// existing messages are not duplicated.
  void listenToFirebase(String firebasePath, {int startAfterTimestamp = 0}) {
    // Idempotency: skip if already listening to this exact path AND the
    // previous subscription had no errors.  If an error was received we must
    // force a re-subscription (the stream is broken and won't recover).
    if (!_listenerHadError &&
        _currentFirebasePath == firebasePath &&
        _childAddedSub != null &&
        _childChangedSub != null) {
      return;
    }

    // Cancel any prior subscription (e.g. switching bookings or forced retry).
    cancelFirebaseListener();
    _currentFirebasePath = firebasePath;
    _listenerHadError = false; // reset — fresh subscription

    // Use orderByChild('timestamp') so Firebase delivers children in
    // chronological order and respects any ".indexOn": ["timestamp"] security
    // rule.  Without this query modifier, RTDB often fails to push new child
    // events in real-time on Android (the driver would only see new messages
    // after a manual refresh).
    //
    // When startAfterTimestamp > 0 (the common case after loadMessages), apply
    // startAfter so the RTDB query only delivers messages that are genuinely
    // newer than the REST history.  This eliminates the duplicate-delivery
    // problem: without it, Firebase would fire childAdded for every existing
    // message in the node on every new subscription.
    Query query;
    try {
      final ref = FirebaseDatabase.instance
          .ref(firebasePath)
          .orderByChild('timestamp');
      query = startAfterTimestamp > 0
          ? ref.startAfter(startAfterTimestamp)
          : ref;
    } catch (e) {
      debugPrint('ChatProvider: Firebase ref error: $e');
      return;
    }

    // --- childAdded ---
    _childAddedSub = query.onChildAdded.listen(
      (event) {
        final key = event.snapshot.key;
        if (key == null) return;

        // Skip messages already loaded from REST.
        if (_knownKeys.contains(key)) return;

        final msg = _firebaseSnapshotToMessage(key, event.snapshot.value);
        if (msg == null) return;

        _knownKeys.add(key);
        _messages.add(msg);
        // Re-sort after every insert so late-arriving messages (network jitter)
        // don't appear out of chronological order in the UI.
        _messages.sort((a, b) {
          final da = (a['created_at'] as String?) ?? '';
          final db = (b['created_at'] as String?) ?? '';
          return da.compareTo(db);
        });
        notifyListeners();
      },
      onError: (e) {
        debugPrint('ChatProvider: childAdded error: $e');
        // Mark the subscription as broken.  The next listenToFirebase() call
        // (triggered when the driver re-opens the chat screen) will force a
        // full re-subscription instead of returning early from the
        // idempotency check.
        _listenerHadError = true;
      },
    );

    // --- childChanged (translation patches) ---
    _childChangedSub = query.onChildChanged.listen(
      (event) {
        final key = event.snapshot.key;
        if (key == null) return;

        final updated =
            _firebaseSnapshotToMessage(key, event.snapshot.value);
        if (updated == null) return;

        // Find the existing message and patch translated_text.
        final idx = _messages
            .indexWhere((m) => m['firebase_message_id'] == key);
        if (idx != -1) {
          final translatedText = updated['translated_text'];
          if (translatedText != null) {
            _messages[idx] = {
              ..._messages[idx],
              'translated_text': translatedText,
            };
            notifyListeners();
          }
        }
      },
      onError: (e) {
        debugPrint('ChatProvider: childChanged error: $e');
        _listenerHadError = true;
      },
    );
  }

  void cancelFirebaseListener() {
    _childAddedSub?.cancel();
    _childAddedSub = null;
    _childChangedSub?.cancel();
    _childChangedSub = null;
    _currentFirebasePath = null;
    _listenerHadError = false;
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Clears all chat state and cancels the Firebase listener.
  ///
  /// Call only when the driver switches to a different booking or logs out.
  /// Do NOT call on ordinary screen disposal — the listener should stay alive
  /// so messages are received even when the chat screen is not visible.
  void clearChat() {
    cancelFirebaseListener();
    _session = null;
    _messages = [];
    _error = null;
    _isLoading = false;
    _isSending = false;
    _knownKeys.clear();
    _lastRestTimestamp = 0;
    _currentBookingId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    cancelFirebaseListener();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Adds [msg] to [_messages] only if its firebase_message_id is not already
  /// tracked.  Falls back to appending unconditionally when there is no ID.
  void _addIfNew(Map<String, dynamic> msg) {
    final key = msg['firebase_message_id'] as String?;
    if (key != null && key.isNotEmpty) {
      if (_knownKeys.contains(key)) return;
      _knownKeys.add(key);
    }
    _messages.add(msg);
  }

  /// Converts a Firebase RTDB snapshot value into a normalised message map
  /// that matches the shape returned by the REST API.
  Map<String, dynamic>? _firebaseSnapshotToMessage(
      String key, Object? value) {
    if (value is! Map) return null;
    final data = Map<String, dynamic>.from(value);

    final ts = data['timestamp'];
    final createdAt = ts is int
        ? DateTime.fromMillisecondsSinceEpoch(ts).toIso8601String()
        : DateTime.now().toIso8601String();

    return {
      'firebase_message_id': key,
      'sender_type': (data['sender_type'] as String?) ?? 'system',
      'sender_id': data['sender_id'],
      'original_text': (data['original_text'] as String?) ?? '',
      'original_language':
          (data['original_language'] as String?) ?? 'en',
      'translated_text': (data['translated_text'] as String?) ??
          (data['original_text'] as String?) ??
          '',
      'is_system_message': data['is_system'] == true,
      'created_at': createdAt,
      'id': null,
    };
  }

  static Map<String, dynamic> _asMap(dynamic raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
}
