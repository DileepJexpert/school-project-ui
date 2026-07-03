import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/staff_api_service.dart';
import 'hr/leave_management_screen.dart';
import 'hr/salary_screen.dart';
import 'hr/staff_attendance_screen.dart';
import 'hr/staff_list_screen.dart';

class HrScreen extends StatefulWidget {
  const HrScreen({super.key});

  @override
  State<HrScreen> createState() => _HrScreenState();
}

class _HrScreenState extends State<HrScreen> {
  String _activeSection = 'dashboard';
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
      final data = await StaffApiService.getStaffDashboard();
      if (!mounted) return;
      setState(() => _dashboard = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_activeSection) {
      'staff' => _wrapWithBack(const StaffListScreen(), 'Staff Directory'),
      'leave' => _wrapWithBack(const LeaveManagementScreen(), 'Leave Desk'),
      'salary' => _wrapWithBack(const SalaryScreen(), 'Salary & Payroll'),
      'attendance' =>
        _wrapWithBack(const StaffAttendanceScreen(), 'Staff Attendance'),
      _ => _buildDashboard(),
    };
  }

  Widget _wrapWithBack(Widget child, String title) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.contentPadding(context),
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: context.palette.surface,
            border: Border(bottom: BorderSide(color: context.palette.border)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to HR',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() => _activeSection = 'dashboard');
                  _loadDashboard();
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh HR'),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildDashboard() {
    final padding = Responsive.contentPadding(context);

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: _StateCard(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load HR dashboard',
                subtitle: _error!,
                actionLabel: 'Retry',
                onAction: _loadDashboard,
              ),
            )
          else ...[
            _buildMetrics(),
            const SizedBox(height: 14),
            _buildActionGrid(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final totalStaff = _number('totalStaff');
    final activeStaff = _number('activeStaff');
    final activePercent =
        totalStaff == 0 ? 0 : (activeStaff / totalStaff * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: context.palette.heroGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HR & Staff',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Staff directory, leave, salary and attendance in one compact desk.',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$activePercent%',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'active staff',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 780;
        final width = compact
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 30) / 4;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricCard(
              width: width,
              label: 'Total staff',
              value: _number('totalStaff').toString(),
              icon: Icons.people_alt_outlined,
              color: context.palette.brand,
            ),
            _MetricCard(
              width: width,
              label: 'Active',
              value: _number('activeStaff').toString(),
              icon: Icons.verified_user_outlined,
              color: AppColors.success,
            ),
            _MetricCard(
              width: width,
              label: 'On leave today',
              value: _number('onLeaveToday').toString(),
              icon: Icons.event_busy_outlined,
              color: AppColors.warning,
            ),
            _MetricCard(
              width: width,
              label: 'Pending leaves',
              value: _number('pendingLeaveRequests').toString(),
              icon: Icons.pending_actions_outlined,
              color: AppColors.error,
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionGrid() {
    final actions = [
      _HrAction(
        title: 'Staff Directory',
        subtitle: 'Profiles, contacts, roles and employment details.',
        icon: Icons.badge_outlined,
        color: context.palette.brand,
        section: 'staff',
      ),
      const _HrAction(
        title: 'Leave Desk',
        subtitle: 'Review pending requests and daily leave pressure.',
        icon: Icons.event_available_outlined,
        color: AppColors.warning,
        section: 'leave',
      ),
      const _HrAction(
        title: 'Salary & Payroll',
        subtitle: 'Generate monthly salaries and mark payouts.',
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.success,
        section: 'salary',
      ),
      const _HrAction(
        title: 'Staff Attendance',
        subtitle: 'Mark presence, late arrivals and daily staff status.',
        icon: Icons.fingerprint_rounded,
        color: AppColors.info,
        section: 'attendance',
      ),
    ];

    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 980
              ? 4
              : constraints.maxWidth >= 620
                  ? 2
                  : 1;
          final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
          return SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: actions
                  .map(
                    (action) => _ActionCard(
                      width: width,
                      action: action,
                      onTap: () => setState(
                        () => _activeSection = action.section,
                      ),
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  int _number(String key) {
    final value = _dashboard?[key];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _HrAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String section;

  const _HrAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.section,
  });
}

class _ActionCard extends StatelessWidget {
  final double width;
  final _HrAction action;
  final VoidCallback onTap;

  const _ActionCard({
    required this.width,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.palette.surface,
            border: Border.all(color: context.palette.border),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: action.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(action.icon, color: action.color, size: 22),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                action.title,
                style: GoogleFonts.nunitoSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                action.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Open module',
                style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: action.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border.all(color: context.palette.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border.all(color: context.palette.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
