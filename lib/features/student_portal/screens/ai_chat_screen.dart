import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/ai_api_service.dart';

class AiChatScreen extends StatefulWidget {
  final String mode;
  final String? homeworkId;
  final String? subject;

  const AiChatScreen({
    super.key,
    required this.mode,
    this.homeworkId,
    this.subject,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  String? _conversationId;
  bool _sending = false;
  int _questionsToday = 0;
  int _dailyLimit = 20;

  String get _modeLabel => switch (widget.mode) {
        'TUTOR' => 'Tutor Mode',
        'SOLVE' => 'Solve Mode',
        'PRACTICE' => 'Practice Mode',
        _ => 'AI Helper',
      };

  Color get _modeColor => switch (widget.mode) {
        'TUTOR' => const Color(0xFF0D9488),
        'SOLVE' => const Color(0xFF2563EB),
        'PRACTICE' => const Color(0xFFD97706),
        _ => AppColors.navy,
      };

  IconData get _modeIcon => switch (widget.mode) {
        'TUTOR' => Icons.school_outlined,
        'SOLVE' => Icons.lightbulb_outlined,
        'PRACTICE' => Icons.fitness_center_outlined,
        _ => Icons.smart_toy_outlined,
      };

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _sending = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await AiApiService.chat({
        'message': text,
        'mode': widget.mode,
        if (widget.homeworkId != null) 'homeworkId': widget.homeworkId,
        if (_conversationId != null) 'conversationId': _conversationId,
      });

      if (mounted) {
        setState(() {
          _conversationId = response['conversationId'] as String?;
          _messages.add(_ChatMessage(
            role: 'assistant',
            content: response['message'] as String? ?? '',
          ));
          final daily = response['dailyUsage'] as Map<String, dynamic>?;
          if (daily != null) {
            _questionsToday = (daily['questionsToday'] as num?)?.toInt() ?? 0;
            _dailyLimit = (daily['limitPerDay'] as num?)?.toInt() ?? 20;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            role: 'error',
            content: e.toString().replaceAll('DioException', 'Error'),
          ));
        });
      }
    }

    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _modeColor,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_modeIcon, size: 20),
            const SizedBox(width: 8),
            Text(_modeLabel,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 16)),
          ],
        ),
        actions: [
          if (_dailyLimit > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$_questionsToday/$_dailyLimit',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Mode description
          if (_messages.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: _modeColor.withOpacity(0.05),
              child: Column(
                children: [
                  Icon(_modeIcon, size: 48, color: _modeColor),
                  const SizedBox(height: 12),
                  Text(
                    switch (widget.mode) {
                      'TUTOR' =>
                        "I'll guide you step by step without giving the answer directly. Let's learn together!",
                      'SOLVE' =>
                        "I'll solve your problem with a clear, step-by-step explanation.",
                      'PRACTICE' =>
                        "Share a problem and I'll generate similar practice questions for you!",
                      _ => "Ask me anything about your homework!",
                    },
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                  if (widget.subject != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _modeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(widget.subject!,
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _modeColor)),
                    ),
                  ],
                ],
              ),
            ),

          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _sending) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type your question...',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 14, color: AppColors.textLight),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _modeColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: _sending ? Colors.grey : _modeColor,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _sending ? null : _sendMessage,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.send_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';
    final isError = msg.role == 'error';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  isError ? Colors.red.withOpacity(0.1) : _modeColor.withOpacity(0.1),
              child: Icon(
                isError ? Icons.error_outline : _modeIcon,
                size: 16,
                color: isError ? Colors.red : _modeColor,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? _modeColor
                    : isError
                        ? Colors.red.withOpacity(0.05)
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                msg.content,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isUser
                      ? Colors.white
                      : isError
                          ? Colors.red
                          : AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _modeColor.withOpacity(0.1),
            child: Icon(_modeIcon, size: 16, color: _modeColor),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + index * 200),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _modeColor.withOpacity(0.3 + value * 0.4),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class _ChatMessage {
  final String role;
  final String content;

  _ChatMessage({required this.role, required this.content});
}
