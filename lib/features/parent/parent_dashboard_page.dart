import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/responsive.dart';
import '../../models/auth_models.dart';
import '../../services/auth_service.dart';

import 'screens/parent_overview_screen.dart';
import 'screens/child_attendance_screen.dart';
import 'screens/child_results_screen.dart';
import 'screens/child_fees_screen.dart';
import 'screens/child_timetable_screen.dart';

class _MenuItem {
  final IconData icon;
  final String label;
  const _MenuItem({required this.icon, required this.label});
}

final _menuItems = [
  const _MenuItem(icon: Icons.dashboard_outlined, label: 'Overview'),
  const _MenuItem(icon: Icons.rule_folder_outlined, label: 'Attendance'),
  const _MenuItem(icon: Icons.emoji_events_outlined, label: 'Results'),
  const _MenuItem(icon: Icons.receipt_long_outlined, label: 'Fees'),
  const _MenuItem(icon: Icons.table_chart_outlined, label: 'Timetable'),
  const _MenuItem(icon: Icons.chat_outlined, label: 'Chat'),
];

class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key});

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _sideMenuVisible = true;

  // Currently selected child (set from overview screen)
  String? _selectedChildId;
  String? _selectedChildName;

  void _selectChild(String childId, String childName) {
    setState(() {
      _selectedChildId = childId;
      _selectedChildName = childName;
    });
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return ParentOverviewScreen(
          onSelectChild: _selectChild,
          onNavigate: (index) => setState(() => _selectedIndex = index),
        );
      case 1:
        return ChildAttendanceScreen(
          studentId: _selectedChildId,
          studentName: _selectedChildName,
        );
      case 2:
        return ChildResultsScreen(
          studentId: _selectedChildId,
          studentName: _selectedChildName,
        );
      case 3:
        return ChildFeesScreen(
          studentId: _selectedChildId,
          studentName: _selectedChildName,
        );
      case 4:
        return ChildTimetableScreen(
          studentId: _selectedChildId,
          studentName: _selectedChildName,
        );
      case 5:
        return const Center(
          child: Text('Chat - Coming Soon'),
        );
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
        actions: [
          if (_selectedChildName != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: const Icon(Icons.person, size: 16),
                label: Text(_selectedChildName!,
                    style: GoogleFonts.poppins(fontSize: 12)),
                backgroundColor: AppColors.goldPale,
              ),
            ),
        ],
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
    final userName = user?.fullName ?? 'Parent';

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
              const Icon(Icons.family_restroom, color: Colors.white, size: 36),
              const SizedBox(height: 8),
              Text(userName,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text('Parent Portal',
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
