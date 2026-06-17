import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/whatsapp_api_service.dart';

class WhatsAppConfigScreen extends StatefulWidget {
  const WhatsAppConfigScreen({super.key});

  @override
  State<WhatsAppConfigScreen> createState() => _WhatsAppConfigScreenState();
}

class _WhatsAppConfigScreenState extends State<WhatsAppConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;
  bool _saving = false;

  // Config state
  bool _enabled = false;
  String _businessToken = '';
  String _phoneNumberId = '';
  String _webhookVerifyToken = 'school-whatsapp-verify-2024';
  String _welcomeMessage =
      'Welcome! I\'m your school\'s AI assistant. Ask me about your child\'s attendance, fees, homework, or results.';
  List<String> _enabledFeatures = ['ATTENDANCE', 'FEES', 'HOMEWORK', 'RESULTS', 'GENERAL'];
  String? _aiProvider;
  int _dailyLimit = 30;
  String _defaultLanguage = 'auto';

  // Auto-notification settings
  bool _absenceAlertEnabled = false;
  bool _feeReminderEnabled = false;
  int _feeReminderDaysBefore = 3;
  bool _sendingReminders = false;

  // Conversations
  List<dynamic> _conversations = [];
  bool _loadingConversations = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadConfig();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    try {
      final data = await WhatsAppApiService.getConfig();
      if (mounted) {
        setState(() {
          _enabled = data['enabled'] == true;
          _businessToken = data['whatsappBusinessToken'] as String? ?? '';
          _phoneNumberId = data['whatsappPhoneNumberId'] as String? ?? '';
          _webhookVerifyToken = data['webhookVerifyToken'] as String? ?? 'school-whatsapp-verify-2024';
          _welcomeMessage = data['welcomeMessage'] as String? ?? _welcomeMessage;
          _enabledFeatures = List<String>.from(data['enabledFeatures'] ?? _enabledFeatures);
          _aiProvider = data['aiProvider'] as String?;
          _dailyLimit = (data['dailyLimitPerParent'] as num?)?.toInt() ?? 30;
          _defaultLanguage = data['defaultLanguage'] as String? ?? 'auto';
          _absenceAlertEnabled = data['absenceAlertEnabled'] == true;
          _feeReminderEnabled = data['feeReminderEnabled'] == true;
          _feeReminderDaysBefore = (data['feeReminderDaysBefore'] as num?)?.toInt() ?? 3;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load config: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    try {
      await WhatsAppApiService.updateConfig({
        'enabled': _enabled,
        'whatsappBusinessToken': _businessToken.isEmpty ? null : _businessToken,
        'whatsappPhoneNumberId': _phoneNumberId.isEmpty ? null : _phoneNumberId,
        'webhookVerifyToken': _webhookVerifyToken,
        'welcomeMessage': _welcomeMessage,
        'enabledFeatures': _enabledFeatures,
        'aiProvider': _aiProvider,
        'dailyLimitPerParent': _dailyLimit,
        'defaultLanguage': _defaultLanguage,
        'absenceAlertEnabled': _absenceAlertEnabled,
        'feeReminderEnabled': _feeReminderEnabled,
        'feeReminderDaysBefore': _feeReminderDaysBefore,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp config saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _loadConversations() async {
    setState(() => _loadingConversations = true);
    try {
      final data = await WhatsAppApiService.getConversations();
      if (mounted) setState(() => _conversations = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load conversations: $e')),
        );
      }
    }
    if (mounted) setState(() => _loadingConversations = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green[50],
          child: Row(
            children: [
              const Icon(Icons.chat, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WhatsApp AI Agent',
                        style: GoogleFonts.poppins(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    Text(
                        'Parents can message on WhatsApp to get instant updates about their child',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Switch(
                value: _enabled,
                activeColor: Colors.green,
                onChanged: (v) => setState(() => _enabled = v),
              ),
            ],
          ),
        ),

        // Tabs
        TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.navy,
          tabs: const [
            Tab(text: 'Configuration'),
            Tab(text: 'Features'),
            Tab(text: 'Conversations'),
          ],
          onTap: (index) {
            if (index == 2 && _conversations.isEmpty) {
              _loadConversations();
            }
          },
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildConfigTab(),
              _buildFeaturesTab(),
              _buildConversationsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Configuration Tab ───────────────────────────────────────────────

  Widget _buildConfigTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('WhatsApp Business API'),
        const SizedBox(height: 8),
        _buildTextField(
          label: 'Business Token',
          value: _businessToken,
          hint: 'Permanent access token from Meta dashboard',
          obscure: true,
          onChanged: (v) => _businessToken = v,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          label: 'Phone Number ID',
          value: _phoneNumberId,
          hint: 'WhatsApp business phone number ID',
          onChanged: (v) => _phoneNumberId = v,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          label: 'Webhook Verify Token',
          value: _webhookVerifyToken,
          hint: 'Token for Meta webhook verification',
          onChanged: (v) => _webhookVerifyToken = v,
        ),
        const SizedBox(height: 24),

        _sectionTitle('AI Provider'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _aiProvider,
          decoration: InputDecoration(
            labelText: 'AI Provider (leave empty to use school AI config)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('Use School AI Config')),
            DropdownMenuItem(value: 'OLLAMA', child: Text('Ollama (Free, Local)')),
            DropdownMenuItem(value: 'GEMINI', child: Text('Gemini (Cheapest)')),
            DropdownMenuItem(value: 'CLAUDE', child: Text('Claude (Best)')),
          ],
          onChanged: (v) => setState(() => _aiProvider = v),
        ),
        const SizedBox(height: 24),

        _sectionTitle('Limits & Language'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Daily Message Limit',
                value: _dailyLimit.toString(),
                hint: 'Max messages per parent per day',
                keyboardType: TextInputType.number,
                onChanged: (v) => _dailyLimit = int.tryParse(v) ?? 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _defaultLanguage,
                decoration: InputDecoration(
                  labelText: 'Language',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('Auto-detect')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                ],
                onChanged: (v) => setState(() => _defaultLanguage = v ?? 'auto'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _sectionTitle('Welcome Message'),
        const SizedBox(height: 8),
        _buildTextField(
          label: 'Greeting Message',
          value: _welcomeMessage,
          hint: 'Message sent when parent first contacts',
          maxLines: 3,
          onChanged: (v) => _welcomeMessage = v,
        ),
        const SizedBox(height: 24),

        // Setup instructions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Setup Instructions',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, color: Colors.blue[800])),
              const SizedBox(height: 8),
              _instructionStep('1', 'Create a Meta Business account at business.facebook.com'),
              _instructionStep('2', 'Create a WhatsApp Business app at developers.facebook.com'),
              _instructionStep('3', 'Get permanent access token & phone number ID'),
              _instructionStep('4', 'Set webhook URL to: https://your-domain.com/api/whatsapp/webhook'),
              _instructionStep('5', 'Enter the verify token above in Meta\'s webhook config'),
              _instructionStep('6', 'Subscribe to "messages" webhook events'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Save button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _saving ? null : _saveConfig,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Save Configuration',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Features Tab ────────────────────────────────────────────────────

  Widget _buildFeaturesTab() {
    final features = [
      {'key': 'ATTENDANCE', 'label': 'Attendance', 'icon': Icons.calendar_today, 'desc': 'Parents can ask about daily/monthly attendance'},
      {'key': 'FEES', 'label': 'Fee Status', 'icon': Icons.payment, 'desc': 'Parents can check pending fees, installments, payment history'},
      {'key': 'HOMEWORK', 'label': 'Homework', 'icon': Icons.assignment, 'desc': 'Parents can see active homework assignments'},
      {'key': 'RESULTS', 'label': 'Exam Results', 'icon': Icons.assessment, 'desc': 'Parents can ask about exam marks, grades, report card'},
      {'key': 'GENERAL', 'label': 'General Queries', 'icon': Icons.help_outline, 'desc': 'General school-related questions answered by AI'},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Select which information parents can query via WhatsApp:',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
        const SizedBox(height: 16),
        ...features.map((f) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: SwitchListTile(
                activeColor: Colors.green,
                secondary: Icon(f['icon'] as IconData, color: Colors.green[700]),
                title: Text(f['label'] as String,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                subtitle: Text(f['desc'] as String,
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                value: _enabledFeatures.contains(f['key']),
                onChanged: (v) {
                  setState(() {
                    if (v) {
                      _enabledFeatures.add(f['key'] as String);
                    } else {
                      _enabledFeatures.remove(f['key']);
                    }
                  });
                },
              ),
            )),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        Text('Automated Notifications',
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.navy)),
        const SizedBox(height: 4),
        Text('Auto-send WhatsApp messages to parents for important events',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 12),

        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: SwitchListTile(
            activeColor: Colors.orange,
            secondary: Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
            title: Text('Absence Alerts',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            subtitle: Text(
                'Auto-notify parents via WhatsApp when their child is marked absent',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
            value: _absenceAlertEnabled,
            onChanged: (v) => setState(() => _absenceAlertEnabled = v),
          ),
        ),

        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              SwitchListTile(
                activeColor: Colors.orange,
                secondary: Icon(Icons.payment, color: Colors.orange[700]),
                title: Text('Fee Due Reminders',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                subtitle: Text(
                    'Auto-send fee payment reminders daily at 9 AM',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey[600])),
                value: _feeReminderEnabled,
                onChanged: (v) => setState(() => _feeReminderEnabled = v),
              ),
              if (_feeReminderEnabled)
                Padding(
                  padding:
                      const EdgeInsets.only(left: 72, right: 16, bottom: 12),
                  child: Row(
                    children: [
                      Text('Remind ',
                          style: GoogleFonts.poppins(fontSize: 13)),
                      SizedBox(
                        width: 60,
                        child: DropdownButtonFormField<int>(
                          value: _feeReminderDaysBefore,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('0')),
                            DropdownMenuItem(value: 1, child: Text('1')),
                            DropdownMenuItem(value: 3, child: Text('3')),
                            DropdownMenuItem(value: 5, child: Text('5')),
                            DropdownMenuItem(value: 7, child: Text('7')),
                          ],
                          onChanged: (v) =>
                              setState(() => _feeReminderDaysBefore = v ?? 3),
                        ),
                      ),
                      Text(' days before due date',
                          style: GoogleFonts.poppins(fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton.icon(
            onPressed: _sendingReminders
                ? null
                : () async {
                    setState(() => _sendingReminders = true);
                    try {
                      await WhatsAppApiService.sendFeeReminders();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fee reminders sent!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e')),
                        );
                      }
                    }
                    if (mounted) setState(() => _sendingReminders = false);
                  },
            icon: _sendingReminders
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send, size: 18),
            label: Text(
                _sendingReminders
                    ? 'Sending...'
                    : 'Send Fee Reminders Now',
                style: GoogleFonts.poppins(fontSize: 13)),
          ),
        ),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _saving ? null : _saveConfig,
            icon: const Icon(Icons.save),
            label: Text('Save Features',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ── Conversations Tab ───────────────────────────────────────────────

  Widget _buildConversationsTab() {
    if (_loadingConversations) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No conversations yet',
                style: GoogleFonts.poppins(color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text('Conversations will appear here when parents message via WhatsApp',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400])),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadConversations,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _conversations.length,
        itemBuilder: (ctx, i) {
          final conv = _conversations[i] as Map<String, dynamic>;
          final messages = conv['messages'] as List<dynamic>? ?? [];
          final lastMsg = messages.isNotEmpty ? messages.last : null;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green[100],
                child: const Icon(Icons.person, color: Colors.green),
              ),
              title: Text(conv['parentName'] as String? ?? 'Parent',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Student: ${conv['studentName'] ?? 'Unknown'} (${conv['className'] ?? ''})',
                      style: GoogleFonts.poppins(fontSize: 11)),
                  Text('Phone: ${conv['phoneNumber'] ?? ''}',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
                  if (lastMsg != null)
                    Text('Last: ${lastMsg['content']?.toString().substring(0, (lastMsg['content']?.toString().length ?? 0).clamp(0, 50))}...',
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
              children: messages.map<Widget>((msg) {
                final isUser = msg['role'] == 'USER';
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blue[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isUser ? 'Parent' : 'AI Agent',
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isUser ? Colors.blue[700] : Colors.green[700])),
                      const SizedBox(height: 4),
                      Text(msg['content'] as String? ?? '',
                          style: GoogleFonts.poppins(fontSize: 13)),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  Widget _sectionTitle(String title) => Text(title,
      style: GoogleFonts.poppins(
          fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.navy));

  Widget _buildTextField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    String? hint,
    bool obscure = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      initialValue: value,
      obscureText: obscure,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: onChanged,
    );
  }

  Widget _instructionStep(String num, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 10,
              backgroundColor: Colors.blue[200],
              child: Text(num,
                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.white)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue[800])),
            ),
          ],
        ),
      );
}
