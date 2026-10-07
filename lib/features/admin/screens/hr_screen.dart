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
  String? _staffCategoryFilter;
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

  void _navigateToCategory(String category) {
    setState(() {
      _staffCategoryFilter = category;
      _activeSection = 'staff';
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_activeSection) {
      'staff' => _wrapWithBack(
          StaffListScreen(initialCategory: _staffCategoryFilter),
          'Staff Directory',
        ),
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
                tooltip: 'Back to HR Desk',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() {
                    _activeSection = 'dashboard';
                    _staffCategoryFilter = null;
                  });
                  _loadDashboard();
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_staffCategoryFilter != null && _staffCategoryFilter != 'ALL')
                      Text(
                        'Filtered by ${_categoryDisplayName(_staffCategoryFilter!)}',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 12,
                          color: const Color(0xFF2563EB),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
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
          else
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetrics(),
                    const SizedBox(height: 20),
                    _buildCategorySection(),
                    const SizedBox(height: 20),
                    _buildCategoryTableCard(),
                    const SizedBox(height: 20),
                    _buildActionGrid(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final totalStaff = _number('totalStaff');
    final activeStaff = _number('activeStaff');
    final payroll = _double('totalMonthlyPayroll');
    final activePercent =
        totalStaff == 0 ? 0 : (activeStaff / totalStaff * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
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
                Row(
                  children: [
                    Text(
                      'HR & Staff Management',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Payroll Desk',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Directory, categorization (teachers, drivers, peons), leave tracking and monthly salary payouts in one desk.',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${_formatCurrency(payroll)}',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$activePercent% staff active',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.82),
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
    final payroll = _double('totalMonthlyPayroll');
    final onLeave = _number('onLeaveToday');
    final active = _number('activeStaff');
    final presentToday = (active - onLeave).clamp(0, 9999);

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
              label: 'Total Staff',
              value: _number('totalStaff').toString(),
              subtext: 'Registered in school',
              icon: Icons.people_alt_outlined,
              color: context.palette.brand,
            ),
            _MetricCard(
              width: width,
              label: 'Active Staff',
              value: active.toString(),
              subtext: '$presentToday present today',
              icon: Icons.verified_user_outlined,
              color: AppColors.success,
            ),
            _MetricCard(
              width: width,
              label: 'On Leave Today',
              value: onLeave.toString(),
              subtext: '${_number('pendingLeaveRequests')} pending approvals',
              icon: Icons.event_busy_outlined,
              color: AppColors.warning,
            ),
            _MetricCard(
              width: width,
              label: 'Monthly Payroll',
              value: '₹${_formatCurrency(payroll)}',
              subtext: 'Total base salary outlay',
              icon: Icons.payments_outlined,
              color: const Color(0xFF6366F1),
            ),
          ],
        );
      },
    );
  }

  // ── CATEGORY BREAKDOWN SECTION ──

  Widget _buildCategorySection() {
    final breakdown = _categoryBreakdown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.pie_chart_outline_rounded,
                  color: Color(0xFF2563EB), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Staff Breakdown by Category',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Categorized headcount (teachers, drivers, peons, admin) with present status and salary outlays.',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _navigateToCategory('ALL'),
              icon: const Icon(Icons.people_alt_outlined, size: 16),
              label: const Text('View All Staff'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            final isMedium = constraints.maxWidth < 1100;
            final columns = isNarrow ? 1 : (isMedium ? 2 : 4);
            final cardWidth =
                (constraints.maxWidth - (columns - 1) * 12) / columns;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: breakdown
                  .map((item) => _CategoryCard(
                        width: cardWidth,
                        data: item,
                        onViewStaff: () => _navigateToCategory(
                          item['category'] as String? ?? '',
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryTableCard() {
    final breakdown = _categoryBreakdown;
    final totalPayroll = _double('totalMonthlyPayroll');

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Payroll & Headcount Distribution',
                style: GoogleFonts.nunitoSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Total Outlay: ₹${_formatCurrency(totalPayroll)} / mo',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Visual distribution bar
          if (totalPayroll > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: breakdown.map((cat) {
                    final salary = (cat['totalSalary'] as num?)?.toDouble() ?? 0.0;
                    final flex = ((salary / totalPayroll) * 1000).round();
                    if (flex <= 0) return const SizedBox.shrink();
                    final color = _categoryColor(cat['category'] as String? ?? '');
                    return Expanded(
                      flex: flex,
                      child: Container(
                        color: color,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Detailed Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 46,
              dataRowMaxHeight: 52,
              horizontalMargin: 12,
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Staff Count', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Active / Present', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Monthly Salary Outlay', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Avg Salary / Staff', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('% of Payroll', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: breakdown.map((cat) {
                final categoryCode = cat['category'] as String? ?? '';
                final label = cat['label'] as String? ?? categoryCode;
                final count = cat['count'] as int? ?? 0;
                final activeCount = cat['activeCount'] as int? ?? 0;
                final presentCount = cat['presentToday'] as int? ?? activeCount;
                final totalSalary = (cat['totalSalary'] as num?)?.toDouble() ?? 0.0;
                final avgSalary = (cat['avgSalary'] as num?)?.toDouble() ?? 0.0;
                final payrollPct = (cat['payrollPercentage'] as num?)?.toDouble() ?? 0.0;
                final color = _categoryColor(categoryCode);
                final icon = _categoryIcon(categoryCode);

                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, size: 16, color: color),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: GoogleFonts.nunitoSans(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(
                      '$count staff',
                      style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600),
                    )),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: activeCount > 0 ? AppColors.success : AppColors.textLight,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$presentCount present / $activeCount active',
                            style: GoogleFonts.nunitoSans(
                              fontWeight: FontWeight.w600,
                              color: activeCount > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(
                      '₹${_formatCurrency(totalSalary)}',
                      style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    )),
                    DataCell(Text(
                      '₹${_formatCurrency(avgSalary)}',
                      style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    )),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$payrollPct%',
                            style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 44,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: totalPayroll > 0 ? (totalSalary / totalPayroll).clamp(0.0, 1.0) : 0,
                                backgroundColor: AppColors.border,
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                                minHeight: 6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      InkWell(
                        onTap: () => _navigateToCategory(categoryCode),
                        child: Text(
                          'View →',
                          style: GoogleFonts.nunitoSans(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── QUICK ACTION MODULES ──

  Widget _buildActionGrid() {
    final actions = [
      _HrAction(
        title: 'Staff Directory',
        subtitle: 'Faculty & staff profiles, categories, contacts and IDs.',
        icon: Icons.badge_outlined,
        color: context.palette.brand,
        section: 'staff',
        badge: '${_number('totalStaff')} Staff',
      ),
      _HrAction(
        title: 'Leave Desk',
        subtitle: 'Review leave applications, daily absence and approvals.',
        icon: Icons.event_available_outlined,
        color: AppColors.warning,
        section: 'leave',
        badge: '${_number('pendingLeaveRequests')} Pending',
      ),
      _HrAction(
        title: 'Salary & Payroll',
        subtitle: 'Generate monthly payroll, category slips and payouts.',
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.success,
        section: 'salary',
        badge: '₹${_formatCurrency(_double('totalMonthlyPayroll'))}',
      ),
      const _HrAction(
        title: 'Staff Attendance',
        subtitle: 'Mark presence, late arrivals and daily attendance records.',
        icon: Icons.fingerprint_rounded,
        color: AppColors.info,
        section: 'attendance',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HR Operations & Modules',
          style: GoogleFonts.nunitoSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 980
                ? 4
                : constraints.maxWidth >= 620
                    ? 2
                    : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
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
            );
          },
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _categoryBreakdown {
    final raw = _dashboard?['categoryBreakdown'];
    if (raw is List) {
      return raw.map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  }

  int _number(String key) {
    final value = _dashboard?[key];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _double(String key) {
    final value = _dashboard?[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _formatCurrency(double val) {
    if (val >= 100000) {
      return '${(val / 100000).toStringAsFixed(val % 100000 == 0 ? 0 : 2)} L';
    }
    return val.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))(\.\d+)?'),
          (Match m) => '${m[1]},',
        );
  }

  static Color _categoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'TEACHER':
        return const Color(0xFF2563EB); // Royal Blue
      case 'DRIVER':
        return const Color(0xFFD97706); // Amber
      case 'PEON':
        return const Color(0xFF0D9488); // Teal
      case 'ADMIN':
        return const Color(0xFF7C3AED); // Purple
      case 'ACCOUNTANT':
        return const Color(0xFF059669); // Emerald
      case 'SECURITY':
        return const Color(0xFF475569); // Slate
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  static IconData _categoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'TEACHER':
        return Icons.school_outlined;
      case 'DRIVER':
        return Icons.directions_bus_filled_outlined;
      case 'PEON':
        return Icons.cleaning_services_outlined;
      case 'ADMIN':
        return Icons.admin_panel_settings_outlined;
      case 'ACCOUNTANT':
        return Icons.account_balance_outlined;
      case 'SECURITY':
        return Icons.shield_outlined;
      default:
        return Icons.badge_outlined;
    }
  }

  static String _categoryDisplayName(String category) {
    switch (category.toUpperCase()) {
      case 'TEACHER':
        return 'Teachers';
      case 'DRIVER':
        return 'Drivers & Transport';
      case 'PEON':
        return 'Peons & Support Staff';
      case 'ADMIN':
        return 'Administration';
      case 'ACCOUNTANT':
        return 'Accounts & Finance';
      case 'SECURITY':
        return 'Security Staff';
      default:
        return category;
    }
  }
}

// ── ACTION CARD WIDGET ──

class _HrAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String section;
  final String? badge;

  const _HrAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.section,
    this.badge,
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
                color: Color(0x060F172A),
                blurRadius: 10,
                offset: Offset(0, 3),
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
                  if (action.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: action.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        action.badge!,
                        style: GoogleFonts.nunitoSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: action.color,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
              const SizedBox(height: 12),
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
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Open module →',
                style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
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

// ── CATEGORY CARD WIDGET ──

class _CategoryCard extends StatelessWidget {
  final double width;
  final Map<String, dynamic> data;
  final VoidCallback onViewStaff;

  const _CategoryCard({
    required this.width,
    required this.data,
    required this.onViewStaff,
  });

  @override
  Widget build(BuildContext context) {
    final category = data['category'] as String? ?? '';
    final label = data['label'] as String? ?? category;
    final count = data['count'] as int? ?? 0;
    final activeCount = data['activeCount'] as int? ?? 0;
    final presentToday = data['presentToday'] as int? ?? activeCount;
    final onLeaveToday = data['onLeaveToday'] as int? ?? 0;
    final totalSalary = (data['totalSalary'] as num?)?.toDouble() ?? 0.0;
    final avgSalary = (data['avgSalary'] as num?)?.toDouble() ?? 0.0;
    final payrollPercentage = (data['payrollPercentage'] as num?)?.toDouble() ?? 0.0;

    final color = _HrScreenState._categoryColor(category);
    final icon = _HrScreenState._categoryIcon(category);

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Title + Active status chip
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.nunitoSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$count in system',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (count > 0 ? AppColors.success : AppColors.textLight)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$activeCount Active',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: count > 0 ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Middle: Headcount Stats
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$presentToday',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'present today',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (onLeaveToday > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$onLeaveToday on leave',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Salary details block
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Outlay',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '₹${_formatNum(totalSalary)}',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Average / Staff',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '₹${_formatNum(avgSalary)}',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Share of payroll bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (payrollPercentage / 100).clamp(0.0, 1.0),
                      backgroundColor: color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$payrollPercentage%',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action: View category staff
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onViewStaff,
                child: Text(
                  'View $label →',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNum(double val) {
    if (val >= 100000) {
      return '${(val / 100000).toStringAsFixed(val % 100000 == 0 ? 0 : 2)} L';
    }
    return val.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))(\.\d+)?'),
          (Match m) => '${m[1]},',
        );
  }
}

// ── METRIC CARD WIDGET ──

class _MetricCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final String? subtext;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    this.subtext,
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
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
                  if (subtext != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtext!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 10,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── STATE CARD WIDGET ──

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
