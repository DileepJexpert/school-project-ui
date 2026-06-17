import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/responsive.dart';
import '../../models/auth_models.dart';
import '../../services/auth_service.dart';
import '../../services/fee_api_service.dart';
import '../../services/staff_api_service.dart';
import '../../models/fee_models.dart';

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
import 'screens/website_editor_screen.dart';
import 'screens/event_management_screen.dart';
import 'screens/library_screen.dart';
import 'screens/exam_schedule_screen.dart';
import 'screens/bulk_message_screen.dart';
import 'screens/asset_management_screen.dart';
import 'screens/study_material_screen.dart';
import 'screens/quiz_management_screen.dart';
import 'screens/daily_diary_screen.dart';
import 'screens/visitor_management_screen.dart';
import 'screens/health_record_screen.dart';
import 'screens/complaint_screen.dart';
import 'screens/attendance_analytics_screen.dart';
import 'screens/notice_board_screen.dart';
import 'screens/awards_screen.dart';
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
  const _MenuItem(icon: Icons.menu_book_outlined,        label: 'Homework',       isLive: true),  // 3
  const _MenuItem(icon: Icons.video_library_outlined,   label: 'Video Tutorials', isLive: true),  // 4
  // -- FINANCE --
  const _MenuItem(icon: Icons.receipt_long_outlined,     label: 'Fees',           isLive: true),  // 5
  const _MenuItem(icon: Icons.money_off_outlined,        label: 'Expenses',       isLive: true),  // 6
  const _MenuItem(icon: Icons.assessment_outlined,       label: 'Reports',        isLive: true),  // 7
  // -- SCHOOL OPERATIONS --
  const _MenuItem(icon: Icons.rule_folder_outlined,      label: 'Attendance',     isLive: true),  // 8
  const _MenuItem(icon: Icons.table_chart_outlined,      label: 'Timetable',      isLive: true),  // 9
  const _MenuItem(icon: Icons.emoji_events_outlined,     label: 'Results',        isLive: true),  // 10
  const _MenuItem(icon: Icons.directions_bus_outlined,   label: 'Transport',      isLive: true),  // 11
  const _MenuItem(icon: Icons.gavel_outlined,            label: 'Discipline',     isLive: true),  // 12
  // -- COMMUNICATION --
  const _MenuItem(icon: Icons.notifications_active_outlined, label: 'Notifications', isLive: true), // 13
  const _MenuItem(icon: Icons.chat_outlined,             label: 'Chat',           isLive: true),  // 14
  const _MenuItem(icon: Icons.chat_bubble_outlined,      label: 'WhatsApp Agent', isLive: true),  // 15
  // -- HR & PAYROLL --
  const _MenuItem(icon: Icons.badge_outlined,            label: 'HR & Staff',     isLive: true),  // 16
  // -- ADMINISTRATION --
  const _MenuItem(icon: Icons.description_outlined,      label: 'Certificates',   isLive: true),  // 17
  const _MenuItem(icon: Icons.language_outlined,         label: 'Website',        isLive: true),  // 18
  const _MenuItem(icon: Icons.smart_toy_outlined,        label: 'AI Settings',    isLive: true),  // 19
  const _MenuItem(icon: Icons.settings_outlined,         label: 'Settings',       isLive: true),  // 20
  // -- SCHOOL OPERATIONS (appended) --
  const _MenuItem(icon: Icons.event_outlined,            label: 'Events',         isLive: true),  // 21
  const _MenuItem(icon: Icons.local_library_outlined,    label: 'Library',        isLive: true),  // 22
  const _MenuItem(icon: Icons.quiz_outlined,             label: 'Exam Schedule',  isLive: true),  // 23
  const _MenuItem(icon: Icons.campaign_outlined,         label: 'Bulk Messages', isLive: true),  // 24
  const _MenuItem(icon: Icons.inventory_2_outlined,      label: 'Assets',        isLive: true),  // 25
  const _MenuItem(icon: Icons.library_books_outlined,    label: 'Study Materials', isLive: true), // 26
  const _MenuItem(icon: Icons.quiz_outlined,             label: 'Quiz Manager',  isLive: true),  // 27
  const _MenuItem(icon: Icons.auto_stories_outlined,     label: 'Daily Diary',   isLive: true),  // 28
  const _MenuItem(icon: Icons.person_pin_outlined,       label: 'Visitors',      isLive: true),  // 29
  const _MenuItem(icon: Icons.health_and_safety_outlined, label: 'Health Records', isLive: true), // 30
  const _MenuItem(icon: Icons.feedback_outlined,          label: 'Complaints',    isLive: true),  // 31
  const _MenuItem(icon: Icons.analytics_outlined,         label: 'Attendance Analytics', isLive: true), // 32
  const _MenuItem(icon: Icons.campaign_outlined,          label: 'Notice Board', isLive: true),  // 33
  const _MenuItem(icon: Icons.emoji_events_outlined,      label: 'Awards',       isLive: true),  // 34
];

