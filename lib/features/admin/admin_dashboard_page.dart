import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/responsive.dart';
import '../../models/auth_models.dart';
import '../../services/auth_service.dart';

// -- Existing live screens
import 'screens/attendance_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/students_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/admission_screen.dart';
import 'screens/expense_screen.dart';
import 'screens/fee_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/results_admin_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/transport_admin_screen.dart';

// -- New screens (Phase 1 & 2)
import 'screens/hr_screen.dart';
import 'screens/discipline_screen.dart';
import 'screens/certificates_screen.dart';
import '../../features/chat/chat_list_screen.dart';

// --------- Menu data ---------

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
final _allItems = [
  // -- ACADEMICS --
  const _MenuItem(icon: Icons.dashboard_outlined,        label: 'Overview',       isLive: true),  // 0
  const _MenuItem(icon: Icons.people_alt_outlined,       label: 'Students',       isLive: true),  // 1
  const _MenuItem(icon: Icons.person_add_alt_1_outlined, label: 'Admissions',     isLive: true),  // 2
  // -- FINANCE --
  const _MenuItem(icon: Icons.receipt_long_outlined,     label: 'Fees',           isLive: true),  // 3
  const _MenuItem(icon: Icons.money_off_outlined,        label: 'Expenses',       isLive: true),  // 4
  const _MenuItem(icon: Icons.assessment_outlined,       label: 'Reports',        isLive: true),  // 5
  // -- SCHOOL OPERATIONS --
  const _MenuItem(icon: Icons.rule_folder_outlined,      label: 'Attendance',     isLive: true),  // 6
  const _MenuItem(icon: Icons.table_chart_outlined,      label: 'Timetable',      isLive: true),  // 7
  const _MenuItem(icon: Icons.emoji_events_outlined,     label: 'Results',        isLive: true),  // 8
  const _MenuItem(icon: Icons.directions_bus_outlined,   label: 'Transport',      isLive: true),  // 9
  const _MenuItem(icon: Icons.gavel_outlined,            label: 'Discipline',     isLive: true),  // 10
  // -- COMMUNICATION --
  const _MenuItem(icon: Icons.notifications_active_outlined, label: 'Notifications', isLive: true), // 11
  const _MenuItem(icon: Icons.chat_outlined,             label: 'Chat',           isLive: true),  // 12
  // -- HR & PAYROLL --
  const _MenuItem(icon: Icons.badge_outlined,            label: 'HR & Staff',     isLive: true),  // 13
  // -- ADMINISTRATION --
  const _MenuItem(icon: Icons.description_outlined,      label: 'Certificates',   isLive: true),  // 14
  const _MenuItem(icon: Icons.settings_outlined,         label: 'Settings',       isLive: true),  // 15
];

final _groups = [
  _MenuGroup(title: 'ACADEMICS',         items: [_allItems[0], _allItems[1], _allItems[2]]),
  _MenuGroup(title: 'FINANCE',           items: [_allItems[3], _allItems[4], _allItems[5]]),
  _MenuGroup(title: 'SCHOOL OPERATIONS', items: [_allItems[6], _allItems[7], _allItems[8], _allItems[9], _allItems[10]]),
  _MenuGroup(title: 'COMMUNICATION',     items: [_allItems[11], _allItems[12]]),
  _MenuGroup(title: 'HR & PAYROLL',      items: [_allItems[13]]),
  _MenuGroup(title: 'ADMINISTRATION',    items: [_allItems[14], _allItems[15]]),
];

