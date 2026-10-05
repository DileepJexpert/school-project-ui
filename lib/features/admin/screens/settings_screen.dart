import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../services/dio_client.dart';
import '../../../services/auth_service.dart';
import '../../../services/tenant_service.dart';
import '../../../models/school_data.dart';
import 'user_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiUrlCtrl = TextEditingController();
  final _schoolNameCtrl = TextEditingController(text: AppStrings.schoolName);
  final _tenantIdCtrl = TextEditingController();
  bool _savingApi = false;
  bool _savingTenant = false;
  String _tenantValidationMsg = '';
  String _academicYear = '';
  String _board = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final tenantId = await TenantService.getTenantId();
    Map<String, dynamic>? profile;
    Map<String, dynamic>? catalogue;
    try {
      profile = Map<String, dynamic>.from(
          (await DioClient.get('/school/profile')).data as Map);
      catalogue = Map<String, dynamic>.from(
          (await DioClient.get('/master-data')).data as Map);
    } catch (_) {
      // The settings page still opens when the API is temporarily unavailable.
    }
    if (!mounted) return;
    setState(() {
      _apiUrlCtrl.text = DioClient.baseUrl;
      _tenantIdCtrl.text = tenantId == 'default' ? '' : tenantId;
      _schoolNameCtrl.text = profile?['name']?.toString() ?? AppStrings.schoolName;
      _board = profile?['board']?.toString() ?? '';
      _academicYear = catalogue?['academicYear']?.toString() ?? '';
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
      final previousTenant = await TenantService.getTenantId();
      if (tenantId != previousTenant) {
        await AuthService.instance.logout();
      }
      await TenantService.setTenant(tenantId);
      await SchoolData.load();
      if (!mounted) return;
      if (tenantId != previousTenant) {
        Navigator.of(context).pushNamedAndRemoveUntil(
            AppRouter.login, (route) => false);
      } else {
        setState(() => _tenantValidationMsg = 'School code saved: $tenantId');
      }
    } catch (e) {
      if (mounted) setState(() => _tenantValidationMsg = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _savingTenant = false);
    }
  }

  Future<void> _saveApiUrl() async {
    setState(() => _savingApi = true);
    try {
      await DioClient.setBaseUrl(_apiUrlCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('API URL saved and applied.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$error'), backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _savingApi = false);
    }
  }

  Future<void> _saveSchoolName() async {
    try {
      final response = await DioClient.put('/school/profile',
          data: {'name': _schoolNameCtrl.text.trim()});
      AppStrings.schoolName = response.data['name'] as String;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('School name saved!'), backgroundColor: AppColors.success,
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save school name: $error'),
          backgroundColor: AppColors.error,
        ));
      }
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
        content: Text('Are you sure you want to logout from the admin panel?',
            style: GoogleFonts.nunitoSans()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await AuthService.instance.logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
            AppRouter.home, (route) => false);
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
                    icon: Icon(
                        obscureNew ? Icons.visibility_off : Icons.visibility),
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
                      if (newCtrl.text.length < 8) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content:
                                Text('Password must be at least 8 characters.'),
                            backgroundColor: AppColors.error));
                        return;
                      }
                      setDlg(() => saving = true);
                      try {
                        await DioClient.post('/users/change-password', data: {
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
            style: GoogleFonts.cormorantGaramond(
                fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Backend Config
          _sectionTitle('Backend Configuration'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FastAPI URL',
                        style: GoogleFonts.nunitoSans(
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy)),
                    const SizedBox(height: 4),
                    Text('The base URL for your backend server.',
                        style: GoogleFonts.nunitoSans(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _apiUrlCtrl,
                          decoration: InputDecoration(
                            hintText: 'http://localhost:8000/api',
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radiusMD)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            prefixIcon: const Icon(Icons.link,
                                color: AppColors.textLight),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white),
                        onPressed: _savingApi ? null : _saveApiUrl,
                        child: _savingApi
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Save'),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                        border:
                            Border.all(color: AppColors.info.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppColors.info, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Deployment URLs',
                                        style: GoogleFonts.nunitoSans(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.info)),
                                    const SizedBox(height: 4),
                                    Text(
                                        '• Local: http://localhost:8000/api\n'
                                        '• Docker: http://host.docker.internal:8000/api\n'
                                        '• Production: https://your-server.com/api',
                                        style: GoogleFonts.nunitoSans(
                                            color: AppColors.textSecondary,
                                            fontSize: 12)),
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('School Code (Tenant ID)',
                        style: GoogleFonts.nunitoSans(
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy)),
                    const SizedBox(height: 4),
                    Text(
                      'Your unique school identifier. This determines which school\'s data is loaded. '
                      'Contact your platform admin if you don\'t know your school code.',
                      style: GoogleFonts.nunitoSans(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _tenantIdCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. springfield, dps_rohini',
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radiusMD)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            prefixIcon: const Icon(Icons.domain,
                                color: AppColors.textLight),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white),
                        onPressed: _savingTenant ? null : _saveTenantId,
                        child: _savingTenant
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Save'),
                      ),
                    ]),
                    if (_tenantValidationMsg.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_tenantValidationMsg,
                          style: GoogleFonts.nunitoSans(
                              fontSize: 12,
                              color: _tenantValidationMsg
                                      .startsWith('School code saved')
                                  ? AppColors.success
                                  : AppColors.error)),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                        border:
                            Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.business_outlined,
                                color: AppColors.gold, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Each school gets its own isolated database. '
                                'Setting this code tells the app which school\'s data to show. '
                                'The code is sent as X-Tenant-ID header with every API request.',
                                style: GoogleFonts.nunitoSans(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
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
                _infoTile('Academic Year', _academicYear,
                    Icons.calendar_today_outlined),
                _infoTile('Affiliation', AppStrings.accreditation, Icons.school_outlined),
                _infoTile('Board', _board, Icons.numbers_outlined),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          _sectionTitle('Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Interface theme',
                    style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Applies across navigation, cards, forms, tables, and shared page components.',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = constraints.maxWidth >= 680
                          ? (constraints.maxWidth - 20) / 3
                          : constraints.maxWidth;
                      return AnimatedBuilder(
                        animation: ThemeController.instance,
                        builder: (context, _) => Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: AppThemePreset.values
                              .map((preset) => SizedBox(
                                    width: itemWidth,
                                    child: _themeOption(preset),
                                  ))
                              .toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Notifications
          _sectionTitle('Notifications'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined, color: AppColors.navy),
              title: Text('In-app notifications',
                  style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
              subtitle: Text('School notifications are available in the app. Email and SMS delivery require a provider and are not enabled.',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 13, color: AppColors.textSecondary)),
            ),
          ),

          const SizedBox(height: 20),

          // Security
          _sectionTitle('Security'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.lock_outline, color: AppColors.navy),
                title: Text('Change Admin Password',
                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
                subtitle: Text('Update your admin login credentials',
                    style: GoogleFonts.nunitoSans(
                        fontSize: 13, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openChangePasswordDialog,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.manage_accounts_outlined,
                    color: AppColors.navy),
                title: Text('Manage Admin Roles',
                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
                subtitle: Text('Add or remove admin users',
                    style: GoogleFonts.nunitoSans(
                        fontSize: 13, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const UserManagementScreen())),
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
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The server operator backs up PostgreSQL and the video storage volume together.',
                      style: GoogleFonts.nunitoSans(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A restore test is required before school records are entered.',
                      style: GoogleFonts.nunitoSans(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                        border:
                            Border.all(color: AppColors.info.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppColors.info, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Contact the server operator for a dated backup and restore report. '
                                'A browser download is not a complete database backup.',
                                style: GoogleFonts.nunitoSans(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _aboutRow('App Version', '1.0.0'),
                    _aboutRow('Built With', 'Flutter + FastAPI + PostgreSQL'),
                    _aboutRow('Database', 'MongoDB'),
                    _aboutRow('UI Framework', 'Material 3 — Navy & Gold'),
                    _aboutRow('Backend Port', '8000'),
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
              label: Text('Logout',
                  style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w600, fontSize: 16)),
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
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.navy)),
      );

  Widget _themeOption(AppThemePreset preset) {
    final selected = ThemeController.instance.preset == preset;
    final preview = AppTheme.forPreset(preset).extension<AppThemePalette>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      onTap: () => ThemeController.instance.setPreset(preset),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              selected ? preview.brand.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
          border: Border.all(
            color: selected ? preview.brand : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: preview.heroGradient,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                selected ? Icons.check_rounded : Icons.palette_outlined,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.label,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    preset.description,
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
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) => ListTile(
        dense: true,
        leading: Icon(icon, size: 18, color: AppColors.textLight),
        title: Text(label,
            style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary, fontSize: 13)),
        trailing: Text(value,
            style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
      );

  Widget _aboutRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ]),
      );
}
