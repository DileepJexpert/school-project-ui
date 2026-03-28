import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/ai_config_api_service.dart';

class AiConfigScreen extends StatefulWidget {
  const AiConfigScreen({super.key});

  @override
  State<AiConfigScreen> createState() => _AiConfigScreenState();
}

class _AiConfigScreenState extends State<AiConfigScreen> {
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic> _config = {};

  // Form state
  bool _enabled = false;
  List<String> _enabledModes = ['TUTOR'];
  String _primaryProvider = 'OLLAMA';
  String? _fallbackProvider = 'GEMINI';
  String _ollamaBaseUrl = 'http://localhost:11434';
  String _ollamaModel = 'llama3';
  String? _geminiApiKey;
  String _geminiModel = 'gemini-2.0-flash';
  String? _claudeApiKey;
  String _claudeModel = 'claude-sonnet-4-20250514';
  int _dailyLimit = 20;
  int _maxTurns = 30;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    try {
      final data = await AiConfigApiService.getConfig();
      if (mounted) {
        setState(() {
          _config = data;
          _enabled = data['enabled'] == true;
          _enabledModes = List<String>.from(data['enabledModes'] ?? ['TUTOR']);
          _primaryProvider = data['primaryProvider'] as String? ?? 'OLLAMA';
          _fallbackProvider = data['fallbackProvider'] as String?;
          _ollamaBaseUrl =
              data['ollamaBaseUrl'] as String? ?? 'http://localhost:11434';
          _ollamaModel = data['ollamaModel'] as String? ?? 'llama3';
          _geminiApiKey = data['geminiApiKey'] as String?;
          _geminiModel =
              data['geminiModel'] as String? ?? 'gemini-2.0-flash';
          _claudeApiKey = data['claudeApiKey'] as String?;
          _claudeModel =
              data['claudeModel'] as String? ?? 'claude-sonnet-4-20250514';
          _dailyLimit = (data['dailyLimitPerStudent'] as num?)?.toInt() ?? 20;
          _maxTurns =
              (data['maxConversationTurns'] as num?)?.toInt() ?? 30;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load AI config: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    try {
      await AiConfigApiService.updateConfig({
        'enabled': _enabled,
        'enabledModes': _enabledModes,
        'primaryProvider': _primaryProvider,
        'fallbackProvider': _fallbackProvider,
        'ollamaBaseUrl': _ollamaBaseUrl,
        'ollamaModel': _ollamaModel,
        'geminiApiKey': _geminiApiKey,
        'geminiModel': _geminiModel,
        'claudeApiKey': _claudeApiKey,
        'claudeModel': _claudeModel,
        'dailyLimitPerStudent': _dailyLimit,
        'maxConversationTurns': _maxTurns,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI Settings saved!')),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.smart_toy_outlined,
                  color: AppColors.navy, size: 28),
              const SizedBox(width: 10),
              Text('AI Homework Helper Settings',
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              'Configure the AI assistant that helps students with their homework.',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 24),

          // Enable toggle
          Card(
            child: SwitchListTile(
              title: Text('Enable AI Homework Helper',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: Text(
                  _enabled
                      ? 'Students can use the AI assistant'
                      : 'AI assistant is disabled for students',
                  style: GoogleFonts.poppins(fontSize: 12)),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              activeColor: AppColors.success,
            ),
          ),
          const SizedBox(height: 16),

          // Enabled Modes
          _sectionTitle('Enabled Modes'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _modeCheckbox('TUTOR', 'Tutor Mode',
                      'Guides students step by step (Socratic)'),
                  _modeCheckbox('SOLVE', 'Solve Mode',
                      'Gives complete solutions with explanations'),
                  _modeCheckbox('PRACTICE', 'Practice Mode',
                      'Generates similar practice problems'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Provider settings
          _sectionTitle('AI Provider'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Primary Provider',
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      border: const OutlineInputBorder(),
                    ),
                    value: _primaryProvider,
                    items: const [
                      DropdownMenuItem(
                          value: 'OLLAMA', child: Text('Ollama (Free Local)')),
                      DropdownMenuItem(
                          value: 'GEMINI',
                          child: Text('Google Gemini (Cheapest)')),
                      DropdownMenuItem(
                          value: 'CLAUDE',
                          child: Text('Claude (Best Quality)')),
                    ],
                    onChanged: (v) =>
                        setState(() => _primaryProvider = v ?? 'OLLAMA'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Fallback Provider (optional)',
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      border: const OutlineInputBorder(),
                    ),
                    value: _fallbackProvider,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('None')),
                      DropdownMenuItem(
                          value: 'OLLAMA', child: Text('Ollama (Free Local)')),
                      DropdownMenuItem(
                          value: 'GEMINI',
                          child: Text('Google Gemini')),
                      DropdownMenuItem(
                          value: 'CLAUDE', child: Text('Claude')),
                    ],
                    onChanged: (v) => setState(() => _fallbackProvider = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Ollama settings
          _sectionTitle('Ollama Settings (Free)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    initialValue: _ollamaBaseUrl,
                    decoration: InputDecoration(
                      labelText: 'Ollama URL',
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      border: const OutlineInputBorder(),
                      hintText: 'http://localhost:11434',
                    ),
                    onChanged: (v) => _ollamaBaseUrl = v,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _ollamaModel,
                    decoration: InputDecoration(
                      labelText: 'Model Name',
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      border: const OutlineInputBorder(),
                      hintText: 'llama3, mistral, phi3...',
                    ),
                    onChanged: (v) => _ollamaModel = v,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // API Keys
          _sectionTitle('API Keys (for paid providers)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    initialValue: _geminiApiKey,
                    decoration: InputDecoration(
                      labelText: 'Gemini API Key',
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                    onChanged: (v) =>
                        _geminiApiKey = v.isEmpty ? null : v,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _claudeApiKey,
                    decoration: InputDecoration(
                      labelText: 'Claude API Key',
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                    onChanged: (v) =>
                        _claudeApiKey = v.isEmpty ? null : v,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Limits
          _sectionTitle('Limits'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    initialValue: '$_dailyLimit',
                    decoration: InputDecoration(
                      labelText: 'Daily Questions Per Student',
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        _dailyLimit = int.tryParse(v) ?? 20,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: '$_maxTurns',
                    decoration: InputDecoration(
                      labelText: 'Max Conversation Turns',
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        _maxTurns = int.tryParse(v) ?? 30,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveConfig,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Save Settings',
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary)),
    );
  }

  Widget _modeCheckbox(String mode, String title, String description) {
    final checked = _enabledModes.contains(mode);
    return CheckboxListTile(
      value: checked,
      onChanged: (v) {
        setState(() {
          if (v == true) {
            _enabledModes.add(mode);
          } else {
            _enabledModes.remove(mode);
          }
        });
      },
      title: Text(title,
          style:
              GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(description,
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textLight)),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      activeColor: AppColors.navy,
    );
  }
}
