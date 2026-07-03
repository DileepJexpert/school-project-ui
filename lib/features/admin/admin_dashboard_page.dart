import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/auth_models.dart';
import '../../models/fee_models.dart';
import '../../services/admin_dashboard_api_service.dart';
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
import 'screens/homework_screen.dart';
import 'screens/video_management_screen.dart';
import 'screens/ai_config_screen.dart';
import 'screens/whatsapp_config_screen.dart';
import '../../features/chat/chat_list_screen.dart';

// --------- Menu data ---------

class _MenuItem {
  final IconData icon;
  final String label;
  final bool isLive;
  const _MenuItem(
      {required this.icon, required this.label, this.isLive = false});
}

class _MenuGroup {
  final String title;
  final List<_MenuItem> items;
  const _MenuGroup({required this.title, required this.items});
}

// Flat list used for switch / index lookup (order must match _groups expansion)
final _allItems = [
  // -- ACADEMICS --
  const _MenuItem(
      icon: Icons.dashboard_outlined, label: 'Overview', isLive: true), // 0
  const _MenuItem(
      icon: Icons.people_alt_outlined, label: 'Students', isLive: true), // 1
  const _MenuItem(
      icon: Icons.person_add_alt_1_outlined,
      label: 'Admissions',
      isLive: true), // 2
  const _MenuItem(
      icon: Icons.menu_book_outlined, label: 'Homework', isLive: true), // 3
  const _MenuItem(
      icon: Icons.video_library_outlined,
      label: 'Video Tutorials',
      isLive: true), // 4
  // -- FINANCE --
  const _MenuItem(
      icon: Icons.receipt_long_outlined, label: 'Fees', isLive: true), // 5
  const _MenuItem(
      icon: Icons.money_off_outlined, label: 'Expenses', isLive: true), // 6
  const _MenuItem(
      icon: Icons.assessment_outlined, label: 'Reports', isLive: true), // 7
  // -- SCHOOL OPERATIONS --
  const _MenuItem(
      icon: Icons.rule_folder_outlined, label: 'Attendance', isLive: true), // 8
  const _MenuItem(
      icon: Icons.table_chart_outlined, label: 'Timetable', isLive: true), // 9
  const _MenuItem(
      icon: Icons.emoji_events_outlined, label: 'Results', isLive: true), // 10
  const _MenuItem(
      icon: Icons.directions_bus_outlined,
      label: 'Transport',
      isLive: true), // 11
  const _MenuItem(
      icon: Icons.gavel_outlined, label: 'Discipline', isLive: true), // 12
  // -- COMMUNICATION --
  const _MenuItem(
      icon: Icons.notifications_active_outlined,
      label: 'Notifications',
      isLive: true), // 13
  const _MenuItem(icon: Icons.chat_outlined, label: 'Chat', isLive: true), // 14
  const _MenuItem(
      icon: Icons.chat_bubble_outlined,
      label: 'WhatsApp Agent',
      isLive: true), // 15
  // -- HR & PAYROLL --
  const _MenuItem(
      icon: Icons.badge_outlined, label: 'HR & Staff', isLive: true), // 16
  // -- ADMINISTRATION --
  const _MenuItem(
      icon: Icons.description_outlined,
      label: 'Certificates',
      isLive: true), // 17
  const _MenuItem(
      icon: Icons.smart_toy_outlined, label: 'AI Settings', isLive: true), // 18
  const _MenuItem(
      icon: Icons.settings_outlined, label: 'Settings', isLive: true), // 19
];

