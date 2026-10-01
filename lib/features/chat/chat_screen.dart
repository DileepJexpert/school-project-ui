import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/chat_api_service.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String otherName;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.otherName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ChatApiService.getMessages(widget.roomId);
      if (!mounted) return;
      setState(() {
        _messages = data.reversed
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAsRead() async {
    final userId = AuthService.instance.currentUser?.userId ?? '';
    if (userId.isEmpty) return;
    try {
      await ChatApiService.markAsRead(widget.roomId, userId);
    } catch (_) {
      // Read receipts are useful, but should not block opening the chat.
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _messageCtrl.clear();

    final user = AuthService.instance.currentUser;
    try {
      await ChatApiService.sendMessage(widget.roomId, {
        'senderId': user?.userId ?? '',
        'senderName': user?.fullName ?? '',
        'senderRole': user?.role ?? '',
        'message': text,
        'messageType': 'TEXT',
      });
      await _loadMessages();
    } catch (e) {
      _snack('Could not send message: $e', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.instance.currentUser?.userId ?? '';
    final initial =
        widget.otherName.isNotEmpty ? widget.otherName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: context.palette.canvas,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        foregroundColor: AppColors.textPrimary,
        shape: Border(bottom: BorderSide(color: context.palette.border)),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: context.palette.brand.withValues(alpha: 0.1),
              child: Text(
                initial,
                style: GoogleFonts.nunitoSans(
                  color: context.palette.brand,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'School chat',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages(userId)),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessages(String userId) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _InlineState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load messages',
        subtitle: _error!,
        actionLabel: 'Retry',
        onAction: _loadMessages,
      );
    }

    if (_messages.isEmpty) {
      return _InlineState(
        icon: Icons.chat_bubble_outline,
        title: 'No messages yet',
        subtitle: 'Send the first message to start the conversation.',
        actionLabel: 'Refresh',
        onAction: _loadMessages,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: ListView.builder(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          return _MessageBubble(
            message: message,
            isMe: message['senderId'] == userId,
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border(top: BorderSide(color: context.palette.border)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 14,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageCtrl,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  prefixIcon: Icon(Icons.chat_bubble_outline, size: 19),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 46,
              width: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _sending ? null : _sendMessage,
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 19),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final text = _text('message');
    final senderName = _text('senderName');
    final senderRole = _prettyRole(_text('senderRole'));
    final bubbleColor = isMe ? context.palette.brand : context.palette.surface;
    final textColor = isMe ? Colors.white : AppColors.textPrimary;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.68,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            border: isMe ? null : Border.all(color: context.palette.border),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe && (senderName.isNotEmpty || senderRole.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    [senderName, senderRole]
                        .where((item) => item.isNotEmpty)
                        .join(' | '),
                    style: GoogleFonts.nunitoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              Text(
                text,
                style: GoogleFonts.nunitoSans(
                  fontSize: 14,
                  height: 1.35,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _text(String key) {
    final value = message[key];
    return value == null ? '' : value.toString();
  }

  static String _prettyRole(String role) {
    return role.replaceAll('ROLE_', '').replaceAll('_', ' ');
  }
}

class _InlineState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _InlineState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border.all(color: context.palette.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
