import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/student_portal_api_service.dart';
import '../../../services/auth_service.dart';

class StudentOverviewScreen extends StatefulWidget {
  final void Function(int index) onNavigate;

  const StudentOverviewScreen({super.key, required this.onNavigate});

  @override
  State<StudentOverviewScreen> createState() => _StudentOverviewScreenState();
}

class _StudentOverviewScreenState extends State<StudentOverviewScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _dashboard;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await StudentPortalApiService.getDashboard();
      if (mounted) setState(() => _dashboard = data);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load dashboard: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final userName = AuthService.instance.currentUser?.fullName ?? 'Student';

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppColors.error.withValues(alpha: 0.8)),
              const SizedBox(height: 12),
              Text(
                'Could not load your overview',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.brand),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: palette.brand),
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final attendance =
        (_dashboard?['attendancePercentage'] as num?)?.toDouble() ?? 0;
    final overallPct =
        (_dashboard?['overallPercentage'] as num?)?.toDouble() ?? 0;
    final totalFees = (_dashboard?['totalFees'] as num?)?.toDouble() ?? 0;
    final paidFees = (_dashboard?['paidFees'] as num?)?.toDouble() ?? 0;
    final pendingFees = (_dashboard?['pendingFees'] as num?)?.toDouble() ?? 0;
    final className = _dashboard?['className'] as String? ?? '';
    final studentId = _dashboard?['studentId'] as String? ?? '';

    final firstName = userName.split(' ').first;
    final attGood = attendance >= 75.0;
    final feeCleared = pendingFees <= 0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Welcome Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  palette.brand,
                  const Color(0xFF1E3A8A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: palette.brand.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.school_rounded,
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  'Student Workspace',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (className.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488)
                                    .withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Class $className',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (studentId.isNotEmpty)
                            Text(
                              'ID: $studentId',
                              style: GoogleFonts.nunitoSans(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Welcome back, $firstName! 👋',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Track your academic journey, upcoming coursework deadlines, and term performance.',
                        style: GoogleFonts.nunitoSans(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: 'Refresh details',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _loadDashboard,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Academic Progress KPIs
          Text(
            'Academic Snapshot',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.brand,
            ),
          ),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final cardWidth = isNarrow
                  ? (constraints.maxWidth - 12) / 2
                  : (constraints.maxWidth - 36) / 4;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _statCard(
                    title: 'Attendance',
                    value: '${attendance.toStringAsFixed(1)}%',
                    caption: attGood ? 'Regular (Above 75%)' : 'Shortage Alert',
                    icon: Icons.fact_check_outlined,
                    color: attGood ? const Color(0xFF059669) : AppColors.error,
                    width: cardWidth,
                    onTap: () => widget.onNavigate(2), // Attendance tab
                  ),
                  _statCard(
                    title: 'Exam Score',
                    value: '${overallPct.toStringAsFixed(1)}%',
                    caption: overallPct >= 80 ? 'Grade A (Distinction)' : 'Overall Average',
                    icon: Icons.emoji_events_outlined,
                    color: const Color(0xFF4F46E5),
                    width: cardWidth,
                    onTap: () => widget.onNavigate(3), // Results tab
                  ),
                  _statCard(
                    title: 'Fee Dues',
                    value: feeCleared ? 'Cleared' : '₹${pendingFees.toStringAsFixed(0)}',
                    caption: 'Paid ₹${paidFees.toStringAsFixed(0)} / ₹${totalFees.toStringAsFixed(0)}',
                    icon: Icons.receipt_long_outlined,
                    color: feeCleared ? const Color(0xFF059669) : const Color(0xFFD97706),
                    width: cardWidth,
                    onTap: () => widget.onNavigate(4), // Fees tab
                  ),
                  _statCard(
                    title: 'Coursework',
                    value: 'Assignments',
                    caption: 'Check active homework',
                    icon: Icons.menu_book_rounded,
                    color: const Color(0xFF0284C7),
                    width: cardWidth,
                    onTap: () => widget.onNavigate(1), // Homework tab
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Quick Learning Launchpad
          Text(
            'Quick Learning Launchpad',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.brand,
            ),
          ),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 900;
              final isTablet = constraints.maxWidth > 600;
              final cols = isDesktop ? 3 : (isTablet ? 2 : 1);
              final width = (constraints.maxWidth - (cols - 1) * 14) / cols;

              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _launchpadTile(
                    title: 'Homework & Assignments',
                    subtitle: 'Submit coursework, review feedback & track due dates',
                    icon: Icons.assignment_outlined,
                    color: const Color(0xFF0284C7),
                    width: width,
                    onTap: () => widget.onNavigate(1),
                  ),
                  _launchpadTile(
                    title: 'Attendance Register',
                    subtitle: 'Day-to-day attendance log, leaves, and percentages',
                    icon: Icons.calendar_month_outlined,
                    color: const Color(0xFF059669),
                    width: width,
                    onTap: () => widget.onNavigate(2),
                  ),
                  _launchpadTile(
                    title: 'Exam Results & Marksheets',
                    subtitle: 'Term assessment grades, marks breakdown and ranks',
                    icon: Icons.grade_outlined,
                    color: const Color(0xFF4F46E5),
                    width: width,
                    onTap: () => widget.onNavigate(3),
                  ),
                  _launchpadTile(
                    title: 'Fee Receipts & Invoices',
                    subtitle: 'Check installment dues, payment status & digital receipts',
                    icon: Icons.payments_outlined,
                    color: const Color(0xFFD97706),
                    width: width,
                    onTap: () => widget.onNavigate(4),
                  ),
                  _launchpadTile(
                    title: 'Class Timetable',
                    subtitle: 'Weekly subject schedule, class timings and teachers',
                    icon: Icons.schedule_outlined,
                    color: const Color(0xFF7C3AED),
                    width: width,
                    onTap: () => widget.onNavigate(5),
                  ),
                  _launchpadTile(
                    title: 'Video Lessons & Study Hub',
                    subtitle: 'Subject lecture recordings, syllabus notes and videos',
                    icon: Icons.play_lesson_outlined,
                    color: const Color(0xFFDC2626),
                    width: width,
                    onTap: () => widget.onNavigate(6),
                  ),
                  _launchpadTile(
                    title: 'AI Homework Helper',
                    subtitle: 'Get step-by-step problem explanations and study hints',
                    icon: Icons.auto_awesome_rounded,
                    color: const Color(0xFF0D9488),
                    width: width,
                    onTap: () => widget.onNavigate(7),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String caption,
    required IconData icon,
    required Color color,
    required double width,
    required VoidCallback onTap,
  }) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_rounded,
                    size: 16, color: color.withValues(alpha: 0.7)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: palette.brand,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.nunitoSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunitoSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _launchpadTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
    required VoidCallback onTap,
  }) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.brand,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textSecondary.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
