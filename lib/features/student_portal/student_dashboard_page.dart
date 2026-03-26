import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/responsive.dart';
import '../../services/auth_service.dart';

import 'screens/student_overview_screen.dart';
import 'screens/my_attendance_screen.dart';
import 'screens/my_results_screen.dart';
import 'screens/my_timetable_screen.dart';
import 'screens/my_fees_screen.dart';

class _MenuItem {
  final IconData icon;
  final String label;
  const _MenuItem({required this.icon, required this.label});
}

final _menuItems = [
  const _MenuItem(icon: Icons.dashboard_outlined, label: 'Overview'),
  const _MenuItem(icon: Icons.rule_folder_outlined, label: 'Attendance'),
  const _MenuItem(icon: Icons.emoji_events_outlined, label: 'Results'),
  const _MenuItem(icon: Icons.table_chart_outlined, label: 'Timetable'),
  const _MenuItem(icon: Icons.receipt_long_outlined, label: 'Fees'),
];

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _sideMenuVisible = true;

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return StudentOverviewScreen(
          onNavigate: (index) => setState(() => _selectedIndex = index),
        );
      case 1:
        return const MyAttendanceScreen();
      case 2:
        return const MyResultsScreen();
      case 3:
        return const MyTimetableScreen();
      case 4:
        return const MyFeesScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isDesktop = Responsive.isDesktop(context);
    final sidebarWidth = isDesktop ? 240.0 : 200.0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        leading: isMobile
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              )
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () =>
                    setState(() => _sideMenuVisible = !_sideMenuVisible),
              ),
        title: Text(
          _menuItems[_selectedIndex].label,
          style:
              GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      drawer: isMobile
          ? Drawer(
              backgroundColor: AppColors.white,
              child: _buildMenuList(),
            )
          : null,
      body: Row(
        children: [
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

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AppRouter.login);
    }
  }

  Widget _buildMenuList() {
    final user = AuthService.instance.currentUser;
    final userName = user?.fullName ?? 'Student';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
              20, Responsive.isMobile(context) ? 48 : 24, 20, 20),
          color: AppColors.navy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.school, color: Colors.white, size: 36),
              const SizedBox(height: 8),
              Text(userName,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text('Student Portal',
                  style: GoogleFonts.poppins(
                      color: AppColors.goldLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w400)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _menuItems.length; i++) _buildMenuItem(i),
        const Divider(indent: 16, endIndent: 16, height: 24),
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
      ],
    );
  }

  Widget _buildMenuItem(int index) {
    final item = _menuItems[index];
    final isActive = _selectedIndex == index;
    return Material(
      color: isActive ? AppColors.goldPale : Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedIndex = index);
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
                  color:
                      isActive ? AppColors.navy : AppColors.textSecondary),
              const SizedBox(width: 14),
              Text(item.label,
                  style: GoogleFonts.poppins(
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive
                        ? AppColors.navy
                        : AppColors.textSecondary,
                    fontSize: 13,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
