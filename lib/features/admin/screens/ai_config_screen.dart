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

  // Form state
  bool _enabled = false;
  List<String> _enabledModes = ['TUTOR'];
  String _ollamaBaseUrl = 'http://localhost:11434';
  String _ollamaModel = 'llama3';
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
          _enabled = data['enabled'] == true;
          _enabledModes = List<String>.from(data['enabledModes'] ?? ['TUTOR']);
          _ollamaBaseUrl =
              data['ollamaBaseUrl'] as String? ?? 'http://localhost:11434';
          _ollamaModel = data['ollamaModel'] as String? ?? 'llama3';
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
    if (_enabledModes.isEmpty || _dailyLimit < 1 || _dailyLimit > 100 ||
        _maxTurns < 1 || _maxTurns > 100 ||
        _ollamaBaseUrl.trim().isEmpty || _ollamaModel.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Select a mode, enter Ollama settings, and use limits from 1 to 100.'),
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      await AiConfigApiService.updateConfig({
        'enabled': _enabled,
        'enabledModes': _enabledModes,
        'primaryProvider': 'OLLAMA',
        'fallbackProvider': null,
        'ollamaBaseUrl': _ollamaBaseUrl.trim(),
        'ollamaModel': _ollamaModel.trim(),
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

          _sectionTitle('Ollama Settings'),
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
            if (_enabledModes.length > 1) _enabledModes.remove(mode);
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
