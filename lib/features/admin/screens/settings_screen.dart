import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiUrlCtrl = TextEditingController();
  final _schoolNameCtrl = TextEditingController(text: AppStrings.schoolName);
  bool _darkMode = false;
  bool _emailNotifications = true;
  bool _smsAlerts = false;
  bool _savingApi = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiUrlCtrl.text = prefs.getString('api_base_url') ?? 'http://localhost:8080/api';
      _emailNotifications = prefs.getBool('email_notifications') ?? true;
      _smsAlerts = prefs.getBool('sms_alerts') ?? false;
    });
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

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    _schoolNameCtrl.dispose();
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

          // School Info
          _sectionTitle('School Information'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                TextField(
                  controller: _schoolNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'School Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                  ),
                ),
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
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Connect to Spring Security — PUT /api/admin/password'),
                      backgroundColor: AppColors.navy),
                ),
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
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Add JWT auth with Spring Security to enable logout'),
                    backgroundColor: AppColors.navy),
              ),
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
