import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/navigation_service.dart';

/// Full-screen chat interface for a driver ↔ employee conversation.
class ChatScreen extends StatefulWidget {
  final int bookingId;

  /// Display name shown in the AppBar (the employee / passenger's name).
  final String? passengerName;

  /// RTDB path supplied directly by the FCM payload
  final String? firebasePath;

  const ChatScreen({
    super.key,
    required this.bookingId,
    this.passengerName,
    this.firebasePath,
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
    NavigationService.markChatOpen(widget.bookingId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initChat());
  }

  Future<void> _initChat() async {
    final isSameBooking = _chatProvider.currentBookingId == widget.bookingId &&
        _chatProvider.session != null;

    if (!isSameBooking) {
      _chatProvider.clearChat();

      await Future.wait([
        _chatProvider.loadSupportedLanguages(),
        _chatProvider.openSession(widget.bookingId),
      ]);

      if (!mounted) return;
      if (_chatProvider.session == null) return;
    } else {
      if (_chatProvider.supportedLanguages.isEmpty) {
        await _chatProvider.loadSupportedLanguages();
        if (!mounted) return;
      }
    }

    await _chatProvider.loadMessages(widget.bookingId);

    if (!mounted) return;

    final path = _resolveFirebasePath();
    if (path != null) {
      _chatProvider.listenToFirebase(
        path,
        startAfterTimestamp: _chatProvider.lastRestTimestamp,
      );
    }

    _scrollToBottom(animated: false);
  }

  String? _resolveFirebasePath() {
    if (widget.firebasePath?.isNotEmpty == true) return widget.firebasePath;

    final sessionPath = _chatProvider.session?['firebase_path'] as String?;
    if (sessionPath?.isNotEmpty == true) return sessionPath;

    final tenantId = Provider.of<AuthProvider>(context, listen: false).tenantId;
    if (tenantId.isNotEmpty && tenantId != 'N/A') {
      return 'chats/$tenantId/booking_${widget.bookingId}/messages';
    }

    return null;
  }

  void _onProviderUpdate() {
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
    NavigationService.markChatClosed(widget.bookingId);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _chatProvider.isSending) return;

    _textController.clear();
    FocusScope.of(context).unfocus();

    final ok = await _chatProvider.sendMessage(widget.bookingId, text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_chatProvider.error ?? 'Failed to send message', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller) => Column(
          children: [
            // Slide Bar Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.translate_rounded, color: _primaryColor, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Translation Settings',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: const Color(0xFF1E293B)
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: languages.entries.map((entry) {
                  final isSelected = entry.key == current;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? _primaryColor.withOpacity(0.06) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: isSelected ? _primaryColor : Colors.grey.shade400,
                        size: 22,
                      ),
                      title: Text(
                        entry.value,
                        style: GoogleFonts.poppins(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? _primaryColor : const Color(0xFF1E293B),
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        entry.key.toUpperCase(),
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500),
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final ok = await _chatProvider.setLanguage(widget.bookingId, entry.key);
                        if (ok) {
                          await _chatProvider.loadMessages(widget.bookingId);
                          _scrollToBottom(animated: false);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: _buildAppBar(),
      body: Consumer<ChatProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.messages.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: _primaryColor, strokeWidth: 3));
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
      iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _primaryColor.withOpacity(0.2), width: 1.5),
            ),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: _primaryColor.withOpacity(0.1),
              child: const Icon(Icons.person_outline_rounded, color: _primaryColor, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.passengerName ?? 'Passenger Chat',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Consumer<ChatProvider>(
                  builder: (_, p, __) {
                    final langName = p.supportedLanguages[p.driverLanguage];
                    if (langName == null) return const SizedBox.shrink();
                    return Row(
                      children: [
                        const Icon(Icons.g_translate_rounded, size: 10, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          'Translating to $langName',
                          style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
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
            icon: const Icon(Icons.translate_rounded),
            onPressed: p.supportedLanguages.isNotEmpty ? _showLanguagePicker : null,
          ),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 0.8),
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 40, color: Colors.red[600]),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load conversation',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _initChat,
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: Text('Retry', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: _primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              'Send the first message to the passenger.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: provider.messages.length,
      itemBuilder: (context, index) {
        final msg = provider.messages[index];
        final prevMsg = index > 0 ? provider.messages[index - 1] : null;
        return _buildMessageBubble(msg, prevMsg);
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, Map<String, dynamic>? prevMsg) {
    final senderType = (msg['sender_type'] as String?) ?? 'system';
    final isSystem = (msg['is_system_message'] as bool?) ?? (senderType == 'system');

    final prevSender = prevMsg?['sender_type'] as String?;
    final isContinuation = prevSender == senderType && !isSystem;
    final topPadding = isContinuation ? 3.0 : 12.0;

    if (isSystem) return _buildSystemMessage(msg, topPadding);

    final isDriver = senderType == 'driver';
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Row(
        mainAxisAlignment: isDriver ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isDriver) ...[
            if (!isContinuation)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: Colors.grey.shade200,
                  child: Icon(Icons.person_rounded, size: 14, color: Colors.grey.shade500),
                ),
              )
            else
              const SizedBox(width: 26),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isDriver ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _buildBubble(msg, isDriver),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    _formatTimestamp(msg['created_at']?.toString()),
                    style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          if (isDriver) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(Map<String, dynamic> msg, double topPadding) {
    final text = (msg['translated_text'] as String?) ?? (msg['original_text'] as String?) ?? '';

    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: 4),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.shade200, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: Colors.amber[800]),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.amber[900],
                    fontWeight: FontWeight.w500,
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
    final displayText = (msg['translated_text'] as String?)?.trim().isNotEmpty == true
        ? (msg['translated_text'] as String)
        : ((msg['original_text'] as String?) ?? '');

    final originalText = (msg['original_text'] as String?) ?? '';
    final showOriginal = displayText != originalText && originalText.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDriver ? _primaryColor : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isDriver ? 16 : 4),
          bottomRight: Radius.circular(isDriver ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: isDriver ? null : Border.all(color: Colors.grey.withOpacity(0.08), width: 1),
      ),
      child: Column(
        crossAxisAlignment: isDriver ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            displayText,
            style: GoogleFonts.poppins(
              color: isDriver ? Colors.white : const Color(0xFF1E293B),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          // Show original text with globe translation indicator
          if (showOriginal) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.g_translate_rounded, 
                  size: 11, 
                  color: isDriver ? Colors.white.withOpacity(0.5) : Colors.grey.shade400
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    originalText,
                    style: GoogleFonts.poppins(
                      color: isDriver ? Colors.white.withOpacity(0.6) : Colors.grey.shade400,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar(ChatProvider provider) {
    final isActive = (provider.session?['is_active'] as bool?) ?? true;

    if (!isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade100)),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 6),
              Text(
                'This chat session has ended.',
                style: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, -3),
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
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: _primaryColor.withOpacity(0.3), width: 1),
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
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(_primaryColor),
                ),
              ),
            )
          : SizedBox(
              key: const ValueKey('send'),
              width: 44,
              height: 44,
              child: FloatingActionButton.small(
                onPressed: _sendMessage,
                backgroundColor: _primaryColor,
                elevation: 0,
                hoverElevation: 0,
                focusElevation: 0,
                highlightElevation: 0,
                heroTag: null,
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              ),
            ),
    );
  }

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