// --------- Page ---------

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _sideMenuVisible = true;

  // Maps bottom-nav slot -> global _allItems index: Overview, Students, Fees, Admissions
  static const _bottomNavToGlobal = [0, 1, 3, 2];

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
      case 10: return const DisciplineScreen();
      case 11: return const NotificationsScreen();
      case 12: return const ChatListScreen();
      case 13: return const HrScreen();
      case 14: return const CertificatesScreen();
      case 15: return const SettingsScreen();
      default: return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile  = Responsive.isMobile(context);
    final isDesktop = Responsive.isDesktop(context);
    // Desktop sidebar: 240px | Tablet sidebar: 200px
    final sidebarWidth = isDesktop ? 240.0 : 200.0;

    // Find which bottom-nav slot to highlight; fall back to "More" (slot 4)
    int bottomIdx = _bottomNavToGlobal.indexOf(_selectedIndex);
    if (bottomIdx == -1) bottomIdx = 4;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        leading: isMobile
            // Mobile: hamburger opens the drawer
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              )
            // Tablet / Desktop: hamburger toggles the persistent sidebar
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () =>
                    setState(() => _sideMenuVisible = !_sideMenuVisible),
              ),
        title: Text(
          _allItems[_selectedIndex].label,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          // Full text on tablet/desktop; icon-only on mobile to save space
          if (!isMobile)
            TextButton.icon(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, AppRouter.home),
              icon: const Icon(Icons.public, color: AppColors.goldLight, size: 18),
              label: Text('View Website',
                  style: GoogleFonts.poppins(
                      color: AppColors.goldLight, fontSize: 12)),
            )
          else
            IconButton(
              icon: const Icon(Icons.public, color: AppColors.goldLight),
              tooltip: 'View Website',
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, AppRouter.home),
            ),
          const SizedBox(width: 4),
        ],
      ),
      // Drawer only on mobile; tablet + desktop use persistent sidebar
      drawer: isMobile
          ? Drawer(
              backgroundColor: AppColors.white,
              child: _buildMenuList(),
            )
          : null,
      // Bottom nav only on mobile for quick section switching
      bottomNavigationBar: isMobile ? _buildBottomNav(bottomIdx) : null,
      body: Row(
        children: [
          // Persistent sidebar for tablet and desktop
          if (!isMobile && _sideMenuVisible)
            Material(
              elevation: 2,
              child: SizedBox(
                width: sidebarWidth,
                child: ColoredBox(
                  color: AppColors.white,
                  child: _buildMenuList(),
                ),
              ),
            ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildBottomNav(int currentIndex) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.white,
      selectedItemColor: AppColors.navy,
      unselectedItemColor: AppColors.textLight,
      selectedLabelStyle:
          GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
      elevation: 8,
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
        BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined), label: 'Students'),
        BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined), label: 'Fees'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_add_alt_1_outlined), label: 'Admissions'),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'More'),
      ],
      onTap: (idx) {
        if (idx == 4) {
          _scaffoldKey.currentState?.openDrawer();
        } else {
          setState(() => _selectedIndex = _bottomNavToGlobal[idx]);
        }
      },
    );
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AppRouter.login);
    }
  }

  Widget _buildMenuList() {
    final auth = AuthService.instance;
    // Build a flat index so that tapping a group item knows its global index.
    int globalIndex = 0;
    final groupWidgets = <Widget>[];

    for (final group in _groups) {
      // Collect visible items in this group
      final visibleItems = <_MenuItem>[];
      final visibleIndices = <int>[];
      for (final item in group.items) {
        if (auth.canAccessMenu(item.label)) {
          visibleItems.add(item);
          visibleIndices.add(globalIndex);
        }
        globalIndex++;
      }
      // Only render the group header if it has visible items
      if (visibleItems.isNotEmpty) {
        groupWidgets.add(_buildGroupHeader(group.title));
        for (int i = 0; i < visibleItems.length; i++) {
          groupWidgets.add(_buildMenuItem(visibleItems[i], visibleIndices[i]));
        }
      }
    }

    final user = auth.currentUser;
    final userName = user?.fullName ?? 'Admin';
    final userRole = user != null ? UserRole.displayName(user.role) : 'Dashboard';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // -- Sidebar header
        Container(
          padding: EdgeInsets.fromLTRB(
              20, Responsive.isMobile(context) ? 48 : 24, 20, 20),
          color: AppColors.navy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.school_rounded, color: Colors.white, size: 36),
              const SizedBox(height: 8),
              Text(userName,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(userRole,
                  style: GoogleFonts.poppins(
                      color: AppColors.goldLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w400)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // -- Grouped items (role-filtered)
        ...groupWidgets,
        const Divider(indent: 16, endIndent: 16, height: 24),
        // -- Logout
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _logout,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.logout_outlined,
                      size: 20, color: AppColors.error),
                  const SizedBox(width: 14),
                  Text('Logout',
                      style: GoogleFonts.poppins(
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textLight,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildMenuItem(_MenuItem item, int index) {
    final isActive = _selectedIndex == index;
    return Material(
      color: isActive ? AppColors.goldPale : Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedIndex = index);
          // Close the drawer when a section is selected -- only on mobile
          if (Responsive.isMobile(context)) Navigator.pop(context);
        },
        child: Container(
          decoration: isActive
              ? const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.gold, width: 3),
                  ),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: Row(
            children: [
              Icon(item.icon,
                  size: 18,
                  color: isActive ? AppColors.navy : AppColors.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(item.label,
                    style: GoogleFonts.poppins(
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? AppColors.navy
                          : AppColors.textSecondary,
                      fontSize: 13,
                    )),
              ),
              if (item.isLive)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.gold
                        : AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------- Overview ---------

class _OverviewContent extends StatelessWidget {
  const _OverviewContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Welcome Back, ${AuthService.instance.currentUser?.fullName?.split(' ').first ?? 'Admin'}!',
              style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text("Here's a quick overview of your school.",
              style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400)),
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
                  _statCard(context, 'Revenue (Month)', 'Rs 12.5L',
                      Icons.monetization_on_rounded, const Color(0xFFDB2777),
                      constraints.maxWidth, columns),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Text('Live Modules',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text('All modules below are connected to the Spring Boot backend.',
              style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w400)),
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
            _liveChip(Icons.gavel_outlined,               'Discipline'),
            _liveChip(Icons.chat_outlined,                'Chat'),
            _liveChip(Icons.badge_outlined,               'HR & Staff'),
            _liveChip(Icons.description_outlined,         'Certificates'),
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
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
                          style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: color)),
                      const SizedBox(height: 2),
                      Text(title,
                          style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
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
