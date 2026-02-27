import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/responsive.dart';

// ── Existing live screens ──────────────────────────────────────────────────
import 'screens/attendance_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/students_screen.dart';
import 'screens/timetable_screen.dart';

// ── New screens (this PR) ──────────────────────────────────────────────────
import 'screens/admission_screen.dart';
import 'screens/expense_screen.dart';
import 'screens/fee_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/results_admin_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/transport_admin_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Menu data
// ─────────────────────────────────────────────────────────────────────────────

class _MenuItem {
  final IconData icon;
  final String label;
  final bool isLive;
  const _MenuItem({required this.icon, required this.label, this.isLive = false});
}

class _MenuGroup {
  final String title;
  final List<_MenuItem> items;
  const _MenuGroup({required this.title, required this.items});
}

// Flat list used for switch / index lookup (order must match _groups expansion)
const _allItems = [
  // ── ACADEMICS ──
  _MenuItem(icon: Icons.dashboard_outlined,      label: 'Overview',       isLive: true),  // 0
  _MenuItem(icon: Icons.people_alt_outlined,     label: 'Students',       isLive: true),  // 1
  _MenuItem(icon: Icons.person_add_alt_1_outlined, label: 'Admissions',   isLive: true),  // 2
  // ── FINANCE ──
  _MenuItem(icon: Icons.receipt_long_outlined,   label: 'Fees',           isLive: true),  // 3
  _MenuItem(icon: Icons.money_off_outlined,      label: 'Expenses',       isLive: true),  // 4
  _MenuItem(icon: Icons.assessment_outlined,     label: 'Reports',        isLive: true),  // 5
  // ── SCHOOL OPERATIONS ──
  _MenuItem(icon: Icons.rule_folder_outlined,    label: 'Attendance',     isLive: true),  // 6
  _MenuItem(icon: Icons.table_chart_outlined,    label: 'Timetable',      isLive: true),  // 7
  _MenuItem(icon: Icons.emoji_events_outlined,   label: 'Results',        isLive: true),  // 8
  _MenuItem(icon: Icons.directions_bus_outlined, label: 'Transport',      isLive: true),  // 9
  // ── COMMUNICATION ──
  _MenuItem(icon: Icons.notifications_active_outlined, label: 'Notifications', isLive: true), // 10
  // ── ADMINISTRATION ──
  _MenuItem(icon: Icons.settings_outlined,       label: 'Settings',       isLive: true),  // 11
];

const _groups = [
  _MenuGroup(title: 'ACADEMICS',          items: [_allItems[0], _allItems[1], _allItems[2]]),
  _MenuGroup(title: 'FINANCE',            items: [_allItems[3], _allItems[4], _allItems[5]]),
  _MenuGroup(title: 'SCHOOL OPERATIONS',  items: [_allItems[6], _allItems[7], _allItems[8], _allItems[9]]),
  _MenuGroup(title: 'COMMUNICATION',      items: [_allItems[10]]),
  _MenuGroup(title: 'ADMINISTRATION',     items: [_allItems[11]]),
];

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;
  bool _sideMenuVisible = true;

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:  return const _OverviewContent();
      case 1:  return const StudentsScreen();
      case 2:  return const AdmissionScreen();
      case 3:  return const FeeScreen();
      case 4:  return const ExpenseScreen();
      case 5:  return const ReportsScreen();
      case 6:  return const AttendanceScreen();
      case 7:  return const TimetableScreen();
      case 8:  return const ResultsAdminScreen();
      case 9:  return const TransportAdminScreen();
      case 10: return const NotificationsScreen();
      case 11: return const SettingsScreen();
      default: return const SizedBox.shrink();
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
          _allItems[_selectedIndex].label,
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
    // Build a flat index so that tapping a group item knows its global index.
    int globalIndex = 0;
    final groupWidgets = <Widget>[];

    for (final group in _groups) {
      groupWidgets.add(_buildGroupHeader(group.title));
      for (final item in group.items) {
        final idx = globalIndex;
        groupWidgets.add(_buildMenuItem(item, idx));
        globalIndex++;
      }
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Sidebar header ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
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
        // ── Grouped items ──────────────────────────────────────────────────
        ...groupWidgets,
        const Divider(indent: 16, endIndent: 16, height: 24),
        // ── Logout ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Logout — implement with Spring Security'),
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
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        title,
        style: GoogleFonts.nunitoSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textLight,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuItem(_MenuItem item, int index) {
    final isActive = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: isActive
            ? AppColors.navy.withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() => _selectedIndex = index);
            if (!Responsive.isDesktop(context)) Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(item.icon,
                    size: 18,
                    color: isActive
                        ? AppColors.navy
                        : AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.label,
                      style: GoogleFonts.nunitoSans(
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w400,
                        color: isActive
                            ? AppColors.navy
                            : AppColors.textPrimary,
                        fontSize: 13,
                      )),
                ),
                if (item.isLive)
                  Container(
                    width: 6,
                    height: 6,
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overview
// ─────────────────────────────────────────────────────────────────────────────

class _OverviewContent extends StatelessWidget {
  const _OverviewContent();

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
          Text('Live Modules',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text('All modules below are connected to the Spring Boot backend.',
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _liveChip(Icons.people_alt_outlined,          'Students'),
            _liveChip(Icons.person_add_alt_1_outlined,    'Admissions'),
            _liveChip(Icons.receipt_long_outlined,        'Fees'),
            _liveChip(Icons.money_off_outlined,           'Expenses'),
            _liveChip(Icons.assessment_outlined,          'Reports'),
            _liveChip(Icons.rule_folder_outlined,         'Attendance'),
            _liveChip(Icons.table_chart_outlined,         'Timetable'),
            _liveChip(Icons.emoji_events_outlined,        'Results'),
            _liveChip(Icons.directions_bus_outlined,      'Transport'),
            _liveChip(Icons.notifications_active_outlined,'Notifications'),
            _liveChip(Icons.settings_outlined,            'Settings'),
          ]),
        ],
      ),
    );
  }

  Widget _liveChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.success.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: AppColors.success),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success)),
          const SizedBox(width: 5),
          Container(
              width: 5,
              height: 5,
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
