import 'dart:html' as html;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
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
  bool _darkMode = false;
  bool _emailNotifications = true;
  bool _smsAlerts = false;
  bool _savingApi = false;
  bool _backingUp = false;
  bool _savingTenant = false;
  String _tenantValidationMsg = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final tenantId = await TenantService.getTenantId();
    setState(() {
      _apiUrlCtrl.text = prefs.getString('api_base_url') ?? 'http://localhost:8080/api';
      _emailNotifications = prefs.getBool('email_notifications') ?? true;
      _smsAlerts = prefs.getBool('sms_alerts') ?? false;
      _tenantIdCtrl.text = tenantId == 'default' ? '' : tenantId;
    });
  }

  Future<void> _saveTenantId() async {
    final tenantId = _tenantIdCtrl.text.trim().toLowerCase();
    if (tenantId.isEmpty) {
      setState(() => _tenantValidationMsg = 'School code cannot be empty.');
      return;
    }
    setState(() { _savingTenant = true; _tenantValidationMsg = ''; });
    try {
      await TenantService.setTenant(tenantId);
      setState(() => _tenantValidationMsg = 'School code saved! All API requests will now use: $tenantId');
    } catch (e) {
      setState(() => _tenantValidationMsg = 'Failed to save: $e');
    } finally {
      setState(() => _savingTenant = false);
    }
  }

  Future<void> _saveApiUrl() async {
    setState(() => _savingApi = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', _apiUrlCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API URL saved! Restart the app to apply.'),
            backgroundColor: AppColors.success),
      );
    }
    setState(() => _savingApi = false);
  }

  Future<void> _saveSchoolName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('school_name', _schoolNameCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('School name saved!'),
            backgroundColor: AppColors.success),
      );
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Backup downloaded successfully!'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Backup failed: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _backingUp = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
        title: Text('Confirm Logout',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.navy)),
        content: Text(
            'Are you sure you want to logout from the admin panel?',
            style: GoogleFonts.nunitoSans()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await AuthService.instance.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRouter.home);
      }
    }
  }

  void _openChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool saving = false;
    bool obscureCurrent = true;
    bool obscureNew = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
          title: Text('Change Admin Password',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: currentCtrl,
                obscureText: obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                  suffixIcon: IconButton(
                    icon: Icon(obscureCurrent
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setDlg(() => obscureCurrent = !obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                  suffixIcon: IconButton(
                    icon:
                        Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDlg(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white),
              onPressed: saving
                  ? null
                  : () async {
                      if (newCtrl.text != confirmCtrl.text) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('Passwords do not match.'),
                            backgroundColor: AppColors.error));
                        return;
                      }
                      if (newCtrl.text.length < 6) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text(
                                'Password must be at least 6 characters.'),
                            backgroundColor: AppColors.error));
                        return;
                      }
                      setDlg(() => saving = true);
                      try {
                        await DioClient.put('/admin/password', data: {
                          'currentPassword': currentCtrl.text,
                          'newPassword': newCtrl.text,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Password changed successfully!'),
                                  backgroundColor: AppColors.success));
                        }
                      } catch (e) {
                        setDlg(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text('Failed: $e'),
                              backgroundColor: AppColors.error));
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    _schoolNameCtrl.dispose();
    _tenantIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text('Admin Settings',
            style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Backend Config
          _sectionTitle('Backend Configuration'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Spring Boot API URL',
                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, color: AppColors.navy)),
                const SizedBox(height: 4),
                Text('The base URL for your backend server.',
                    style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _apiUrlCtrl,
                      decoration: InputDecoration(
                        hintText: 'http://localhost:8080/api',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        prefixIcon: const Icon(Icons.link, color: AppColors.textLight),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy, foregroundColor: Colors.white),
                    onPressed: _savingApi ? null : _saveApiUrl,
                    child: _savingApi
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save'),
                  ),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    border: Border.all(color: AppColors.info.withOpacity(0.2)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline, color: AppColors.info, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Deployment URLs',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w600, color: AppColors.info)),
                        const SizedBox(height: 4),
                        Text('• Local: http://localhost:8080/api\n'
                            '• Docker: http://host.docker.internal:8080/api\n'
                            '• Production: https://your-server.com/api',
                            style: GoogleFonts.nunitoSans(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          // Multi-Tenant School Identity
          _sectionTitle('School Identity (Multi-Tenant)'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('School Code (Tenant ID)',
                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, color: AppColors.navy)),
                const SizedBox(height: 4),
                Text(
                  'Your unique school identifier. This determines which school\'s data is loaded. '
                  'Contact your platform admin if you don\'t know your school code.',
                  style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _tenantIdCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. springfield, dps_rohini',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        prefixIcon: const Icon(Icons.domain, color: AppColors.textLight),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy, foregroundColor: Colors.white),
                    onPressed: _savingTenant ? null : _saveTenantId,
                    child: _savingTenant
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save'),
                  ),
                ]),
                if (_tenantValidationMsg.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_tenantValidationMsg,
                      style: GoogleFonts.nunitoSans(
                          fontSize: 12,
                          color: _tenantValidationMsg.startsWith('School code saved')
                              ? AppColors.success
                              : AppColors.error)),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.business_outlined, color: AppColors.gold, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Each school gets its own isolated database. '
                        'Setting this code tells the app which school\'s data to show. '
                        'The code is sent as X-Tenant-ID header with every API request.',
                        style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          // School Info
          _sectionTitle('School Information'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _schoolNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'School Name',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMD)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white),
                    onPressed: _saveSchoolName,
                    child: const Text('Save'),
                  ),
                ]),
                const SizedBox(height: 12),
                _infoTile('Academic Year', '2025–2026', Icons.calendar_today_outlined),
                _infoTile('Affiliation', 'CBSE', Icons.school_outlined),
                _infoTile('Board Code', 'TBD', Icons.numbers_outlined),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          // Notifications
          _sectionTitle('Notification Preferences'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
            child: Column(children: [
              SwitchListTile(
                title: Text('Email Notifications',
                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
                subtitle: Text('Receive fee receipts and alerts via email',
                    style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.textSecondary)),
                value: _emailNotifications,
                activeColor: AppColors.navy,
                onChanged: (v) async {
                  setState(() => _emailNotifications = v);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('email_notifications', v);
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text('SMS Alerts', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
                subtitle: Text('Send fee reminders via SMS to parents',
                    style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.textSecondary)),
                value: _smsAlerts,
                activeColor: AppColors.navy,
                onChanged: (v) async {
                  setState(() => _smsAlerts = v);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('sms_alerts', v);
                },
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // Security
          _sectionTitle('Security'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.lock_outline, color: AppColors.navy),
                title: Text('Change Admin Password',
                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
                subtitle: Text('Update your admin login credentials',
                    style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openChangePasswordDialog,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.manage_accounts_outlined, color: AppColors.navy),
                title: Text('Manage Admin Roles',
                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
                subtitle: Text('Add or remove admin users',
                    style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Connect to Spring Security — GET /api/admin/users'),
                      backgroundColor: AppColors.navy),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // Data Backup
          _sectionTitle('Data Backup'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Download a full backup of all school data as a ZIP file containing JSON exports.',
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'Includes: students, fees, expenses, attendance, results, timetable, transport.',
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _backingUp ? null : _downloadBackup,
                    icon: _backingUp
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.download_outlined),
                    label: Text(
                      _backingUp ? 'Preparing backup...' : 'Backup Now',
                      style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    border: Border.all(color: AppColors.info.withOpacity(0.2)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline, color: AppColors.info, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The ZIP file will be saved to your browser\'s default download folder. '
                        'To always save backups to a specific folder, configure it in your browser\'s download settings.',
                        style: GoogleFonts.nunitoSans(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          // About
          _sectionTitle('About'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _aboutRow('App Version', '1.0.0'),
                _aboutRow('Built With', 'Flutter 3.x + Spring Boot 3.4.5'),
                _aboutRow('Database', 'MongoDB'),
                _aboutRow('UI Framework', 'Material 3 — Navy & Gold'),
                _aboutRow('Backend Port', '8080'),
              ]),
            ),
          ),

          const SizedBox(height: 40),

          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.logout),
              label: Text('Logout', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600, fontSize: 16)),
              onPressed: _logout,
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title,
            style: GoogleFonts.cormorantGaramond(
                fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.navy)),
      );

  Widget _infoTile(String label, String value, IconData icon) => ListTile(
        dense: true,
        leading: Icon(icon, size: 18, color: AppColors.textLight),
        title: Text(label, style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 13)),
        trailing: Text(value, style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
      );

  Widget _aboutRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ]),
      );
}
