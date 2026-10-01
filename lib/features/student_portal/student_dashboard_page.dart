import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/responsive.dart';
import '../../services/auth_service.dart';
import '../../services/homework_api_service.dart';
import 'screens/ai_homework_helper_screen.dart';
import 'screens/my_attendance_screen.dart';
import 'screens/my_fees_screen.dart';
import 'screens/my_results_screen.dart';
import 'screens/my_timetable_screen.dart';
import 'screens/my_videos_screen.dart';
import 'screens/student_overview_screen.dart';

class _StudentMenuItem {
  final IconData icon;
  final String label;
  final String hint;

  const _StudentMenuItem({
    required this.icon,
    required this.label,
    required this.hint,
  });
}

const _studentMenu = [
  _StudentMenuItem(
    icon: Icons.space_dashboard_outlined,
    label: 'Overview',
    hint: 'Today, attendance and progress',
  ),
  _StudentMenuItem(
    icon: Icons.menu_book_outlined,
    label: 'Homework',
    hint: 'Assigned work and AI help',
  ),
  _StudentMenuItem(
    icon: Icons.fact_check_outlined,
    label: 'Attendance',
    hint: 'Daily attendance record',
  ),
  _StudentMenuItem(
    icon: Icons.emoji_events_outlined,
    label: 'Results',
    hint: 'Subject performance',
  ),
  _StudentMenuItem(
    icon: Icons.receipt_long_outlined,
    label: 'Fees',
    hint: 'Pending and paid fees',
  ),
  _StudentMenuItem(
    icon: Icons.calendar_month_outlined,
    label: 'Timetable',
    hint: 'Class schedule',
  ),
  _StudentMenuItem(
    icon: Icons.video_library_outlined,
    label: 'Videos',
    hint: 'Learning videos',
  ),
  _StudentMenuItem(
    icon: Icons.smart_toy_outlined,
    label: 'AI Helper',
    hint: 'Practice and explanation',
  ),
];

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _loadingHomework = true;
  List<dynamic> _homeworkList = [];

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    setState(() => _loadingHomework = true);
    try {
      final data = await HomeworkApiService.getMyHomework();
      if (mounted) setState(() => _homeworkList = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load homework: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingHomework = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AppRouter.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final railWidth = Responsive.isDesktop(context) ? 286.0 : 236.0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.palette.canvas,
      drawer: isMobile
          ? Drawer(
              child: _StudentRail(
                  selectedIndex: _selectedIndex, onSelect: _selectTab))
          : null,
      body: Row(
        children: [
          if (!isMobile)
            SizedBox(
              width: railWidth,
              child: _StudentRail(
                selectedIndex: _selectedIndex,
                onSelect: _selectTab,
              ),
            ),
          Expanded(
            child: Column(
              children: [
                _StudentTopBar(
                  selectedIndex: _selectedIndex,
                  onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
                  onLogout: _logout,
                ),
                Expanded(child: _buildPage()),
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

  Widget _buildPage() {
    return switch (_selectedIndex) {
      0 => StudentOverviewScreen(onNavigate: _selectTab),
      1 => _buildHomeworkPage(),
      2 => const MyAttendanceScreen(),
      3 => const MyResultsScreen(),
      4 => const MyFeesScreen(),
      5 => const MyTimetableScreen(),
      6 => const MyVideosScreen(),
      7 => const AiHomeworkHelperScreen(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildHomeworkPage() {
    if (_loadingHomework) {
      return const Center(child: CircularProgressIndicator());
    }

    final total = _homeworkList.length;
    final overdue = _homeworkList.where((entry) {
      final dueDate =
          (entry as Map<String, dynamic>)['dueDate'] as String? ?? '';
      final parsed = DateTime.tryParse(dueDate);
      return parsed != null && parsed.isBefore(DateTime.now());
    }).length;

    return RefreshIndicator(
      onRefresh: _loadHomework,
      child: ListView(
        padding: EdgeInsets.all(Responsive.contentPadding(context)),
        children: [
          _HomeworkHeader(total: total, overdue: overdue),
          const SizedBox(height: 16),
          if (_homeworkList.isEmpty)
            const _EmptyHomework()
          else
            ..._homeworkList
                .cast<Map<String, dynamic>>()
                .map((homework) => _HomeworkCard(homework: homework)),
        ],
      ),
    );
  }
}

class _StudentTopBar extends StatelessWidget {
  final int selectedIndex;
  final VoidCallback onOpenMenu;
  final VoidCallback onLogout;

  const _StudentTopBar({
    required this.selectedIndex,
    required this.onOpenMenu,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final item = _studentMenu[selectedIndex];
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

class _StudentRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _StudentRail({
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final userName = user?.fullName ?? 'Student';

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
                    child: const Icon(Icons.school_outlined),
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
                    'Student learning workspace',
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
                itemCount: _studentMenu.length,
                itemBuilder: (context, index) {
                  final item = _studentMenu[index];
                  final isActive = selectedIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: isActive
                          ? context.palette.brand.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                      child: InkWell(
                        onTap: () => onSelect(index),
                        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusLG),
                            border: Border.all(
                              color: isActive
                                  ? context.palette.border
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 20,
                                color: isActive
                                    ? context.palette.brand
                                    : AppColors.textLight,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: GoogleFonts.nunitoSans(
                                    fontSize: 14,
                                    fontWeight: isActive
                                        ? FontWeight.w800
                                        : FontWeight.w600,
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeworkHeader extends StatelessWidget {
  final int total;
  final int overdue;

  const _HomeworkHeader({
    required this.total,
    required this.overdue,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final intro = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Homework desk',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Track assignments, ask for guidance and keep due work visible.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            );
            final metrics = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MiniStat(
                  label: 'Assigned',
                  value: '$total',
                  color: context.palette.brand,
                ),
                _MiniStat(
                  label: 'Overdue',
                  value: '$overdue',
                  color: overdue > 0 ? AppColors.error : AppColors.success,
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [intro, const SizedBox(height: 14), metrics],
              );
            }
            return Row(
              children: [
                Expanded(child: intro),
                const SizedBox(width: 18),
                metrics,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.nunitoSans(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  final Map<String, dynamic> homework;

  const _HomeworkCard({required this.homework});

  @override
  Widget build(BuildContext context) {
    final title = homework['title'] as String? ?? 'Untitled homework';
    final description = homework['description'] as String? ?? '';
    final subject = homework['subject'] as String? ?? 'General';
    final teacherName = homework['teacherName'] as String? ?? 'Teacher';
    final dueDate = homework['dueDate'] as String? ?? '';
    final assignedDate = homework['assignedDate'] as String? ?? '';
    final homeworkId = homework['id'] as String?;
    final parsedDue = DateTime.tryParse(dueDate);
    final isOverdue = parsedDue != null && parsedDue.isBefore(DateTime.now());
    final statusColor = isOverdue ? AppColors.error : AppColors.warning;

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                  ),
                  child: const Icon(Icons.menu_book_outlined,
                      color: Color(0xFF0D9488), size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$subject - $teacherName',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(
                  label: isOverdue ? 'Overdue' : 'Due $dueDate',
                  color: statusColor,
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetaText(
                    icon: Icons.calendar_today_outlined,
                    text: 'Assigned $assignedDate'),
                _MetaText(icon: Icons.flag_outlined, text: 'Due $dueDate'),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AiHomeworkHelperScreen(
                          homeworkId: homeworkId,
                          subject: subject,
                          homeworkTitle: title,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.smart_toy_outlined, size: 17),
                  label: const Text('Ask AI'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textLight),
        const SizedBox(width: 5),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunitoSans(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyHomework extends StatelessWidget {
  const _EmptyHomework();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 46),
        child: Column(
          children: [
            Icon(Icons.menu_book_outlined,
                size: 48, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text('No homework assigned yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'New assignments from teachers will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
