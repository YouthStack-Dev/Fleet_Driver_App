import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../services/navigation_service.dart';

/// Full-screen chat interface for a driver ↔ employee conversation.
///
/// Usage — push from the passenger card:
/// ```dart
/// Navigator.pushNamed(context, '/chat', arguments: {
///   'booking_id': stop['booking_id'] as int,
///   'passenger_name': stop['employee_name'] as String?,
/// });
/// ```
class ChatScreen extends StatefulWidget {
  final int bookingId;

  /// Display name shown in the AppBar (the employee / passenger's name).
  final String? passengerName;

  const ChatScreen({
    super.key,
    required this.bookingId,
    this.passengerName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const Color _primaryColor = Color(0xFF6C63FF);

  late ChatProvider _chatProvider;

  @override
  void initState() {
    super.initState();
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _chatProvider.addListener(_onProviderUpdate);
    // Tell the notification service this booking's chat is now on screen so
    // it can suppress redundant push-notification banners.
    NavigationService.markChatOpen(widget.bookingId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initChat());
  }

  // ---------------------------------------------------------------------------
  // Init & lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _initChat() async {
    // If the provider already has state for this booking (e.g. the driver
    // pressed back and then reopened the same chat), skip the full reset and
    // just refresh the REST history.  The Firebase listener stays alive so
    // messages received while the screen was closed are already in _messages.
    final isSameBooking = _chatProvider.currentBookingId == widget.bookingId &&
        _chatProvider.session != null;

    if (!isSameBooking) {
      // Different booking or first open — full reset.
      _chatProvider.clearChat();

      // Load supported languages in parallel with session open so the language
      // picker is ready as soon as the screen settles.
      await Future.wait([
        _chatProvider.loadSupportedLanguages(),
        _chatProvider.openSession(widget.bookingId),
      ]);

      if (!mounted) return;
      if (_chatProvider.session == null) return; // openSession failed
    } else {
      // Same booking re-open: ensure language list is populated if missing
      // (edge case: app restarted with an in-progress booking).
      if (_chatProvider.supportedLanguages.isEmpty) {
        await _chatProvider.loadSupportedLanguages();
        if (!mounted) return;
      }
    }

    // Refresh REST history (merges with any Firebase-only messages that
    // arrived while the screen was closed).
    await _chatProvider.loadMessages(widget.bookingId);

    if (!mounted) return;

    // Attach Firebase listener AFTER loading history so _knownKeys is
    // populated.  Idempotent — calling again with the same path is a no-op,
    // so the listener is never needlessly cancelled and re-created.
    final firebasePath =
        _chatProvider.session?['firebase_path'] as String?;
    if (firebasePath != null && firebasePath.isNotEmpty) {
      _chatProvider.listenToFirebase(firebasePath);
    }

    _scrollToBottom(animated: false);
  }

  void _onProviderUpdate() {
    // Auto-scroll to the bottom when a new message arrives, but only if
    // the user is already near the bottom (≤ 120 px away).
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 120) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          max,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(max);
      }
    });
  }

  @override
  void dispose() {
    _chatProvider.removeListener(_onProviderUpdate);
    // Mark the chat screen as no longer visible so the notification service
    // can resume showing banners for this booking.
    NavigationService.markChatClosed(widget.bookingId);
    // Do NOT cancel the Firebase listener here.  The provider is a singleton
    // that outlives this screen, and the listener must stay alive so messages
    // sent by the employee while the chat screen is closed are received and
    // shown immediately when the driver reopens the screen.
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _chatProvider.isSending) return;

    _textController.clear();
    FocusScope.of(context).unfocus();

    final ok =
        await _chatProvider.sendMessage(widget.bookingId, text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _chatProvider.error ?? 'Failed to send message'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
    if (ok) _scrollToBottom();
  }

  void _showLanguagePicker() {
    final languages = _chatProvider.supportedLanguages;
    final current = _chatProvider.driverLanguage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        builder: (_, controller) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 12, horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.translate,
                      color: _primaryColor, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Chat Language',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: controller,
                children: languages.entries.map((entry) {
                  final isSelected = entry.key == current;
                  return ListTile(
                    leading: isSelected
                        ? const Icon(Icons.check_circle,
                            color: _primaryColor)
                        : const Icon(Icons.radio_button_unchecked,
                            color: Colors.grey),
                    title: Text(entry.value),
                    subtitle: Text(entry.key,
                        style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    selectedTileColor:
                        _primaryColor.withOpacity(0.07),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ok = await _chatProvider.setLanguage(
                          widget.bookingId, entry.key);
                      if (ok) {
                        // Reload with newly-translated texts.
                        await _chatProvider.loadMessages(
                            widget.bookingId);
                        _scrollToBottom(animated: false);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(),
      body: Consumer<ChatProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.messages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.messages.isEmpty) {
            return _buildErrorState(provider.error!);
          }

          return Column(
            children: [
              Expanded(child: _buildMessageList(provider)),
              _buildInputBar(provider),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _primaryColor.withOpacity(0.15),
            child: const Icon(Icons.person,
                color: _primaryColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.passengerName ?? 'Chat',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Consumer<ChatProvider>(
                  builder: (_, p, __) {
                    final langName =
                        p.supportedLanguages[p.driverLanguage];
                    if (langName == null) return const SizedBox.shrink();
                    return Text(
                      'Translating to $langName',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Consumer<ChatProvider>(
          builder: (_, p, __) => IconButton(
            icon: const Icon(Icons.translate, color: Colors.black87),
            tooltip: 'Change language',
            onPressed: p.supportedLanguages.isNotEmpty
                ? _showLanguagePicker
                : null,
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: Colors.grey[200], height: 1),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline,
                size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _initChat,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ChatProvider provider) {
    if (provider.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No messages yet.\nSend the first one!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: provider.messages.length,
      itemBuilder: (context, index) {
        final msg = provider.messages[index];
        final prevMsg = index > 0 ? provider.messages[index - 1] : null;
        return _buildMessageBubble(msg, prevMsg);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Message bubble
  // ---------------------------------------------------------------------------

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    Map<String, dynamic>? prevMsg,
  ) {
    final senderType =
        (msg['sender_type'] as String?) ?? 'system';
    final isSystem =
        (msg['is_system_message'] as bool?) ?? (senderType == 'system');

    // Group spacing: tighter when consecutive messages from same sender.
    final prevSender = prevMsg?['sender_type'] as String?;
    final isContinuation = prevSender == senderType && !isSystem;
    final topPadding = isContinuation ? 2.0 : 10.0;

    if (isSystem) return _buildSystemMessage(msg, topPadding);

    final isDriver = senderType == 'driver';
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: 0),
      child: Row(
        mainAxisAlignment:
            isDriver ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isDriver) ...[
            if (!isContinuation)
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFFE8E8E8),
                child:
                    Icon(Icons.person, size: 16, color: Colors.grey),
              )
            else
              const SizedBox(width: 28),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isDriver
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _buildBubble(msg, isDriver),
                const SizedBox(height: 2),
                Text(
                  _formatTimestamp(
                      msg['created_at']?.toString()),
                  style: const TextStyle(
                      fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (isDriver) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(
      Map<String, dynamic> msg, double topPadding) {
    final text = (msg['translated_text'] as String?) ??
        (msg['original_text'] as String?) ??
        '';

    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: 4),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber[200]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline,
                  size: 13, color: Colors.amber[700]),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber[900],
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg, bool isDriver) {
    final displayText = (msg['translated_text'] as String?)
            ?.trim()
            .isNotEmpty ==
        true
        ? (msg['translated_text'] as String)
        : ((msg['original_text'] as String?) ?? '');

    final originalText =
        (msg['original_text'] as String?) ?? '';
    final showOriginal = displayText != originalText &&
        originalText.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isDriver ? _primaryColor : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isDriver ? 18 : 4),
          bottomRight: Radius.circular(isDriver ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: isDriver
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            displayText,
            style: TextStyle(
              color: isDriver ? Colors.white : Colors.black87,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          // Show original language text beneath when translated.
          if (showOriginal) ...[
            const SizedBox(height: 4),
            Text(
              originalText,
              style: TextStyle(
                color:
                    isDriver ? Colors.white60 : Colors.black38,
                fontSize: 11,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Input bar
  // ---------------------------------------------------------------------------

  Widget _buildInputBar(ChatProvider provider) {
    final isActive =
        (provider.session?['is_active'] as bool?) ?? true;

    if (!isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline,
                  size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                'This chat session has ended.',
                style: TextStyle(
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                    fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  maxLength: 1000,
                  keyboardType: TextInputType.multiline,
                  textCapitalization:
                      TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle:
                        TextStyle(color: Colors.grey[400]),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(24),
                      borderSide: BorderSide(
                          color: _primaryColor.withOpacity(0.5),
                          width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildSendButton(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton(ChatProvider provider) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: provider.isSending
          ? Container(
              key: const ValueKey('loading'),
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(_primaryColor)),
              ),
            )
          : SizedBox(
              key: const ValueKey('send'),
              width: 44,
              height: 44,
              child: FloatingActionButton.small(
                onPressed: _sendMessage,
                backgroundColor: _primaryColor,
                elevation: 2,
                heroTag: null,
                child: const Icon(Icons.send,
                    color: Colors.white, size: 20),
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatTimestamp(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ap = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ap';
    } catch (_) {
      return '';
    }
  }
}
