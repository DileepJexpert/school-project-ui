import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../services/chat_api_service.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String otherName;

  const ChatScreen(
      {super.key, required this.roomId, required this.otherName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _loading = true;
  List<dynamic> _messages = [];
  bool _sending = false;

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
    setState(() => _loading = true);
    try {
      final data = await ChatApiService.getMessages(widget.roomId);
      if (mounted) {
        setState(() => _messages = data.reversed.toList());
        _scrollToBottom();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markAsRead() async {
    final userId = AuthService.instance.currentUser?.userId ?? '';
    try {
      await ChatApiService.markAsRead(widget.roomId, userId);
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

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
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.instance.currentUser?.userId ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: Text(widget.otherName,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text('No messages yet. Say hello!',
                            style: GoogleFonts.poppins(
                                color: AppColors.textSecondary)))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg =
                              _messages[index] as Map<String, dynamic>;
                          final isMe = msg['senderId'] == userId;
                          return _buildBubble(msg, isMe);
                        },
                      ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg, bool isMe) {
    final text = msg['message'] as String? ?? '';
    final senderName = msg['senderName'] as String? ?? '';
    final senderRole = msg['senderRole'] as String? ?? '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.navy : Colors.grey[100],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text('$senderName ($senderRole)',
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            Text(text,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isMe ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageCtrl,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.navy,
            child: IconButton(
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: _sending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