final _groups = [
  _MenuGroup(title: 'ACADEMICS',         items: [_allItems[0], _allItems[1], _allItems[2], _allItems[3], _allItems[4], _allItems[23], _allItems[26], _allItems[27], _allItems[28], _allItems[34]]),
  _MenuGroup(title: 'FINANCE',           items: [_allItems[5], _allItems[6], _allItems[7]]),
  _MenuGroup(title: 'SCHOOL OPERATIONS', items: [_allItems[8], _allItems[9], _allItems[10], _allItems[11], _allItems[12], _allItems[21], _allItems[22], _allItems[30], _allItems[32]]),
  _MenuGroup(title: 'COMMUNICATION',     items: [_allItems[13], _allItems[14], _allItems[15], _allItems[24], _allItems[31], _allItems[33]]),
  _MenuGroup(title: 'HR & PAYROLL',      items: [_allItems[16]]),
  _MenuGroup(title: 'ADMINISTRATION',    items: [_allItems[17], _allItems[18], _allItems[19], _allItems[20], _allItems[25], _allItems[29]]),
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
      case 0:  return const _OverviewContent();
      case 1:  return const StudentsScreen();
      case 2:  return const AdmissionScreen();
      case 3:  return const HomeworkScreen();
      case 4:  return const VideoManagementScreen();
      case 5:  return const FeeScreen();
      case 6:  return const ExpenseScreen();
      case 7:  return const ReportsScreen();
      case 8:  return const AttendanceScreen();
      case 9:  return const TimetableScreen();
      case 10: return const ResultsAdminScreen();
      case 11: return const TransportAdminScreen();
      case 12: return const DisciplineScreen();
      case 13: return const NotificationsScreen();
      case 14: return const ChatListScreen();
      case 15: return const WhatsAppConfigScreen();
      case 16: return const HrScreen();
      case 17: return const CertificatesScreen();
      case 18: return const WebsiteEditorScreen();
      case 19: return const AiConfigScreen();
      case 20: return const SettingsScreen();
      case 21: return const EventManagementScreen();
      case 22: return const LibraryScreen();
      case 23: return const ExamScheduleScreen();
      case 24: return const BulkMessageScreen();
      case 25: return const AssetManagementScreen();
      case 26: return const StudyMaterialScreen();
      case 27: return const QuizManagementScreen();
      case 28: return const DailyDiaryScreen();
      case 29: return const VisitorManagementScreen();
      case 30: return const HealthRecordScreen();
      case 31: return const ComplaintScreen();
      case 32: return const AttendanceAnalyticsScreen();
      case 33: return const NoticeBoardScreen();
      case 34: return const AwardsScreen();
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
    final groupWidgets = <Widget>[];

    for (final group in _groups) {
      // Collect visible items in this group
      final visibleItems = <_MenuItem>[];
      final visibleIndices = <int>[];
      for (final item in group.items) {
        if (auth.canAccessMenu(item.label)) {
          visibleItems.add(item);
          visibleIndices.add(_allItems.indexOf(item));
        }
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

class _OverviewContent extends StatefulWidget {
  const _OverviewContent();

  @override
  State<_OverviewContent> createState() => _OverviewContentState();
}

class _OverviewContentState extends State<_OverviewContent> {
  bool _loading = true;
  SchoolSummary? _schoolSummary;
  Map<String, dynamic>? _staffDashboard;
  Map<String, dynamic>? _analytics;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _schoolSummary = await FeeApiService.getSchoolSummary();
    } catch (_) {}
    try {
      _staffDashboard = await StaffApiService.getStaffDashboard();
    } catch (_) {}
    try {
      _analytics = await FeeApiService.getDashboardAnalytics();
    } catch (_) {}
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
    if (amount >= 10000000) return 'Rs ${(amount / 10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000) return 'Rs ${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return 'Rs ${(amount / 1000).toStringAsFixed(1)}K';
    return 'Rs ${amount.toStringAsFixed(0)}';
  }

  double _attendancePercent() {
    final present = (_analytics?['todayPresent'] as num?)?.toDouble() ?? 0;
    final total = (_analytics?['todayTotal'] as num?)?.toDouble() ?? 0;
    if (total == 0) return 0;
    return (present / total) * 100;
  }

  double _feeCollectionRate() {
    final collected = _schoolSummary?.totalFeesCollected ?? 0.0;
    final due = _schoolSummary?.totalFeesDue ?? 0.0;
    final total = collected + due;
    if (total == 0) return 0;
    return (collected / total) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final totalStudents = _schoolSummary?.totalStudents ?? 0;
    final totalStaff = (_staffDashboard?['totalStaff'] as num?)?.toInt() ?? 0;
    final pendingLeaves =
        (_staffDashboard?['pendingLeaveRequests'] as num?)?.toInt() ?? 0;
    final revenue = _schoolSummary?.totalFeesCollected ?? 0.0;

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
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            // ── KPI Cards ──────────────────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = Responsive.gridColumns(context);
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _statCard(context, 'Total Students',
                        _formatNumber(totalStudents),
                        Icons.people_alt_rounded, AppColors.navy,
                        constraints.maxWidth, columns),
                    _statCard(context, 'Total Staff',
                        _formatNumber(totalStaff),
                        Icons.badge_rounded, const Color(0xFF0D9488),
                        constraints.maxWidth, columns),
                    _statCard(context, 'Pending Leaves',
                        '$pendingLeaves',
                        Icons.event_busy_rounded, AppColors.gold,
                        constraints.maxWidth, columns),
                    _statCard(context, 'Revenue (Total)',
                        _formatRevenue(revenue),
                        Icons.monetization_on_rounded, const Color(0xFFDB2777),
                        constraints.maxWidth, columns),
                    _statCard(context, "Today's Attendance",
                        '${_attendancePercent().toStringAsFixed(1)}%',
                        Icons.check_circle_rounded, AppColors.success,
                        constraints.maxWidth, columns),
                    _statCard(context, 'Fee Collection Rate',
                        '${_feeCollectionRate().toStringAsFixed(1)}%',
                        Icons.trending_up_rounded, AppColors.info,
                        constraints.maxWidth, columns),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            // ── Charts Section ─────────────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = Responsive.isDesktop(context) ||
                    Responsive.isTablet(context);
                if (isWide) {
                  return Column(
                    children: [
                      // Row 1: Monthly Fee Collection + Class-wise Enrollment
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildMonthlyFeeChart()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildClassEnrollmentChart()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Row 2: Today's Attendance + Weekly Attendance
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTodayAttendancePie()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildWeeklyAttendanceChart()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Row 3: Gender Distribution + New Admissions
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildGenderDistributionPie()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildNewAdmissionsCard()),
                        ],
                      ),
                    ],
                  );
                }
                // Mobile: single column
                return Column(
                  children: [
                    _buildMonthlyFeeChart(),
                    const SizedBox(height: 16),
                    _buildClassEnrollmentChart(),
                    const SizedBox(height: 16),
                    _buildTodayAttendancePie(),
                    const SizedBox(height: 16),
                    _buildWeeklyAttendanceChart(),
                    const SizedBox(height: 16),
                    _buildGenderDistributionPie(),
                    const SizedBox(height: 16),
                    _buildNewAdmissionsCard(),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ── Chart Card wrapper ───────────────────────────────────────────────────
  Widget _chartCard({required String title, required Widget child}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  // ── Chart A: Monthly Fee Collection (Line Chart) ────────────────────────
  Widget _buildMonthlyFeeChart() {
    final collections = _schoolSummary?.monthlyCollections;
    if (collections == null || collections.isEmpty) {
      return _chartCard(
        title: 'Monthly Fee Collection',
        child: const SizedBox(
          height: 250,
          child: Center(child: Text('No data')),
        ),
      );
    }

    final maxY = collections.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
    final yInterval = maxY > 0 ? (maxY / 4).ceilToDouble() : 1.0;

    return _chartCard(
      title: 'Monthly Fee Collection',
      child: SizedBox(
        height: 250,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yInterval,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppColors.border.withOpacity(0.5),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 50,
                  getTitlesWidget: (value, meta) {
                    String label;
                    if (value >= 100000) {
                      label = '${(value / 100000).toStringAsFixed(1)}L';
                    } else if (value >= 1000) {
                      label = '${(value / 1000).toStringAsFixed(0)}K';
                    } else {
                      label = value.toStringAsFixed(0);
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(label,
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: AppColors.textSecondary)),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= collections.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        collections[idx].label.length > 3
                            ? collections[idx].label.substring(0, 3)
                            : collections[idx].label,
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: (collections.length - 1).toDouble(),
            minY: 0,
            maxY: maxY * 1.15,
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(
                  collections.length,
                  (i) => FlSpot(i.toDouble(), collections[i].amount),
                ),
                isCurved: true,
                color: AppColors.navy,
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.navy,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.navy.withOpacity(0.25),
                      AppColors.navy.withOpacity(0.02),
                    ],
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    return LineTooltipItem(
                      _formatRevenue(spot.y),
                      GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Chart B: Class-wise Enrollment (Horizontal Bar) ─────────────────────
  Widget _buildClassEnrollmentChart() {
    final enrollment = _schoolSummary?.enrollmentByClass;
    if (enrollment == null || enrollment.isEmpty) {
      return _chartCard(
        title: 'Class-wise Enrollment',
        child: const SizedBox(
          height: 250,
          child: Center(child: Text('No data')),
        ),
      );
    }

    final entries = enrollment.entries.toList();
    final maxVal =
        entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return _chartCard(
      title: 'Class-wise Enrollment',
      child: SizedBox(
        height: (entries.length * 32.0).clamp(150, 400),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal * 1.2,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${entries[group.x.toInt()].key}: ${rod.toY.toInt()}',
                    GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 80,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= entries.length) {
                      return const SizedBox.shrink();
                    }
                    String label = entries[idx].key;
                    if (label.length > 10) {
                      label = '${label.substring(0, 10)}..';
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(label,
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis),
                    );
                  },
                ),
              ),
              bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawHorizontalLine: false,
              drawVerticalLine: true,
              getDrawingVerticalLine: (value) => FlLine(
                color: AppColors.border.withOpacity(0.5),
                strokeWidth: 1,
              ),
            ),
            barGroups: List.generate(entries.length, (i) {
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: entries[i].value.toDouble(),
                    color: AppColors.gold,
                    width: 18,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Chart C: Today's Attendance (Donut/Pie) ─────────────────────────────
  Widget _buildTodayAttendancePie() {
    if (_analytics == null) {
      return _chartCard(
        title: "Today's Attendance",
        child: const SizedBox(
          height: 200,
          child: Center(child: Text('No data')),
        ),
      );
    }

    final present = (_analytics!['todayPresent'] as num?)?.toDouble() ?? 0;
    final absent = (_analytics!['todayAbsent'] as num?)?.toDouble() ?? 0;
    final late = (_analytics!['todayLate'] as num?)?.toDouble() ?? 0;
    final halfDay = (_analytics!['todayHalfDay'] as num?)?.toDouble() ?? 0;
    final total = present + absent + late + halfDay;

    if (total == 0) {
      return _chartCard(
        title: "Today's Attendance",
        child: const SizedBox(
          height: 200,
          child: Center(child: Text('No data')),
        ),
      );
    }

    final percent = (present / total * 100).toStringAsFixed(1);

    return _chartCard(
      title: "Today's Attendance",
      child: SizedBox(
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: present,
                    title: '${present.toInt()}',
                    color: AppColors.success,
                    radius: 45,
                    titleStyle: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: absent,
                    title: '${absent.toInt()}',
                    color: AppColors.error,
                    radius: 45,
                    titleStyle: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: late,
                    title: '${late.toInt()}',
                    color: AppColors.warning,
                    radius: 45,
                    titleStyle: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: halfDay,
                    title: '${halfDay.toInt()}',
                    color: AppColors.info,
                    radius: 45,
                    titleStyle: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$percent%',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy)),
                Text('Present',
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Chart D: Weekly Attendance Trend (Grouped Bar) ──────────────────────
  Widget _buildWeeklyAttendanceChart() {
    final weekly = _analytics?['weeklyAttendance'] as List?;
    if (weekly == null || weekly.isEmpty) {
      return _chartCard(
        title: 'Weekly Attendance Trend',
        child: const SizedBox(
          height: 250,
          child: Center(child: Text('No data')),
        ),
      );
    }

    double maxTotal = 0;
    for (final day in weekly) {
      final t = (day['total'] as num?)?.toDouble() ?? 0;
      if (t > maxTotal) maxTotal = t;
    }

    return _chartCard(
      title: 'Weekly Attendance Trend',
      child: SizedBox(
        height: 250,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxTotal * 1.15,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final labels = ['Present', 'Absent', 'Late'];
                  return BarTooltipItem(
                    '${labels[rodIndex]}: ${rod.toY.toInt()}',
                    GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(value.toInt().toString(),
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: AppColors.textSecondary));
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= weekly.length) {
                      return const SizedBox.shrink();
                    }
                    final label = weekly[idx]['date']?.toString() ??
                        (idx < dayNames.length ? dayNames[idx] : '$idx');
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(label,
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: AppColors.textSecondary)),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppColors.border.withOpacity(0.5),
                strokeWidth: 1,
              ),
            ),
            barGroups: List.generate(weekly.length, (i) {
              final day = weekly[i] as Map<String, dynamic>;
              final present = (day['present'] as num?)?.toDouble() ?? 0;
              final absent = (day['absent'] as num?)?.toDouble() ?? 0;
              final lateCount = (day['late'] as num?)?.toDouble() ?? 0;
              return BarChartGroupData(
                x: i,
                barsSpace: 2,
                barRods: [
                  BarChartRodData(
                    toY: present,
                    color: AppColors.success,
                    width: 10,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3)),
                  ),
                  BarChartRodData(
                    toY: absent,
                    color: AppColors.error,
                    width: 10,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3)),
                  ),
                  BarChartRodData(
                    toY: lateCount,
                    color: AppColors.warning,
                    width: 10,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3)),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Chart E: Gender Distribution (Pie) ──────────────────────────────────
  Widget _buildGenderDistributionPie() {
    final genderMap = _analytics?['genderDistribution'] as Map<String, dynamic>?;
    if (genderMap == null || genderMap.isEmpty) {
      return _chartCard(
        title: 'Gender Distribution',
        child: const SizedBox(
          height: 200,
          child: Center(child: Text('No data')),
        ),
      );
    }

    final colorMap = <String, Color>{
      'Male': AppColors.navy,
      'Female': AppColors.gold,
      'Other': const Color(0xFF0D9488),
    };

    final entries = genderMap.entries.toList();

    return _chartCard(
      title: 'Gender Distribution',
      child: SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  sections: entries.map((e) {
                    final val = (e.value as num).toDouble();
                    return PieChartSectionData(
                      value: val,
                      title: '${val.toInt()}',
                      color: colorMap[e.key] ?? AppColors.textSecondary,
                      radius: 40,
                      titleStyle: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: entries.map((e) {
                  final color = colorMap[e.key] ?? AppColors.textSecondary;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${e.key}: ${(e.value as num).toInt()}',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textPrimary)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chart F: New Admissions Comparison ──────────────────────────────────
  Widget _buildNewAdmissionsCard() {
    final thisMonth =
        (_analytics?['newAdmissionsThisMonth'] as num?)?.toInt() ?? 0;
    final lastMonth =
        (_analytics?['newAdmissionsLastMonth'] as num?)?.toInt() ?? 0;

    final diff = thisMonth - lastMonth;
    final isUp = diff >= 0;
    final changeColor = isUp ? AppColors.success : AppColors.error;
    final changeIcon = isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final changeText = isUp ? '+$diff' : '$diff';

    double percentChange = 0;
    if (lastMonth > 0) {
      percentChange = (diff / lastMonth) * 100;
    }

    return _chartCard(
      title: 'New Admissions',
      child: SizedBox(
        height: 200,
        child: _analytics == null
            ? const Center(child: Text('No data'))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // This Month
                      Column(
                        children: [
                          Text('This Month',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          Text('$thisMonth',
                              style: GoogleFonts.poppins(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy)),
                        ],
                      ),
                      // Divider
                      Container(
                        width: 1,
                        height: 60,
                        color: AppColors.border,
                      ),
                      // Last Month
                      Column(
                        children: [
                          Text('Last Month',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          Text('$lastMonth',
                              style: GoogleFonts.poppins(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Change indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: changeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(changeIcon, size: 18, color: changeColor),
                        const SizedBox(width: 6),
                        Text(
                          '$changeText (${percentChange.toStringAsFixed(1)}%)',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: changeColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── KPI Stat Card ───────────────────────────────────────────────────────
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
