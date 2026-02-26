import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/responsive.dart';
import 'screens/attendance_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/students_screen.dart';
import 'screens/timetable_screen.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;
  bool _sideMenuVisible = true;

  static final _menuItems = [
    _MenuItem(icon: Icons.dashboard_outlined, label: 'Overview'),         // 0
    _MenuItem(icon: Icons.people_alt_outlined, label: 'Students'),        // 1  ← live
    _MenuItem(icon: Icons.badge_outlined, label: 'Staff'),                // 2
    _MenuItem(icon: Icons.school_outlined, label: 'Classes'),             // 3
    _MenuItem(icon: Icons.receipt_long_outlined, label: 'Fees'),          // 4
    _MenuItem(icon: Icons.directions_bus_outlined, label: 'Transport'),   // 5
    _MenuItem(icon: Icons.rule_folder_outlined, label: 'Attendance'),     // 6  ← live
    _MenuItem(icon: Icons.table_chart_outlined, label: 'Timetable'),      // 7  ← live
    _MenuItem(icon: Icons.assessment_outlined, label: 'Results'),         // 8
    _MenuItem(icon: Icons.notifications_active_outlined, label: 'Notifications'), // 9 ← live
    _MenuItem(icon: Icons.event_outlined, label: 'Events'),               // 10
    _MenuItem(icon: Icons.photo_library_outlined, label: 'Gallery'),      // 11
    _MenuItem(icon: Icons.settings_outlined, label: 'Settings'),          // 12
  ];

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _OverviewContent();
      case 1:
        return const StudentsScreen();
      case 6:
        return const AttendanceScreen();
      case 7:
        return const TimetableScreen();
      case 9:
        return const NotificationsScreen();
      default:
        return _PlaceholderContent(title: _menuItems[_selectedIndex].label);
    }
  }

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
                onPressed: () =>
                    setState(() => _sideMenuVisible = !_sideMenuVisible),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, AppRouter.home),
              ),
        title: Text(
          _menuItems[_selectedIndex].label,
          style: GoogleFonts.cormorantGaramond(
              fontWeight: FontWeight.w700, fontSize: 22),
        ),
        actions: [
          TextButton.icon(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, AppRouter.home),
            icon: const Icon(Icons.public, color: AppColors.goldLight, size: 18),
            label: Text('View Website',
                style: GoogleFonts.nunitoSans(
                    color: AppColors.goldLight, fontSize: 12)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isDesktop
          ? null
          : Drawer(
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
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildMenuList() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Sidebar header
        Container(
          padding: const EdgeInsets.all(20),
          color: AppColors.navy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.school_rounded, color: Colors.white, size: 36),
              const SizedBox(height: 8),
              Text('School Admin',
                  style: GoogleFonts.cormorantGaramond(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              Text('Management Dashboard',
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.goldLight, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(_menuItems.length, (i) {
          final item = _menuItems[i];
          final isActive = _selectedIndex == i;
          // Live modules get a gold dot indicator
          final isLive = [1, 6, 7, 9].contains(i);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Material(
              color: isActive
                  ? AppColors.navy.withOpacity(0.08)
                  : Colors.transparent,
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
                      Icon(item.icon,
                          size: 20,
                          color: isActive
                              ? AppColors.navy
                              : AppColors.textSecondary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(item.label,
                            style: GoogleFonts.nunitoSans(
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isActive
                                  ? AppColors.navy
                                  : AppColors.textPrimary,
                              fontSize: 14,
                            )),
                      ),
                      if (isLive)
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
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
                const SnackBar(
                    content:
                        Text('Logout — implement with Spring Security'),
                    backgroundColor: AppColors.navy),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.logout_outlined,
                      size: 20, color: AppColors.error),
                  const SizedBox(width: 14),
                  Text('Logout',
                      style: GoogleFonts.nunitoSans(
                          color: AppColors.error, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Overview Content (unchanged)
// ──────────────────────────────────────────────────────────────────────────────
class _OverviewContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome Back, Admin!',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text("Here's a quick overview of your school.",
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = Responsive.gridColumns(context);
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _statCard(context, 'Total Students', '2,400',
                      Icons.people_alt_rounded, AppColors.navy,
                      constraints.maxWidth, columns),
                  _statCard(context, 'Total Staff', '180',
                      Icons.badge_rounded, const Color(0xFF0D9488),
                      constraints.maxWidth, columns),
                  _statCard(context, 'Upcoming Events', '3',
                      Icons.event_available_rounded, AppColors.gold,
                      constraints.maxWidth, columns),
                  _statCard(context, 'Revenue (Month)', '₹12.5L',
                      Icons.monetization_on_rounded, const Color(0xFFDB2777),
                      constraints.maxWidth, columns),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          // Quick-access live modules
          Text('Live Modules',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text('These modules are connected to the Spring Boot backend.',
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _liveChip(Icons.people_alt_outlined, 'Students'),
            _liveChip(Icons.rule_folder_outlined, 'Attendance'),
            _liveChip(Icons.table_chart_outlined, 'Timetable'),
            _liveChip(Icons.notifications_active_outlined, 'Notifications'),
          ]),
        ],
      ),
    );
  }

  Widget _liveChip(IconData icon, String label) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.success.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: AppColors.success),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success)),
          const SizedBox(width: 6),
          Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  color: AppColors.success, shape: BoxShape.circle)),
        ]),
      );

  Widget _statCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    double maxWidth,
    int columns,
  ) {
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
                      Text(value,
                          style: GoogleFonts.cormorantGaramond(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(title,
                          style: GoogleFonts.nunitoSans(
                              color: AppColors.textSecondary,
                              fontSize: 13)),
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

// ──────────────────────────────────────────────────────────────────────────────
// Placeholder for modules not yet implemented
// ──────────────────────────────────────────────────────────────────────────────
class _PlaceholderContent extends StatelessWidget {
  final String title;
  const _PlaceholderContent({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_rounded,
              size: 64, color: AppColors.textLight.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 8),
          Text('This module is ready for development.',
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          Text('Spring Boot API is running at localhost:8080.',
              style: GoogleFonts.nunitoSans(
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
