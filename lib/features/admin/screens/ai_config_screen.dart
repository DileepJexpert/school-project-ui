import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../services/ai_config_api_service.dart';

class AiConfigScreen extends StatefulWidget {
  const AiConfigScreen({super.key});

  @override
  State<AiConfigScreen> createState() => _AiConfigScreenState();
}

class _AiConfigScreenState extends State<AiConfigScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

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

  static const _providers = [
    _ProviderInfo(
      code: 'OLLAMA',
      label: 'Ollama',
      subtitle: 'Free local AI for low-cost school deployment',
      icon: Icons.dns_outlined,
      color: AppColors.success,
    ),
    _ProviderInfo(
      code: 'GEMINI',
      label: 'Gemini',
      subtitle: 'Cloud model option with API key',
      icon: Icons.auto_awesome_outlined,
      color: AppColors.info,
    ),
    _ProviderInfo(
      code: 'CLAUDE',
      label: 'Claude',
      subtitle: 'High quality cloud model fallback',
      icon: Icons.psychology_alt_outlined,
      color: Color(0xFF7C3AED),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AiConfigApiService.getConfig();
      if (!mounted) return;
      setState(() {
        _enabled = data['enabled'] == true;
        _enabledModes = List<String>.from(data['enabledModes'] ?? ['TUTOR']);
        _primaryProvider = data['primaryProvider'] as String? ?? 'OLLAMA';
        _fallbackProvider = data['fallbackProvider'] as String?;
        _ollamaBaseUrl =
            data['ollamaBaseUrl'] as String? ?? 'http://localhost:11434';
        _ollamaModel = data['ollamaModel'] as String? ?? 'llama3';
        _geminiApiKey = data['geminiApiKey'] as String?;
        _geminiModel = data['geminiModel'] as String? ?? 'gemini-2.0-flash';
        _claudeApiKey = data['claudeApiKey'] as String?;
        _claudeModel =
            data['claudeModel'] as String? ?? 'claude-sonnet-4-20250514';
        _dailyLimit = (data['dailyLimitPerStudent'] as num?)?.toInt() ?? 20;
        _maxTurns = (data['maxConversationTurns'] as num?)?.toInt() ?? 30;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      _snack('AI settings saved.');
    } catch (e) {
      _snack('Failed to save AI settings: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    return AdminPageScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdminPageHeader(
          title: 'AI Settings',
          subtitle:
              'Configure student homework assistance, providers, limits and safety modes.',
          icon: Icons.smart_toy_outlined,
          actions: [
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadConfig,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Reload'),
            ),
            ElevatedButton.icon(
              onPressed: _saving || _loading ? null : _saveConfig,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 17),
              label: Text(_saving ? 'Saving' : 'Save'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading)
          const SizedBox(
            height: 260,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _errorState()
        else
          _settingsContent(),
      ]),
    );
  }

  Widget _settingsContent() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _enableCard(),
      const SizedBox(height: 14),
      _providerOverview(),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 920;
        if (!wide) {
          return Column(children: [
            _modesCard(),
            const SizedBox(height: 14),
            _providerSettingsCard(),
            const SizedBox(height: 14),
            _limitsCard(),
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _modesCard()),
          const SizedBox(width: 14),
          Expanded(flex: 2, child: _providerSettingsCard()),
          const SizedBox(width: 14),
          Expanded(child: _limitsCard()),
        ]);
      }),
      const SizedBox(height: 70),
    ]);
  }

  Widget _enableCard() {
    return Card(
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        value: _enabled,
        onChanged: (value) => setState(() => _enabled = value),
        activeThumbColor: AppColors.success,
        title: Text(
          'AI Homework Helper',
          style: GoogleFonts.nunitoSans(
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          _enabled
              ? 'Enabled for students using selected modes and provider rules.'
              : 'Disabled for students. Settings are saved but not active.',
          style: GoogleFonts.nunitoSans(color: AppColors.textSecondary),
        ),
        secondary: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: (_enabled ? AppColors.success : AppColors.textLight)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusLG),
          ),
          child: Icon(
            _enabled ? Icons.check_circle_outline : Icons.pause_circle_outline,
            color: _enabled ? AppColors.success : AppColors.textLight,
          ),
        ),
      ),
    );
  }

  Widget _providerOverview() {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 820 ? 3 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _providers
            .map((provider) => SizedBox(
                  width: width,
                  child: _providerCard(provider),
                ))
            .toList(),
      );
    });
  }

  Widget _providerCard(_ProviderInfo provider) {
    final isPrimary = _primaryProvider == provider.code;
    final isFallback = _fallbackProvider == provider.code;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: provider.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            ),
            child: Icon(provider.icon, color: provider.color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                provider.label,
                style: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                provider.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                if (isPrimary) _pill('Primary', AppColors.success),
                if (isFallback) _pill('Fallback', AppColors.info),
                if (!isPrimary && !isFallback)
                  _pill('Available', provider.color),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _modesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader(
              'Learning Modes', 'Choose what students can ask AI to do.'),
          const SizedBox(height: 12),
          _modeTile(
            mode: 'TUTOR',
            title: 'Tutor Mode',
            subtitle: 'Guides students step by step.',
            icon: Icons.school_outlined,
          ),
          _modeTile(
            mode: 'SOLVE',
            title: 'Solve Mode',
            subtitle: 'Allows complete worked solutions.',
            icon: Icons.task_alt_outlined,
          ),
          _modeTile(
            mode: 'PRACTICE',
            title: 'Practice Mode',
            subtitle: 'Generates similar practice questions.',
            icon: Icons.fitness_center_outlined,
          ),
        ]),
      ),
    );
  }

  Widget _modeTile({
    required String mode,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final enabled = _enabledModes.contains(mode);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: enabled,
      activeColor: context.palette.brand,
      controlAffinity: ListTileControlAffinity.leading,
      secondary: Icon(icon,
          color: enabled ? context.palette.brand : AppColors.textLight),
      title: Text(
        title,
        style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.nunitoSans(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
      onChanged: (value) {
        setState(() {
          if (value == true && !_enabledModes.contains(mode)) {
            _enabledModes.add(mode);
          } else if (value == false) {
            _enabledModes.remove(mode);
          }
        });
      },
    );
  }

  Widget _providerSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader(
              'Provider Settings', 'Local-first, cloud fallback ready.'),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 560;
            final fields = [
              _providerDropdown(
                label: 'Primary Provider',
                value: _primaryProvider,
                allowNone: false,
                onChanged: (value) =>
                    setState(() => _primaryProvider = value ?? 'OLLAMA'),
              ),
              _providerDropdown(
                label: 'Fallback Provider',
                value: _fallbackProvider,
                allowNone: true,
                onChanged: (value) => setState(() => _fallbackProvider = value),
              ),
            ];
            return wide
                ? Row(children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 12),
                    Expanded(child: fields[1]),
                  ])
                : Column(children: [
                    fields[0],
                    const SizedBox(height: 12),
                    fields[1],
                  ]);
          }),
          const SizedBox(height: 16),
          _sectionHeader('Ollama', 'Free local provider'),
          const SizedBox(height: 10),
          _textField(
            label: 'Ollama URL',
            initialValue: _ollamaBaseUrl,
            onChanged: (value) => _ollamaBaseUrl = value,
          ),
          const SizedBox(height: 10),
          _textField(
            label: 'Ollama Model',
            initialValue: _ollamaModel,
            onChanged: (value) => _ollamaModel = value,
          ),
          const SizedBox(height: 16),
          _sectionHeader('Cloud Keys', 'Needed only for paid cloud providers'),
          const SizedBox(height: 10),
          _textField(
            label: 'Gemini API Key',
            initialValue: _geminiApiKey,
            obscure: true,
            onChanged: (value) => _geminiApiKey = value.isEmpty ? null : value,
          ),
          const SizedBox(height: 10),
          _textField(
            label: 'Gemini Model',
            initialValue: _geminiModel,
            onChanged: (value) => _geminiModel = value,
          ),
          const SizedBox(height: 10),
          _textField(
            label: 'Claude API Key',
            initialValue: _claudeApiKey,
            obscure: true,
            onChanged: (value) => _claudeApiKey = value.isEmpty ? null : value,
          ),
          const SizedBox(height: 10),
          _textField(
            label: 'Claude Model',
            initialValue: _claudeModel,
            onChanged: (value) => _claudeModel = value,
          ),
        ]),
      ),
    );
  }

  Widget _limitsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader('Limits', 'Keep usage predictable and affordable.'),
          const SizedBox(height: 12),
          _numberField(
            label: 'Daily questions per student',
            initialValue: _dailyLimit,
            onChanged: (value) => _dailyLimit = value,
          ),
          const SizedBox(height: 12),
          _numberField(
            label: 'Max conversation turns',
            initialValue: _maxTurns,
            onChanged: (value) => _maxTurns = value,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.palette.brand.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            ),
            child: Text(
              'Tip: keep Tutor Mode enabled by default. Solve Mode is useful, but schools may want it only for higher classes.',
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _providerDropdown({
    required String label,
    required String? value,
    required bool allowNone,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        if (allowNone) const DropdownMenuItem(value: null, child: Text('None')),
        ..._providers.map(
          (provider) => DropdownMenuItem(
            value: provider.code,
            child: Text(provider.label),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _textField({
    required String label,
    required String? initialValue,
    required ValueChanged<String> onChanged,
    bool obscure = false,
  }) {
    return TextFormField(
      initialValue: initialValue,
      obscureText: obscure,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
  }

  Widget _numberField({
    required String label,
    required int initialValue,
    required ValueChanged<int> onChanged,
  }) {
    return TextFormField(
      initialValue: '$initialValue',
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (value) => onChanged(int.tryParse(value) ?? initialValue),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        title,
        style: GoogleFonts.nunitoSans(
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
          fontSize: 15,
        ),
      ),
      Text(
        subtitle,
        style: GoogleFonts.nunitoSans(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
    ]);
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunitoSans(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _errorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              'Could not load AI settings',
              style: GoogleFonts.nunitoSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadConfig,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Retry'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ProviderInfo {
  final String code;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ProviderInfo({
    required this.code,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
