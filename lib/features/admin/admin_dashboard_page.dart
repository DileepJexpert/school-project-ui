import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/responsive.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;
  bool _sideMenuVisible = true;

  static final _menuItems = [
    _MenuItem(icon: Icons.dashboard_outlined, label: 'Overview'),
    _MenuItem(icon: Icons.people_alt_outlined, label: 'Students'),
    _MenuItem(icon: Icons.badge_outlined, label: 'Staff'),
    _MenuItem(icon: Icons.school_outlined, label: 'Classes'),
    _MenuItem(icon: Icons.receipt_long_outlined, label: 'Fees'),
    _MenuItem(icon: Icons.directions_bus_outlined, label: 'Transport'),
    _MenuItem(icon: Icons.rule_folder_outlined, label: 'Attendance'),
    _MenuItem(icon: Icons.assessment_outlined, label: 'Results'),
    _MenuItem(icon: Icons.notifications_active_outlined, label: 'Notifications'),
    _MenuItem(icon: Icons.event_outlined, label: 'Events'),
    _MenuItem(icon: Icons.photo_library_outlined, label: 'Gallery'),
    _MenuItem(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        leading: isDesktop
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => setState(() => _sideMenuVisible = !_sideMenuVisible),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pushReplacementNamed(context, AppRouter.home),
              ),
        title: Text(_menuItems[_selectedIndex].label,
          style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, fontSize: 22)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(context, AppRouter.home),
            icon: const Icon(Icons.public, color: AppColors.goldLight, size: 18),
            label: Text('View Website', style: GoogleFonts.nunitoSans(color: AppColors.goldLight, fontSize: 12)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isDesktop ? null : Drawer(
        backgroundColor: AppColors.white,
        child: _buildMenuList(),
      ),
      body: Row(
        children: [
          if (isDesktop && _sideMenuVisible)
            Material(
              elevation: 2,
              child: Container(
                width: 240,
                color: AppColors.white,
                child: _buildMenuList(),
              ),
            ),
          Expanded(
            child: _selectedIndex == 0
                ? _OverviewContent()
                : _PlaceholderContent(title: _menuItems[_selectedIndex].label),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          color: AppColors.navy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.school_rounded, color: Colors.white, size: 36),
              const SizedBox(height: 8),
              Text('School Admin', style: GoogleFonts.cormorantGaramond(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              Text('Management Dashboard', style: GoogleFonts.nunitoSans(
                color: AppColors.goldLight, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(_menuItems.length, (i) {
          final item = _menuItems[i];
          final isActive = _selectedIndex == i;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Material(
              color: isActive ? AppColors.navy.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() => _selectedIndex = i);
                  if (!Responsive.isDesktop(context)) Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(item.icon, size: 20,
                        color: isActive ? AppColors.navy : AppColors.textSecondary),
                      const SizedBox(width: 14),
                      Text(item.label, style: GoogleFonts.nunitoSans(
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                        color: isActive ? AppColors.navy : AppColors.textPrimary,
                        fontSize: 14,
                      )),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const Divider(indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logout — implement with Spring Security'), backgroundColor: AppColors.navy),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.logout_outlined, size: 20, color: AppColors.error),
                  const SizedBox(width: 14),
                  Text('Logout', style: GoogleFonts.nunitoSans(color: AppColors.error, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome Back, Admin!', style: GoogleFonts.cormorantGaramond(
            fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.navy)),
          const SizedBox(height: 4),
          Text("Here's a quick overview of your school.", style: GoogleFonts.nunitoSans(
            color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = Responsive.gridColumns(context);
              return Wrap(
                spacing: 16, runSpacing: 16,
                children: [
                  _statCard(context, 'Total Students', '2,400', Icons.people_alt_rounded, AppColors.navy, constraints.maxWidth, columns),
                  _statCard(context, 'Total Staff', '180', Icons.badge_rounded, const Color(0xFF0D9488), constraints.maxWidth, columns),
                  _statCard(context, 'Upcoming Events', '3', Icons.event_available_rounded, AppColors.gold, constraints.maxWidth, columns),
                  _statCard(context, 'Revenue (Month)', '₹12.5L', Icons.monetization_on_rounded, const Color(0xFFDB2777), constraints.maxWidth, columns),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String title, String value, IconData icon, Color color, double maxWidth, int columns) {
    return SizedBox(
      width: (maxWidth - (columns - 1) * 16) / columns,
      child: Card(
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(icon, size: 26, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value, style: GoogleFonts.cormorantGaramond(
                        fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(title, style: GoogleFonts.nunitoSans(
                        color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderContent extends StatelessWidget {
  final String title;
  const _PlaceholderContent({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_rounded, size: 64, color: AppColors.textLight.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.cormorantGaramond(
            fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.navy)),
          const SizedBox(height: 8),
          Text('This module is ready for development.', style: GoogleFonts.nunitoSans(
            color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          Text('Connect to Spring Boot API to activate.', style: GoogleFonts.nunitoSans(
            color: AppColors.textLight, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  const _MenuItem({required this.icon, required this.label});
}
