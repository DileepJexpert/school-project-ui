// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/auth_service.dart';
import '../../../services/dio_client.dart';
import '../../../services/tenant_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiUrlCtrl = TextEditingController();
  final _schoolNameCtrl = TextEditingController(text: AppStrings.schoolName);
  final _tenantIdCtrl = TextEditingController();

  bool _emailNotifications = true;
  bool _smsAlerts = false;
  bool _savingApi = false;
  bool _savingSchool = false;
  bool _backingUp = false;
  bool _savingTenant = false;
  String _tenantValidationMsg = '';
  String _currentTenant = 'default';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    _schoolNameCtrl.dispose();
    _tenantIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final tenantId = await TenantService.getTenantId();
    if (!mounted) return;
    setState(() {
      _apiUrlCtrl.text =
          prefs.getString('api_base_url') ?? 'http://localhost:8080/api';
      _emailNotifications = prefs.getBool('email_notifications') ?? true;
      _smsAlerts = prefs.getBool('sms_alerts') ?? false;
      _currentTenant = tenantId;
      _tenantIdCtrl.text = tenantId == 'default' ? '' : tenantId;
      final savedSchoolName = prefs.getString('school_name');
      if (savedSchoolName != null && savedSchoolName.isNotEmpty) {
        _schoolNameCtrl.text = savedSchoolName;
      }
    });
  }

  Future<void> _saveTenantId() async {
    final tenantId = _tenantIdCtrl.text.trim().toLowerCase();
    if (tenantId.isEmpty) {
      setState(() => _tenantValidationMsg = 'School code cannot be empty.');
      return;
    }

    setState(() {
      _savingTenant = true;
      _tenantValidationMsg = '';
    });

    try {
      await TenantService.setTenant(tenantId);
      if (!mounted) return;
      setState(() {
        _currentTenant = tenantId;
        _tenantValidationMsg =
            'Saved. API requests now use X-Tenant-ID: $tenantId';
      });
      _snack('School code saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _tenantValidationMsg = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _savingTenant = false);
    }
  }

  Future<void> _saveApiUrl() async {
    setState(() => _savingApi = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_base_url', _apiUrlCtrl.text.trim());
      _snack('API URL saved. Restart the app to apply it.');
    } finally {
      if (mounted) setState(() => _savingApi = false);
    }
  }

  Future<void> _saveSchoolName() async {
    setState(() => _savingSchool = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('school_name', _schoolNameCtrl.text.trim());
      _snack('School name saved.');
    } finally {
      if (mounted) setState(() => _savingSchool = false);
    }
  }

  Future<void> _downloadBackup() async {
    setState(() => _backingUp = true);
    try {
      final response = await DioClient.instance.get(
        '/admin/backup',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data as List<int>);
      final blob = html.Blob([bytes], 'application/zip');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final now = DateTime.now();
      final filename =
          'school_backup_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'
          '_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}.zip';
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
      _snack('Backup downloaded.');
    } catch (e) {
      _snack('Backup failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm logout'),
        content: const Text('Logout from the admin panel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.home);
  }

  Future<void> _openChangePasswordDialog() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool saving = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          Future<void> submit() async {
            if (newCtrl.text != confirmCtrl.text) {
              _dialogSnack(ctx, 'Passwords do not match.');
              return;
            }
            if (newCtrl.text.length < 6) {
              _dialogSnack(ctx, 'Password must be at least 6 characters.');
              return;
            }

            setDlg(() => saving = true);
            try {
              await DioClient.put('/admin/password', data: {
                'currentPassword': currentCtrl.text,
                'newPassword': newCtrl.text,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _snack('Password changed.');
            } catch (e) {
              _dialogSnack(ctx, 'Failed: $e');
              setDlg(() => saving = false);
            }
          }

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
            contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            actionsPadding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.palette.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.lock_outline, color: context.palette.brand),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Change password',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _passwordField(
                    controller: currentCtrl,
                    label: 'Current password',
                    obscure: obscureCurrent,
                    onToggle: () =>
                        setDlg(() => obscureCurrent = !obscureCurrent),
                  ),
                  const SizedBox(height: 10),
                  _passwordField(
                    controller: newCtrl,
                    label: 'New password',
                    obscure: obscureNew,
                    onToggle: () => setDlg(() => obscureNew = !obscureNew),
                  ),
                  const SizedBox(height: 10),
                  _passwordField(
                    controller: confirmCtrl,
                    label: 'Confirm new password',
                    obscure: obscureConfirm,
                    onToggle: () =>
                        setDlg(() => obscureConfirm = !obscureConfirm),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: saving ? null : submit,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(saving ? 'Changing...' : 'Change password'),
              ),
            ],
          );
        },
      ),
    );

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
        ),
      ),
    );
  }

  void _dialogSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
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
    final padding = Responsive.contentPadding(context);

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1080 ? 2 : 1;
                final cardWidth =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(width: cardWidth, child: _backendCard()),
                      SizedBox(width: cardWidth, child: _tenantCard()),
                      SizedBox(width: cardWidth, child: _schoolCard()),
                      SizedBox(width: cardWidth, child: _appearanceCard()),
                      SizedBox(width: cardWidth, child: _notificationCard()),
                      SizedBox(width: cardWidth, child: _securityCard()),
                      SizedBox(width: cardWidth, child: _backupCard()),
                      SizedBox(width: cardWidth, child: _aboutCard()),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: context.palette.heroGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure local API, tenant identity, theme, security and backups.',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          _HeaderPill(label: 'Tenant', value: _currentTenant),
          const SizedBox(width: 8),
          _HeaderPill(label: 'Mode', value: 'Local first'),
        ],
      ),
    );
  }

  Widget _backendCard() {
    return _SettingsCard(
      icon: Icons.api_outlined,
      title: 'Backend Configuration',
      subtitle: 'Local Spring Boot API base URL.',
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _apiUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'API base URL',
                  hintText: 'http://localhost:8080/api',
                  prefixIcon: Icon(Icons.link_rounded, size: 19),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _savingApi ? null : _saveApiUrl,
              icon: _savingApi
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _InfoPanel(
          icon: Icons.info_outline,
          title: 'Useful URLs',
          lines: [
            'Local: http://localhost:8080/api',
            'Docker: http://host.docker.internal:8080/api',
            'Production later: https://your-server.com/api',
          ],
        ),
      ],
    );
  }

  Widget _tenantCard() {
    final messageColor = _tenantValidationMsg.startsWith('Saved')
        ? AppColors.success
        : AppColors.error;

    return _SettingsCard(
      icon: Icons.domain_outlined,
      title: 'School Identity',
      subtitle: 'Tenant code used as X-Tenant-ID for every request.',
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tenantIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'School code',
                  hintText: 'example: springfield',
                  prefixIcon: Icon(Icons.badge_outlined, size: 19),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _savingTenant ? null : _saveTenantId,
              icon: _savingTenant
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save'),
            ),
          ],
        ),
        if (_tenantValidationMsg.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _tenantValidationMsg,
            style: GoogleFonts.nunitoSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: messageColor,
            ),
          ),
        ],
        const SizedBox(height: 12),
        const _InfoPanel(
          icon: Icons.verified_user_outlined,
          title: 'Tenant isolation',
          lines: [
            'Use one school code per school.',
            'Changing this switches the data loaded by the app.',
          ],
        ),
      ],
    );
  }

  Widget _schoolCard() {
    return _SettingsCard(
      icon: Icons.school_outlined,
      title: 'School Information',
      subtitle: 'Local display values for the admin app.',
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _schoolNameCtrl,
                decoration: const InputDecoration(labelText: 'School name'),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _savingSchool ? null : _saveSchoolName,
              icon: _savingSchool
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _InfoRows(
          rows: [
            ('Academic year', '2025-2026'),
            ('Affiliation', 'CBSE'),
            ('Board code', 'TBD'),
          ],
        ),
      ],
    );
  }

  Widget _appearanceCard() {
    return _SettingsCard(
      icon: Icons.palette_outlined,
      title: 'Appearance',
      subtitle: 'Switch between the configured app themes.',
      children: [
        AnimatedBuilder(
          animation: ThemeController.instance,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final width = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 3;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppThemePreset.values
                    .map(
                      (preset) => SizedBox(
                        width: width,
                        child: _ThemeOption(preset: preset),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _notificationCard() {
    return _SettingsCard(
      icon: Icons.notifications_active_outlined,
      title: 'Notification Preferences',
      subtitle: 'Local switches for school communication channels.',
      children: [
        _SwitchRow(
          title: 'Email notifications',
          subtitle: 'Receive fee receipts and alerts by email.',
          icon: Icons.email_outlined,
          value: _emailNotifications,
          onChanged: (value) async {
            setState(() => _emailNotifications = value);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('email_notifications', value);
          },
        ),
        const SizedBox(height: 8),
        _SwitchRow(
          title: 'SMS alerts',
          subtitle: 'Send fee reminders to parents by SMS.',
          icon: Icons.sms_outlined,
          value: _smsAlerts,
          onChanged: (value) async {
            setState(() => _smsAlerts = value);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('sms_alerts', value);
          },
        ),
      ],
    );
  }

  Widget _securityCard() {
    return _SettingsCard(
      icon: Icons.security_outlined,
      title: 'Security',
      subtitle: 'Password and admin access controls.',
      children: [
        _ActionRow(
          icon: Icons.lock_outline,
          title: 'Change admin password',
          subtitle: 'Update your current admin login password.',
          actionLabel: 'Change',
          onTap: _openChangePasswordDialog,
        ),
        const SizedBox(height: 8),
        _ActionRow(
          icon: Icons.manage_accounts_outlined,
          title: 'Manage admin roles',
          subtitle: 'Backend endpoint is planned for admin user management.',
          actionLabel: 'Soon',
          onTap: () => _snack(
            'Admin user management endpoint is not wired yet.',
            isError: true,
          ),
        ),
        const SizedBox(height: 8),
        _ActionRow(
          icon: Icons.logout_rounded,
          title: 'Logout',
          subtitle: 'End this admin session on this browser.',
          actionLabel: 'Logout',
          danger: true,
          onTap: _logout,
        ),
      ],
    );
  }

  Widget _backupCard() {
    return _SettingsCard(
      icon: Icons.backup_outlined,
      title: 'Data Backup',
      subtitle: 'Download a ZIP export from the backend.',
      children: [
        Text(
          'Includes students, fees, expenses, attendance, results, timetable and transport records where supported by the backend.',
          style: GoogleFonts.nunitoSans(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _backingUp ? null : _downloadBackup,
            icon: _backingUp
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined, size: 18),
            label: Text(_backingUp ? 'Preparing backup...' : 'Backup now'),
          ),
        ),
        const SizedBox(height: 12),
        const _InfoPanel(
          icon: Icons.folder_zip_outlined,
          title: 'Browser download',
          lines: [
            'The ZIP is saved to the browser download folder.',
            'Change the folder in browser settings if needed.',
          ],
        ),
      ],
    );
  }

  Widget _aboutCard() {
    return const _SettingsCard(
      icon: Icons.info_outline,
      title: 'About',
      subtitle: 'Current local project details.',
      children: [
        _InfoRows(
          rows: [
            ('App version', '1.0.0'),
            ('Frontend', 'Flutter Web'),
            ('Backend', 'Spring Boot'),
            ('Database', 'MongoDB'),
            ('Backend port', '8080'),
          ],
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.palette.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: context.palette.brand, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunitoSans(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunitoSans(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final AppThemePreset preset;

  const _ThemeOption({required this.preset});

  @override
  Widget build(BuildContext context) {
    final selected = ThemeController.instance.preset == preset;
    final preview = AppTheme.forPreset(preset).extension<AppThemePalette>()!;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => ThemeController.instance.setPreset(preset),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? preview.brand.withValues(alpha: 0.07)
              : context.palette.canvas,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? preview.brand : context.palette.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 38,
              decoration: BoxDecoration(
                gradient: preview.heroGradient,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                selected ? Icons.check_rounded : Icons.palette_outlined,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              preset.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              preset.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunitoSans(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.canvas,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.palette.brand, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;
  final bool danger;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : context.palette.brand;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.palette.canvas,
          border: Border.all(color: context.palette.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              actionLabel,
              style: GoogleFonts.nunitoSans(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;

  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.info, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(height: 3),
                for (final line in lines)
                  Text(
                    line,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRows extends StatelessWidget {
  final List<(String, String)> rows;

  const _InfoRows({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.$1,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    row.$2,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
