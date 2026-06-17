import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/bulk_message_api_service.dart';

class BulkMessageScreen extends StatefulWidget {
  const BulkMessageScreen({super.key});

  @override
  State<BulkMessageScreen> createState() => _BulkMessageScreenState();
}

class _BulkMessageScreenState extends State<BulkMessageScreen> {
  // --- Compose state ---
  String _channel = 'EMAIL';
  String _targetAudience = 'All Parents';
  String? _targetClass;
  final _customRecipientsController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _sending = false;

  // --- History state ---
  bool _loadingHistory = true;
  List<Map<String, dynamic>> _messages = [];

  static const _channels = ['EMAIL', 'SMS', 'BOTH'];
  static const _audiences = [
    'All Parents',
    'Class Specific',
    'All Staff',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _customRecipientsController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final data = await BulkMessageApiService.getAllMessages();
      if (mounted) setState(() => _messages = data);
    } catch (_) {}
    if (mounted) setState(() => _loadingHistory = false);
  }

  Future<void> _sendMessage() async {
    if (_bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message body is required')),
      );
      return;
    }
    if ((_channel == 'EMAIL' || _channel == 'BOTH') &&
        _subjectController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject is required for email messages')),
      );
      return;
    }
    if (_targetAudience == 'Class Specific' && _targetClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target class')),
      );
      return;
    }
    if (_targetAudience == 'Custom' &&
        _customRecipientsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter custom recipients')),
      );
      return;
    }

    final audienceLabel = _targetAudience == 'Class Specific'
        ? '$_targetAudience ($_targetClass)'
        : _targetAudience;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        ),
        title: Text('Confirm Send',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to send this message to $audienceLabel recipients via $_channel?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Send', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _sending = true);
    try {
      final data = <String, dynamic>{
        'channel': _channel,
        'targetAudience': _targetAudience,
        'body': _bodyController.text.trim(),
      };
      if (_subjectController.text.trim().isNotEmpty) {
        data['subject'] = _subjectController.text.trim();
      }
      if (_targetAudience == 'Class Specific' && _targetClass != null) {
        data['targetClass'] = _targetClass;
      }
      if (_targetAudience == 'Custom') {
        data['customRecipients'] = _customRecipientsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      await BulkMessageApiService.sendBulkMessage(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        _subjectController.clear();
        _bodyController.clear();
        _customRecipientsController.clear();
        _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isDesktop(context) || Responsive.isTablet(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text('Bulk Messaging',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text('Send messages to parents, staff, or custom recipients.',
              style: GoogleFonts.poppins(
                  color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _buildComposeCard()),
                const SizedBox(width: 20),
                Expanded(flex: 5, child: _buildHistoryCard()),
              ],
            )
          else ...[
            _buildComposeCard(),
            const SizedBox(height: 20),
            _buildHistoryCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildComposeCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Compose Message',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
            const SizedBox(height: 20),

            // Channel selector
            Text('Channel',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _channels.map((ch) {
                final selected = _channel == ch;
                return ChoiceChip(
                  label: Text(ch, style: GoogleFonts.poppins(fontSize: 13)),
                  selected: selected,
                  selectedColor: _channelColor(ch).withOpacity(0.2),
                  labelStyle: GoogleFonts.poppins(
                    color: selected ? _channelColor(ch) : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  onSelected: (_) => setState(() => _channel = ch),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Target audience
            Text('Target Audience',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _targetAudience,
              decoration: _inputDecoration('Select audience'),
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AppColors.textPrimary),
              items: _audiences
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _targetAudience = v;
                    if (v != 'Class Specific') _targetClass = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Target class (conditional)
            if (_targetAudience == 'Class Specific') ...[
              Text('Target Class',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _targetClass,
                decoration: _inputDecoration('Select class'),
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.textPrimary),
                items: SchoolConstants.allClasses
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _targetClass = v),
              ),
              const SizedBox(height: 16),
            ],

            // Custom recipients (conditional)
            if (_targetAudience == 'Custom') ...[
              Text('Custom Recipients',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _customRecipientsController,
                maxLines: 3,
                decoration: _inputDecoration(
                    'Enter emails/phones separated by commas'),
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 16),
            ],

            // Subject (for EMAIL/BOTH)
            if (_channel == 'EMAIL' || _channel == 'BOTH') ...[
              Text('Subject',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                decoration: _inputDecoration('Enter subject'),
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 16),
            ],

            // Message body
            Text('Message Body',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bodyController,
              maxLines: 6,
              decoration: _inputDecoration('Type your message here...'),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _sendMessage,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _sending ? 'Sending...' : 'Send Message',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Message History',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy)),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: AppColors.textSecondary,
                  tooltip: 'Refresh',
                  onPressed: _loadHistory,
                ),
              ],
            ),
            const Divider(height: 24),
            if (_loadingHistory)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_messages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.campaign_outlined,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('No messages sent yet',
                          style: GoogleFonts.poppins(
                              color: AppColors.textLight, fontSize: 14)),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(_messages.length, (i) {
                final msg = _messages[i];
                return _buildMessageItem(msg, i < _messages.length - 1);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> msg, bool showDivider) {
    final subject = msg['subject'] as String? ?? '';
    final body = msg['body'] as String? ?? '';
    final channel = msg['channel'] as String? ?? 'EMAIL';
    final status = msg['status'] as String? ?? 'SENDING';
    final target = msg['targetAudience'] as String? ?? '';
    final targetClass = msg['targetClass'] as String?;
    final sentCount = (msg['sentCount'] as num?)?.toInt() ?? 0;
    final totalRecipients = (msg['totalRecipients'] as num?)?.toInt() ?? 0;
    final createdAt = msg['createdAt'] as String?;

    String displayTitle = subject.isNotEmpty
        ? subject
        : (body.length > 60 ? '${body.substring(0, 60)}...' : body);

    String dateStr = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt);
        dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
      } catch (_) {
        dateStr = createdAt;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayTitle,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _chip(channel, _channelColor(channel)),
                        _chip(status, _statusColor(status)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${targetClass != null ? "$target ($targetClass)" : target}'
                      '${totalRecipients > 0 ? " | $sentCount/$totalRecipients sent" : ""}',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(dateStr,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.textLight)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Color _channelColor(String channel) {
    return switch (channel) {
      'EMAIL' => AppColors.info,
      'SMS' => AppColors.success,
      'BOTH' => const Color(0xFF7C3AED),
      _ => AppColors.textSecondary,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'COMPLETED' => AppColors.success,
      'SENDING' => AppColors.warning,
      'FAILED' => AppColors.error,
      _ => AppColors.textSecondary,
    };
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight),
      filled: true,
      fillColor: AppColors.cream,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
      ),
    );
  }
}