final _groups = [
  _MenuGroup(title: 'ACADEMICS', items: [
    _allItems[0],
    _allItems[1],
    _allItems[2],
    _allItems[3],
    _allItems[4]
  ]),
  _MenuGroup(
      title: 'FINANCE', items: [_allItems[5], _allItems[6], _allItems[7]]),
  _MenuGroup(title: 'SCHOOL OPERATIONS', items: [
    _allItems[8],
    _allItems[9],
    _allItems[10],
    _allItems[11],
    _allItems[12]
  ]),
  _MenuGroup(
      title: 'COMMUNICATION',
      items: [_allItems[13], _allItems[14], _allItems[15]]),
  _MenuGroup(title: 'HR & PAYROLL', items: [_allItems[16]]),
  _MenuGroup(
      title: 'ADMINISTRATION',
      items: [_allItems[17], _allItems[18], _allItems[19]]),
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
  static const _bottomNavToGlobal = [0, 1, 5, 2];

  Widget _buildContent() {
    // Role guard: the sidebar hides unauthorized items, but this also blocks
    // programmatic navigation from rendering screens the role can't access.
    final label = _allItems[_selectedIndex].label;
    if (!AuthService.instance.canAccessMenu(label)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('You don\'t have permission to view $label',
                style: GoogleFonts.poppins(color: Colors.grey[600])),
          ],
        ),
      );
    }
    switch (_selectedIndex) {
      case 0:
        return _OverviewContent(
          onOpenSection: (index) => setState(() => _selectedIndex = index),
        );
      case 1:
        return const StudentsScreen();
      case 2:
        return const AdmissionScreen();
      case 3:
        return const HomeworkScreen();
      case 4:
        return const VideoManagementScreen();
      case 5:
        return const FeeScreen();
      case 6:
        return const ExpenseScreen();
      case 7:
        return const ReportsScreen();
      case 8:
        return const AttendanceScreen();
      case 9:
        return const TimetableScreen();
      case 10:
        return const ResultsAdminScreen();
      case 11:
        return const TransportAdminScreen();
      case 12:
        return const DisciplineScreen();
      case 13:
        return const NotificationsScreen();
      case 14:
        return const ChatListScreen();
      case 15:
        return const WhatsAppConfigScreen();
      case 16:
        return const HrScreen();
      case 17:
        return const CertificatesScreen();
      case 18:
        return const AiConfigScreen();
      case 19:
        return const SettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isDesktop = Responsive.isDesktop(context);
    final sidebarWidth = isDesktop ? 224.0 : 196.0;

    // Find which bottom-nav slot to highlight; fall back to "More" (slot 4)
    int bottomIdx = _bottomNavToGlobal.indexOf(_selectedIndex);
    if (bottomIdx == -1) bottomIdx = 4;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.palette.canvas,
      appBar: AppBar(
        toolbarHeight: 58,
        backgroundColor: context.palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(color: context.palette.border),
        ),
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
          style: GoogleFonts.nunitoSans(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          // Full text on tablet/desktop; icon-only on mobile to save space
          if (!isMobile)
            TextButton.icon(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, AppRouter.home),
              icon: const Icon(Icons.public, color: AppColors.gold, size: 18),
              label: Text('View Website',
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            )
          else
            IconButton(
              icon: const Icon(Icons.public, color: AppColors.gold),
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
              elevation: 0,
              child: SizedBox(
                width: sidebarWidth,
                child: ColoredBox(
                  color: context.palette.surface,
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
    final userRole =
        user != null ? UserRole.displayName(user.role) : 'Dashboard';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // -- Sidebar header
        Container(
          padding: EdgeInsets.fromLTRB(
              16, Responsive.isMobile(context) ? 42 : 18, 16, 16),
          decoration: BoxDecoration(
            color: context.palette.surface,
            border: Border(bottom: BorderSide(color: context.palette.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.palette.brand,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName,
                          style: GoogleFonts.nunitoSans(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(userRole,
                          style: GoogleFonts.nunitoSans(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 4),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 3),
      child: Text(
        title,
        style: GoogleFonts.nunitoSans(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textLight,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuItem(_MenuItem item, int index) {
    final isActive = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedIndex = index);
          // Close the drawer when a section is selected -- only on mobile
          if (Responsive.isMobile(context)) Navigator.pop(context);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: isActive
                ? context.palette.brand.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Icon(item.icon,
                  size: 18,
                  color: isActive ? AppColors.navy : AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item.label,
                    style: GoogleFonts.nunitoSans(
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color:
                          isActive ? AppColors.navy : AppColors.textSecondary,
                      fontSize: 12.5,
                    )),
              ),
              if (item.isLive)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.gold : AppColors.success,
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

class _OverviewContent extends StatefulWidget {
  final ValueChanged<int> onOpenSection;

  const _OverviewContent({required this.onOpenSection});

  @override
  State<_OverviewContent> createState() => _OverviewContentState();
}

class _OverviewContentState extends State<_OverviewContent> {
  bool _loading = true;
  AdminDashboardData? _dashboard;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final dashboard = await AdminDashboardApiService.getDashboard();
      if (mounted) {
        setState(() => _dashboard = dashboard);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dashboard: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _formatNumber(int n) {
    if (n >= 10000000) return '${(n / 10000000).toStringAsFixed(1)}Cr';
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) {
      final s = n.toString();
      final buf = StringBuffer();
      for (int i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
        buf.write(s[i]);
      }
      return buf.toString();
    }
    return n.toString();
  }

  String _formatRevenue(double amount) {
    if (amount >= 10000000) {
      return 'Rs ${(amount / 10000000).toStringAsFixed(1)}Cr';
    }
    if (amount >= 100000) {
      return 'Rs ${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return 'Rs ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return 'Rs ${amount.toStringAsFixed(0)}';
  }

  double get _collectionRate {
    final summary = _dashboard?.schoolSummary;
    if (summary == null) return 0;
    final total = summary.totalFeesCollected + summary.totalFeesDue;
    if (total <= 0) return 0;
    return (summary.totalFeesCollected / total) * 100;
  }

  List<_DashboardAction> _buildActionQueue() {
    final queue = _dashboard?.actionQueue ?? [];
    if (queue.isEmpty) {
      return [
        _DashboardAction(
          icon: Icons.check_circle_outline_rounded,
          title: 'School operations look stable',
          subtitle: 'No urgent dashboard action is visible right now.',
          color: AppColors.success,
          sectionIndex: 7,
        )
      ];
    }
    return queue.map((item) {
      return _DashboardAction(
        icon: _iconForRouteHint(item.routeHint),
        title: item.title,
        subtitle: item.subtitle,
        color: _colorForSeverity(item.severity),
        sectionIndex: _sectionForRouteHint(item.routeHint),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final firstName =
        AuthService.instance.currentUser?.fullName.split(' ').first ?? 'Admin';
    final dashboard = _dashboard;
    final summary = dashboard?.schoolSummary;
    final staffDashboard = dashboard?.staffDashboard ?? {};
    final totalStudents = summary?.totalStudents ?? 0;
    final totalStaff = (staffDashboard['totalStaff'] as num?)?.toInt() ?? 0;
    final activeStaff = (staffDashboard['activeStaff'] as num?)?.toInt() ?? 0;
    final pendingLeaves =
        (staffDashboard['pendingLeaveRequests'] as num?)?.toInt() ?? 0;
    final onLeaveToday = (staffDashboard['onLeaveToday'] as num?)?.toInt() ?? 0;
    final revenue = summary?.totalFeesCollected ?? 0.0;
    final totalDue = summary?.totalFeesDue ?? 0.0;
    final monthlyCollections = summary?.monthlyCollections ?? [];
    final topDues = dashboard?.topDueStudents ?? [];
    final classEntries = (summary?.enrollmentByClass.entries.toList() ??
        <MapEntry<String, int>>[])
      ..sort((a, b) => a.key.compareTo(b.key));

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Welcome Back, $firstName',
            subtitle:
                'Today\'s school pulse, decisions and money movement in one place.',
            icon: Icons.dashboard_customize_outlined,
            actions: [
              OutlinedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = Responsive.gridColumns(context);
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _metricTile(
                            context,
                            'Students',
                            _formatNumber(totalStudents),
                            'Across ${classEntries.length} active classes',
                            Icons.people_alt_rounded,
                            AppColors.navy,
                            constraints.maxWidth,
                            columns),
                        _metricTile(
                            context,
                            'Staff On Duty',
                            '$activeStaff/$totalStaff',
                            '$onLeaveToday on leave today',
                            Icons.badge_rounded,
                            const Color(0xFF0D9488),
                            constraints.maxWidth,
                            columns),
                        _metricTile(
                            context,
                            'Pending Leaves',
                            '$pendingLeaves',
                            pendingLeaves == 0
                                ? 'No approvals waiting'
                                : 'Needs admin review',
                            Icons.event_busy_rounded,
                            AppColors.gold,
                            constraints.maxWidth,
                            columns),
                        _metricTile(
                            context,
                            'Collection Rate',
                            '${_collectionRate.toStringAsFixed(0)}%',
                            '${_formatRevenue(revenue)} collected',
                            Icons.trending_up_rounded,
                            const Color(0xFFDB2777),
                            constraints.maxWidth,
                            columns),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildHeroCommandCenter(
                  actions: _buildActionQueue(),
                  revenue: revenue,
                  totalDue: totalDue,
                  monthlyCollections: monthlyCollections,
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumn = constraints.maxWidth >= 980;
                    final cardWidth =
                        twoColumn ? (constraints.maxWidth - 14) / 2 : null;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: cardWidth ?? constraints.maxWidth,
                          child: _buildClassHealthCard(classEntries),
                        ),
                        SizedBox(
                          width: cardWidth ?? constraints.maxWidth,
                          child:
                              _buildDuesAttentionCard(topDues.take(5).toList()),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final threeColumn = constraints.maxWidth >= 1120;
                    final twoColumn = constraints.maxWidth >= 760;
                    final columns = threeColumn
                        ? 3
                        : twoColumn
                            ? 2
                            : 1;
                    final width =
                        (constraints.maxWidth - ((columns - 1) * 14)) / columns;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: width,
                          child: _buildAttendanceStatusCard(
                              dashboard?.attendancePulse),
                        ),
                        SizedBox(
                          width: width,
                          child: _buildAcademicAdmissionCard(
                            dashboard?.academicPulse,
                            dashboard?.admissionPulse,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _buildOperationsCard(
                            dashboard?.disciplinePulse,
                            dashboard?.communicationPulse,
                            dashboard?.transportPulse,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildRoleFocusCard(),
                const SizedBox(height: 16),
                _buildQuickActions(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeroCommandCenter({
    required List<_DashboardAction> actions,
    required double revenue,
    required double totalDue,
    required List<MonthlyFeeSummary> monthlyCollections,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: context.palette.heroGradient,
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            boxShadow: const [
              BoxShadow(
                color: Color(0x180F172A),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildActionQueueCard(actions)),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 5,
                      child: _buildFinanceSnapshot(
                        revenue: revenue,
                        totalDue: totalDue,
                        monthlyCollections: monthlyCollections,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildActionQueueCard(actions),
                    const SizedBox(height: 14),
                    _buildFinanceSnapshot(
                      revenue: revenue,
                      totalDue: totalDue,
                      monthlyCollections: monthlyCollections,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildActionQueueCard(List<_DashboardAction> actions) {
    return _glassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(
          'Principal Action Queue',
          'Rule-based priorities from live school data',
          Icons.bolt_outlined,
          Colors.white,
        ),
        const SizedBox(height: 12),
        ...actions.map((action) => _actionRow(action)),
      ]),
    );
  }

  Widget _buildFinanceSnapshot({
    required double revenue,
    required double totalDue,
    required List<MonthlyFeeSummary> monthlyCollections,
  }) {
    final maxAmount = monthlyCollections.fold<double>(
      0,
      (max, item) => item.amount > max ? item.amount : max,
    );
    final recent = monthlyCollections.length > 6
        ? monthlyCollections.sublist(monthlyCollections.length - 6)
        : monthlyCollections;

    return _glassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(
          'Finance Snapshot',
          'Collection movement and pending exposure',
          Icons.account_balance_wallet_outlined,
          Colors.white,
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _financeStat(
              'Collected',
              _formatRevenue(revenue),
              AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _financeStat(
              'Outstanding',
              _formatRevenue(totalDue),
              AppColors.warning,
            ),
          ),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 76,
          child: recent.isEmpty
              ? Center(
                  child: Text(
                    'No monthly collection data yet',
                    style: GoogleFonts.nunitoSans(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: recent.map((item) {
                    final ratio =
                        maxAmount <= 0 ? 0.0 : item.amount / maxAmount;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: ratio.clamp(0.08, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.label.split(' ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunitoSans(
                                color: Colors.white.withValues(alpha: 0.74),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ]),
    );
  }

  Widget _buildClassHealthCard(List<MapEntry<String, int>> classEntries) {
    final maxCount = classEntries.fold<int>(
      0,
      (max, item) => item.value > max ? item.value : max,
    );
    return _dashboardCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(
          'Class Health',
          'Enrollment spread by class',
          Icons.bar_chart_rounded,
          AppColors.navy,
        ),
        const SizedBox(height: 14),
        if (classEntries.isEmpty)
          _emptyState('No enrollment data yet.')
        else
          ...classEntries.take(8).map((entry) {
            final ratio = maxCount == 0 ? 0.0 : entry.value / maxCount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                  width: 78,
                  child: Text(
                    entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.04, 1.0),
                      minHeight: 9,
                      backgroundColor: context.palette.canvas,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(context.palette.brand),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${entry.value}',
                  style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ]),
            );
          }),
      ]),
    );
  }

  Widget _buildDuesAttentionCard(List<DashboardDueStudent> dues) {
    return _dashboardCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(
          'Dues Attention',
          'Highest pending student balances',
          Icons.report_problem_outlined,
          AppColors.navy,
        ),
        const SizedBox(height: 10),
        if (dues.isEmpty)
          _emptyState('No outstanding dues found.')
        else
          ...dues.map((student) => _dueRow(student)),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => widget.onOpenSection(5),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Open Fees'),
          ),
        ),
      ]),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _DashboardAction(
        icon: Icons.person_add_alt_1_rounded,
        title: 'New Admission',
        subtitle: 'Add or continue admission',
        color: context.palette.brand,
        sectionIndex: 2,
      ),
      _DashboardAction(
        icon: Icons.receipt_long_rounded,
        title: 'Collect Fee',
        subtitle: 'Open finance counter',
        color: const Color(0xFFDB2777),
        sectionIndex: 5,
      ),
      _DashboardAction(
        icon: Icons.fact_check_outlined,
        title: 'Mark Attendance',
        subtitle: 'Daily class attendance',
        color: const Color(0xFF0D9488),
        sectionIndex: 8,
      ),
      _DashboardAction(
        icon: Icons.campaign_outlined,
        title: 'Send Notice',
        subtitle: 'Parent communication',
        color: AppColors.gold,
        sectionIndex: 13,
      ),
    ];
    return _dashboardCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(
          'Quick Actions',
          'Common admin work without hunting through menus',
          Icons.flash_on_outlined,
          AppColors.navy,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth > 900
              ? 4
              : constraints.maxWidth > 560
                  ? 2
                  : 1;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: actions.map((action) {
              return SizedBox(
                width: (constraints.maxWidth - ((columns - 1) * 10)) / columns,
                child: _quickAction(action),
              );
            }).toList(),
          );
        }),
      ]),
    );
  }

  Widget _buildAttendanceStatusCard(AttendancePulse? pulse) {
    final marked = pulse?.markedClasses ?? 0;
    final total = pulse?.totalClasses ?? 0;
    final unmarked = pulse?.unmarkedClassNames ?? [];
    final ratio = total == 0 ? 0.0 : marked / total;
    return _dashboardCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(
          'Attendance Status',
          'Today class marking progress',
          Icons.fact_check_outlined,
          AppColors.navy,
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _plainStat(
              'Marked',
              '$marked/$total',
              AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _plainStat(
              'Absent',
              '${pulse?.absent ?? 0}',
              AppColors.error,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 9,
            backgroundColor: context.palette.canvas,
            valueColor: AlwaysStoppedAnimation<Color>(
              unmarked.isEmpty ? AppColors.success : AppColors.warning,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (unmarked.isEmpty)
          _softNote(
              'All visible classes are marked for today.', AppColors.success)
        else
          _softNote(
              'Pending: ${unmarked.take(4).join(', ')}', AppColors.warning),
      ]),
    );
  }

  Widget _buildAcademicAdmissionCard(
      AcademicPulse? academic, AdmissionPulse? admission) {
    return _dashboardCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(
          'Academic & Admission',
          'Results, risk and pipeline',
          Icons.school_outlined,
          AppColors.navy,
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _plainStat(
              'At Risk',
              '${academic?.atRiskStudents ?? 0}',
              AppColors.error,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _plainStat(
              'Enquiries',
              '${admission?.enquiries ?? 0}',
              context.palette.brand,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _miniLine(
          Icons.publish_outlined,
          '${academic?.unpublishedResultRecords ?? 0} unpublished result records',
          AppColors.gold,
        ),
        _miniLine(
          Icons.person_add_alt_1_outlined,
          '${admission?.todayAdmissions ?? 0} admissions today, ${admission?.followUpsNeeded ?? 0} follow-ups',
          const Color(0xFF0D9488),
        ),
        if ((academic?.weakClasses ?? []).isNotEmpty)
          _miniLine(
            Icons.warning_amber_outlined,
            'Weak class: ${academic!.weakClasses.first.className} (${academic.weakClasses.first.averagePercentage.toStringAsFixed(1)}%)',
            AppColors.error,
          ),
      ]),
    );
  }

  Widget _buildOperationsCard(
    DisciplinePulse? discipline,
    CommunicationPulse? communication,
    TransportPulse? transport,
  ) {
    return _dashboardCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(
          'Operations Alerts',
          'Discipline, transport and notices',
          Icons.crisis_alert_outlined,
          AppColors.navy,
        ),
        const SizedBox(height: 14),
        _miniLine(
          Icons.gavel_outlined,
          '${discipline?.openIncidents ?? 0} open incidents, ${discipline?.criticalIncidents ?? 0} critical',
          (discipline?.criticalIncidents ?? 0) > 0
              ? AppColors.error
              : AppColors.gold,
        ),
        _miniLine(
          Icons.campaign_outlined,
          '${communication?.unreadNotifications ?? 0} unread notices, ${communication?.highPriorityNotifications ?? 0} high priority',
          AppColors.gold,
        ),
        _miniLine(
          Icons.directions_bus_outlined,
          '${transport?.activeBuses ?? 0}/${transport?.totalBuses ?? 0} buses active, ${transport?.maintenanceBuses ?? 0} maintenance',
          const Color(0xFF0D9488),
        ),
        _miniLine(
          Icons.route_outlined,
          '${transport?.assignedStudents ?? 0} students assigned to transport',
          context.palette.brand,
        ),
      ]),
    );
  }

  Widget _buildRoleFocusCard() {
    final role = AuthService.instance.currentUser?.role ?? '';
    final items = switch (role) {
      'ACCOUNTANT' => [
          _DashboardAction(
              icon: Icons.receipt_long_rounded,
              title: 'Collect fees',
              subtitle: 'Prioritize dues and receipt flow',
              color: const Color(0xFFDB2777),
              sectionIndex: 5),
          _DashboardAction(
              icon: Icons.assessment_outlined,
              title: 'Finance reports',
              subtitle: 'Review collection and expenses',
              color: AppColors.gold,
              sectionIndex: 7),
        ],
      'TEACHER' => [
          _DashboardAction(
              icon: Icons.fact_check_outlined,
              title: 'Mark attendance',
              subtitle: 'Complete today class status',
              color: const Color(0xFF0D9488),
              sectionIndex: 8),
          _DashboardAction(
              icon: Icons.emoji_events_outlined,
              title: 'Enter results',
              subtitle: 'Review unpublished marks',
              color: AppColors.gold,
              sectionIndex: 10),
        ],
      _ => [
          _DashboardAction(
              icon: Icons.bolt_outlined,
              title: 'Review action queue',
              subtitle: 'Start with highest severity items',
              color: context.palette.brand,
              sectionIndex: 0),
          _DashboardAction(
              icon: Icons.people_alt_outlined,
              title: 'School pulse',
              subtitle: 'Students, attendance and staff',
              color: const Color(0xFF0D9488),
              sectionIndex: 1),
        ],
    };

    return _dashboardCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(
          'Role Focus',
          'Dashboard priorities adjust by logged-in role',
          Icons.manage_accounts_outlined,
          AppColors.navy,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth > 620 ? 2 : 1;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items
                .map(
                  (item) => SizedBox(
                    width:
                        (constraints.maxWidth - ((columns - 1) * 10)) / columns,
                    child: _quickAction(item),
                  ),
                )
                .toList(),
          );
        }),
      ]),
    );
  }

  Widget _actionRow(_DashboardAction action) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        onTap: () => widget.onOpenSection(action.sectionIndex),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(children: [
            _iconBubble(action.icon, action.color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    style: GoogleFonts.nunitoSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.subtitle,
                    style: GoogleFonts.nunitoSans(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white70, size: 20),
          ]),
        ),
      ),
    );
  }

  Widget _quickAction(_DashboardAction action) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusMD),
      onTap: () => widget.onOpenSection(action.sectionIndex),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: action.color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          border: Border.all(color: action.color.withValues(alpha: 0.18)),
        ),
        child: Row(children: [
          _iconBubble(action.icon, action.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  action.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _dueRow(DashboardDueStudent student) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.error.withValues(alpha: 0.08),
          child: Text(
            student.name.isEmpty ? '?' : student.name[0].toUpperCase(),
            style: GoogleFonts.nunitoSans(
              color: AppColors.error,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              student.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunitoSans(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${student.className} - Roll ${student.rollNumber}',
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ]),
        ),
        Text(
          _formatRevenue(student.dueFees),
          style: GoogleFonts.nunitoSans(
            color: AppColors.error,
            fontWeight: FontWeight.w900,
          ),
        ),
      ]),
    );
  }

  Widget _financeStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          label,
          style: GoogleFonts.nunitoSans(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.nunitoSans(
            color:
                color == AppColors.warning ? AppColors.goldLight : Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ]),
    );
  }

  Widget _plainStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          label,
          style: GoogleFonts.nunitoSans(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.nunitoSans(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ]),
    );
  }

  Widget _miniLine(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _softNote(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunitoSans(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  int _sectionForRouteHint(String routeHint) {
    return switch (routeHint) {
      'students' => 1,
      'admissions' => 2,
      'fees' => 5,
      'expenses' => 6,
      'reports' => 7,
      'attendance' => 8,
      'results' => 10,
      'transport' => 11,
      'discipline' => 12,
      'notifications' => 13,
      'hr' => 15,
      _ => 0,
    };
  }

  IconData _iconForRouteHint(String routeHint) {
    return switch (routeHint) {
      'students' => Icons.people_alt_outlined,
      'admissions' => Icons.person_add_alt_1_outlined,
      'fees' => Icons.receipt_long_outlined,
      'expenses' => Icons.money_off_outlined,
      'reports' => Icons.assessment_outlined,
      'attendance' => Icons.fact_check_outlined,
      'results' => Icons.emoji_events_outlined,
      'transport' => Icons.directions_bus_outlined,
      'discipline' => Icons.gavel_outlined,
      'notifications' => Icons.campaign_outlined,
      'hr' => Icons.badge_outlined,
      _ => Icons.bolt_outlined,
    };
  }

  Color _colorForSeverity(String severity) {
    return switch (severity.toUpperCase()) {
      'HIGH' => AppColors.error,
      'MEDIUM' => AppColors.gold,
      _ => AppColors.success,
    };
  }

  Widget _sectionHeader(
      String title, String subtitle, IconData icon, Color foreground) {
    final onDark = foreground == Colors.white;
    return Row(children: [
      Icon(icon, color: foreground, size: 20),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            title,
            style: GoogleFonts.nunitoSans(
              color: foreground,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.nunitoSans(
              color: onDark
                  ? Colors.white.withValues(alpha: 0.68)
                  : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _dashboardCard({required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: child,
    );
  }

  Widget _iconBubble(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }

  Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.canvas,
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        border: Border.all(color: context.palette.border),
      ),
      child: Text(
        message,
        style: GoogleFonts.nunitoSans(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _metricTile(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    double maxWidth,
    int columns,
  ) {
    return SizedBox(
      width: (maxWidth - (columns - 1) * 12) / columns,
      child: AdminMetricCard(
        title: title,
        value: value,
        caption: subtitle,
        icon: icon,
        color: color,
      ),
    );
  }
}

class _DashboardAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final int sectionIndex;

  const _DashboardAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.sectionIndex,
  });
}
