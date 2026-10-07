import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/responsive.dart';
import '../../models/auth_models.dart';
import '../../services/auth_service.dart';
import '../../services/fee_api_service.dart';
import '../../services/staff_api_service.dart';
import '../../models/fee_models.dart';
import '../../models/school_data.dart';

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
  // -- HR & PAYROLL --
  const _MenuItem(
      icon: Icons.badge_outlined, label: 'HR & Staff', isLive: true), // 15
  // -- ADMINISTRATION --
  const _MenuItem(
      icon: Icons.description_outlined,
      label: 'Certificates',
      isLive: true), // 16
  const _MenuItem(
      icon: Icons.smart_toy_outlined, label: 'AI Settings', isLive: true), // 17
  const _MenuItem(
      icon: Icons.settings_outlined, label: 'Settings', isLive: true), // 18
  const _MenuItem(
      icon: Icons.chat_bubble_outline,
      label: 'WhatsApp Agent',
      isLive: true), // 19
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
      items: [_allItems[13], _allItems[14], _allItems[19]]),
  _MenuGroup(title: 'HR & PAYROLL', items: [_allItems[15]]),
  _MenuGroup(
      title: 'ADMINISTRATION',
      items: [_allItems[16], _allItems[17], _allItems[18]]),
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
    switch (_selectedIndex) {
      case 0:
        return _OverviewContent(
          onNavigate: (index) => setState(() => _selectedIndex = index),
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
        return const HrScreen();
      case 16:
        return const CertificatesScreen();
      case 17:
        return const AiConfigScreen();
      case 18:
        return const SettingsScreen();
      case 19:
        return const WhatsAppConfigScreen();
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
    final brandColor = context.palette.brand;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedIndex = index);
          if (Responsive.isMobile(context)) Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: isActive
                ? brandColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 19,
                color: isActive ? brandColor : const Color(0xFF64748B),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  item.label,
                  style: GoogleFonts.nunitoSans(
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? brandColor : const Color(0xFF334155),
                    fontSize: 13,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: brandColor,
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
  final void Function(int index)? onNavigate;
  const _OverviewContent({this.onNavigate});

  @override
  State<_OverviewContent> createState() => _OverviewContentState();
}

class _OverviewContentState extends State<_OverviewContent> {
  bool _loading = true;
  String? _error;
  SchoolSummary? _schoolSummary;
  Map<String, dynamic>? _staffDashboard;

  static const _moduleNavMap = {
    'Students': 1,
    'Admissions': 2,
    'Homework': 3,
    'Video Tutorials': 4,
    'Fees': 5,
    'Expenses': 6,
    'Reports': 7,
    'Attendance': 8,
    'Timetable': 9,
    'Results': 10,
    'Transport': 11,
    'Discipline': 12,
    'Notifications': 13,
    'Chat': 14,
    'HR & Staff': 15,
    'Certificates': 16,
    'AI Settings': 17,
    'Settings': 18,
    'WhatsApp Agent': 19,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    var failedRequests = 0;

    Future<SchoolSummary?> loadSummary() async {
      try {
        return await FeeApiService.getSchoolSummary();
      } catch (_) {
        failedRequests++;
        return null;
      }
    }

    Future<Map<String, dynamic>?> loadStaffDashboard() async {
      try {
        return await StaffApiService.getStaffDashboard();
      } catch (_) {
        failedRequests++;
        return null;
      }
    }

    try {
      final results = await Future.wait([
        loadSummary(),
        loadStaffDashboard(),
      ]);
      if (mounted) {
        setState(() {
          if (results[0] != null) {
            _schoolSummary = results[0] as SchoolSummary;
          }
          if (results[1] != null) {
            _staffDashboard = results[1] as Map<String, dynamic>;
          }
          _error = failedRequests == 0
              ? null
              : 'Some dashboard metrics are temporarily unavailable.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Dashboard metrics could not be loaded.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    if (amount >= 100000) return 'Rs ${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return 'Rs ${(amount / 1000).toStringAsFixed(1)}K';
    return 'Rs ${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final totalStudents = _schoolSummary?.totalStudents ?? 0;
    final totalStaff = (_staffDashboard?['totalStaff'] as num?)?.toInt() ?? 0;
    final pendingLeaves =
        (_staffDashboard?['pendingLeaveRequests'] as num?)?.toInt() ?? 0;
    final revenue = _schoolSummary?.totalFeesCollected ?? 0.0;
    final checklist = SchoolData.setupChecklist;
    final completedChecklistCount = checklist.where((c) => c.isComplete).length;
    final palette = context.palette;
    final now = DateTime.now();
    final academicYearStart = now.month >= 4 ? now.year : now.year - 1;
    final academicYear = '$academicYearStart–${academicYearStart + 1}';

    final user = AuthService.instance.currentUser;
    final userName = user?.fullName.split(' ').first ?? 'Admin';

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Sleek Compact Overview Header Bar ──────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x060F172A),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Welcome, $userName',
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: context.palette.brand.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: context.palette.brand.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, size: 12, color: context.palette.brand),
                                const SizedBox(width: 4),
                                Text(
                                  'AY $academicYear • ${AppStrings.schoolName}',
                                  style: GoogleFonts.nunitoSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: context.palette.brand,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _loadData,
                      icon: _loading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Refresh'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Some metrics need attention',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.error)),
                            const SizedBox(height: 2),
                            Text(
                              '$_error You can retry without leaving this page.',
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = Responsive.gridColumns(context);
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _statCard(
                            context,
                            'Total Students',
                            _formatNumber(totalStudents),
                            Icons.people_alt_rounded,
                            palette.brand,
                            constraints.maxWidth,
                            columns,
                            onTap: () => widget.onNavigate?.call(1)),
                        _statCard(
                            context,
                            'Total Staff',
                            _formatNumber(totalStaff),
                            Icons.badge_rounded,
                            const Color(0xFF0D9488),
                            constraints.maxWidth,
                            columns,
                            onTap: () => widget.onNavigate?.call(15)),
                        _statCard(
                            context,
                            'Pending Leaves',
                            '$pendingLeaves',
                            Icons.event_busy_rounded,
                            palette.accent,
                            constraints.maxWidth,
                            columns,
                            onTap: () => widget.onNavigate?.call(15)),
                        _statCard(
                            context,
                            'Revenue (Total)',
                            _formatRevenue(revenue),
                            Icons.monetization_on_rounded,
                            const Color(0xFFDB2777),
                            constraints.maxWidth,
                            columns,
                            onTap: () => widget.onNavigate?.call(5)),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 24),
              Text('Quick Actions',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: palette.brand)),
              const SizedBox(height: 4),
              Text('Jump directly to frequent workflows and operations.',
                  style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w400)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _actionCard('New Enquiry', 'Register admission lead',
                      Icons.person_add_alt_1_outlined, 2, palette.brand),
                  _actionCard('Enroll Student', 'Full student registration',
                      Icons.school_outlined, 1, const Color(0xFF0D9488)),
                  _actionCard('Collect Fees', 'Record cash / online fee',
                      Icons.receipt_long_outlined, 5, const Color(0xFFDB2777)),
                  _actionCard('Mark Attendance', 'Daily class roll call',
                      Icons.how_to_reg_outlined, 8, palette.accent),
                  _actionCard('Assign Homework', 'Class assignments & notes',
                      Icons.menu_book_outlined, 3, const Color(0xFF6366F1)),
                  _actionCard('Send Notice', 'Broadcast announcements',
                      Icons.campaign_outlined, 13, const Color(0xFFEA580C)),
                ],
              ),
              if (completedChecklistCount < checklist.length) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.checklist_rounded,
                              color: palette.brand, size: 22),
                          const SizedBox(width: 8),
                          Text('School Setup Progress',
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: palette.brand)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: palette.brand.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$completedChecklistCount / ${checklist.length} Complete',
                              style: GoogleFonts.nunitoSans(
                                  fontWeight: FontWeight.w700,
                                  color: palette.brand,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...checklist.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  item.isComplete
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 18,
                                  color: item.isComplete
                                      ? AppColors.success
                                      : AppColors.textLight,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.title,
                                          style: GoogleFonts.nunitoSans(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: item.isComplete
                                                  ? AppColors.textPrimary
                                                  : AppColors.navy)),
                                      Text(item.description,
                                          style: GoogleFonts.nunitoSans(
                                              fontSize: 11,
                                              color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                if (!item.isComplete)
                                  TextButton(
                                    onPressed: () => widget.onNavigate
                                        ?.call(item.targetIndex),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Configure →',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text('Live Modules',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: palette.brand)),
              const SizedBox(height: 4),
              Text('Click any module chip to open it directly.',
                  style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w400)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _liveChip(Icons.people_alt_outlined, 'Students'),
                _liveChip(Icons.person_add_alt_1_outlined, 'Admissions'),
                _liveChip(Icons.receipt_long_outlined, 'Fees'),
                _liveChip(Icons.money_off_outlined, 'Expenses'),
                _liveChip(Icons.assessment_outlined, 'Reports'),
                _liveChip(Icons.rule_folder_outlined, 'Attendance'),
                _liveChip(Icons.table_chart_outlined, 'Timetable'),
                _liveChip(Icons.emoji_events_outlined, 'Results'),
                _liveChip(Icons.directions_bus_outlined, 'Transport'),
                _liveChip(Icons.notifications_active_outlined, 'Notifications'),
                _liveChip(Icons.settings_outlined, 'Settings'),
                _liveChip(Icons.gavel_outlined, 'Discipline'),
                _liveChip(Icons.chat_outlined, 'Chat'),
                _liveChip(Icons.badge_outlined, 'HR & Staff'),
                _liveChip(Icons.description_outlined, 'Certificates'),
                _liveChip(Icons.menu_book_outlined, 'Homework'),
                _liveChip(Icons.video_library_outlined, 'Video Tutorials'),
                _liveChip(Icons.smart_toy_outlined, 'AI Settings'),
                _liveChip(Icons.chat_bubble_outline, 'WhatsApp Agent'),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard(String title, String subtitle, IconData icon,
      int targetIndex, Color color) {
    return SizedBox(
      width: 210,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEAECF0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06101828),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onNavigate?.call(targetIndex),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.nunitoSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.nunitoSans(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 17, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _liveChip(IconData icon, String label) {
    final target = _moduleNavMap[label];
    return InkWell(
      onTap: target != null ? () => widget.onNavigate?.call(target) : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
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
      ),
    );
  }

  Widget _statCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    double maxWidth,
    int columns, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: (maxWidth - (columns - 1) * 14) / columns,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAECF0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A101828),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.nunitoSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 20, color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          subtitle ?? 'Active System',
                          style: GoogleFonts.nunitoSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 15,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
