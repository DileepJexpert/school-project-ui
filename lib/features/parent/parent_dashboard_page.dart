import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/responsive.dart';
import '../../services/auth_service.dart';

import 'screens/child_attendance_screen.dart';
import 'screens/child_fees_screen.dart';
import 'screens/child_results_screen.dart';
import 'screens/child_timetable_screen.dart';
import 'screens/parent_overview_screen.dart';

class _MenuItem {
  final IconData icon;
  final String label;
  final String hint;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.hint,
  });
}

const _menuItems = [
  _MenuItem(
    icon: Icons.dashboard_outlined,
    label: 'Overview',
    hint: 'Children, alerts and quick actions',
  ),
  _MenuItem(
    icon: Icons.fact_check_outlined,
    label: 'Attendance',
    hint: 'Daily presence and trends',
  ),
  _MenuItem(
    icon: Icons.emoji_events_outlined,
    label: 'Results',
    hint: 'Marks, grades and progress',
  ),
  _MenuItem(
    icon: Icons.receipt_long_outlined,
    label: 'Fees',
    hint: 'Paid, pending and receipts',
  ),
  _MenuItem(
    icon: Icons.calendar_month_outlined,
    label: 'Timetable',
    hint: 'Today and weekly schedule',
  ),
  _MenuItem(
    icon: Icons.chat_bubble_outline_rounded,
    label: 'Chat',
    hint: 'Teacher communication',
  ),
];

class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key});

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  String? _selectedChildId;
  String? _selectedChildName;

  void _selectChild(String childId, String childName) {
    setState(() {
      _selectedChildId = childId;
      _selectedChildName = childName;
    });
  }

  Widget _buildContent() {
    return switch (_selectedIndex) {
      0 => ParentOverviewScreen(
          onSelectChild: _selectChild,
          onNavigate: (index) => setState(() => _selectedIndex = index),
        ),
      1 => ChildAttendanceScreen(
          studentId: _selectedChildId,
          studentName: _selectedChildName,
        ),
      2 => ChildResultsScreen(
          studentId: _selectedChildId,
          studentName: _selectedChildName,
        ),
      3 => ChildFeesScreen(
          studentId: _selectedChildId,
          studentName: _selectedChildName,
        ),
      4 => ChildTimetableScreen(
          studentId: _selectedChildId,
          studentName: _selectedChildName,
        ),
      5 => const _ComingSoonPanel(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final railWidth = Responsive.isDesktop(context) ? 280.0 : 232.0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.palette.canvas,
      drawer:
          isMobile ? Drawer(child: _PortalRail(onSelect: _selectTab)) : null,
      body: Row(
        children: [
          if (!isMobile)
            SizedBox(
              width: railWidth,
              child: _PortalRail(onSelect: _selectTab),
            ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  selectedIndex: _selectedIndex,
                  childName: _selectedChildName,
                  onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
                  onLogout: _logout,
                ),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
    if (Responsive.isMobile(context)) Navigator.pop(context);
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AppRouter.login);
    }
  }
}

class _TopBar extends StatelessWidget {
  final int selectedIndex;
  final String? childName;
  final VoidCallback onOpenMenu;
  final VoidCallback onLogout;

  const _TopBar({
    required this.selectedIndex,
    required this.childName,
    required this.onOpenMenu,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final item = _menuItems[selectedIndex];
    final isMobile = Responsive.isMobile(context);

    return Container(
      height: isMobile ? 74 : 78,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border(bottom: BorderSide(color: context.palette.border)),
      ),
      child: Row(
        children: [
          if (isMobile) ...[
            IconButton(
              onPressed: onOpenMenu,
              icon: const Icon(Icons.menu_rounded),
              tooltip: 'Open menu',
            ),
            const SizedBox(width: 6),
          ],
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.palette.brand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              border: Border.all(color: context.palette.border),
            ),
            child: Icon(item.icon, color: context.palette.brand, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: isMobile ? 18 : 21,
                      ),
                ),
                Text(
                  item.hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          if (childName != null && !isMobile) ...[
            _ChildChip(name: childName!),
            const SizedBox(width: 10),
          ],
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }
}

class _PortalRail extends StatelessWidget {
  final ValueChanged<int> onSelect;

  const _PortalRail({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final userName = AuthService.instance.currentUser?.fullName ?? 'Parent';

    return Container(
      color: context.palette.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: context.palette.heroGradient,
                borderRadius: BorderRadius.circular(AppSizes.radiusXL),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.family_restroom_rounded),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Parent command center',
                    style: GoogleFonts.nunitoSans(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
                itemCount: _menuItems.length,
                itemBuilder: (context, index) => _RailButton(
                  index: index,
                  onTap: () => onSelect(index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  final int index;
  final VoidCallback onTap;

  const _RailButton({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_ParentDashboardPageState>();
    final isActive = state?._selectedIndex == index;
    final item = _menuItems[index];

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isActive
            ? context.palette.brand.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              border: Border.all(
                color: isActive ? context.palette.border : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isActive ? context.palette.brand : AppColors.textLight,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      color: isActive
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (isActive)
                  Icon(Icons.chevron_right_rounded,
                      color: context.palette.brand, size: 19),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChildChip extends StatelessWidget {
  final String name;

  const _ChildChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: context.palette.canvas,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline_rounded,
              size: 16, color: context.palette.brand),
          const SizedBox(width: 6),
          Text(
            name,
            style: GoogleFonts.nunitoSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonPanel extends StatelessWidget {
  const _ComingSoonPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  color: context.palette.brand, size: 42),
              const SizedBox(height: 12),
              Text(
                'Parent chat is next',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'This space is reserved for teacher conversations and callbacks.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
