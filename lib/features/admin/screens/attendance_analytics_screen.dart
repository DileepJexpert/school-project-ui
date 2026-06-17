import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/attendance_analytics_api_service.dart';

class AttendanceAnalyticsScreen extends StatefulWidget {
  const AttendanceAnalyticsScreen({super.key});

  @override
  State<AttendanceAnalyticsScreen> createState() =>
      _AttendanceAnalyticsScreenState();
}

class _AttendanceAnalyticsScreenState extends State<AttendanceAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Overview tab state ────────────────────────────────────────────────
  String? _selectedClass;
  final _yearCtrl = TextEditingController(text: '2024-25');
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  // Analytics data
  double _overallPercentage = 0;
  int _totalStudents = 0;
  int _totalDays = 0;
  int _atRiskCount = 0;
  List<_MonthlyData> _monthlyData = [];
  List<_ClassBreakdown> _classBreakdown = [];

  // ── At-Risk tab state ─────────────────────────────────────────────────
  final _arYearCtrl = TextEditingController(text: '2024-25');
  double _threshold = 75;
  bool _arLoading = false;
  bool _arLoaded = false;
  String? _arError;
  List<_AtRiskStudent> _atRiskStudents = [];
  bool _sortAscending = true;

  // ─────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _yearCtrl.dispose();
    _arYearCtrl.dispose();
    super.dispose();
  }

  // ── Overview tab helpers ──────────────────────────────────────────────

  Future<void> _loadAnalytics() async {
    setState(() {
      _loading = true;
      _error = null;
      _loaded = false;
    });
    try {
      final data = await AttendanceAnalyticsApiService.getAnalytics(
        className: _selectedClass,
        academicYear: _yearCtrl.text.trim(),
      );

      if (!mounted) return;

      _overallPercentage =
          (data['overallPercentage'] as num?)?.toDouble() ?? 0;
      _totalStudents = (data['totalStudents'] as num?)?.toInt() ?? 0;
      _totalDays = (data['totalDays'] as num?)?.toInt() ?? 0;
      _atRiskCount = (data['atRiskCount'] as num?)?.toInt() ?? 0;

      // Parse monthly data
      final monthlyRaw = data['monthlyTrend'] as List? ?? [];
      _monthlyData = monthlyRaw.map((m) {
        return _MonthlyData(
          month: (m['month'] as num?)?.toInt() ?? 1,
          percentage: (m['percentage'] as num?)?.toDouble() ?? 0,
        );
      }).toList();

      // Parse class-wise breakdown
      final classRaw = data['classBreakdown'] as List? ?? [];
      _classBreakdown = classRaw.map((c) {
        return _ClassBreakdown(
          className: c['className'] as String? ?? '',
          percentage: (c['percentage'] as num?)?.toDouble() ?? 0,
          studentCount: (c['studentCount'] as num?)?.toInt() ?? 0,
        );
      }).toList();

      setState(() => _loaded = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── At-Risk tab helpers ───────────────────────────────────────────────

  Future<void> _loadAtRisk() async {
    setState(() {
      _arLoading = true;
      _arError = null;
      _arLoaded = false;
    });
    try {
      final data = await AttendanceAnalyticsApiService.getAtRiskStudents(
        academicYear: _arYearCtrl.text.trim(),
        threshold: _threshold.toInt(),
      );

      if (!mounted) return;

      _atRiskStudents = data.map((s) {
        return _AtRiskStudent(
          name: s['studentName'] as String? ?? '',
          className: s['className'] as String? ?? '',
          percentage: (s['percentage'] as num?)?.toDouble() ?? 0,
          presentCount: (s['presentCount'] as num?)?.toInt() ?? 0,
          absentCount: (s['absentCount'] as num?)?.toInt() ?? 0,
        );
      }).toList();

      _sortStudents();

      setState(() => _arLoaded = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _arError = e.toString());
    } finally {
      if (mounted) setState(() => _arLoading = false);
    }
  }

  void _sortStudents() {
    _atRiskStudents.sort((a, b) => _sortAscending
        ? a.percentage.compareTo(b.percentage)
        : b.percentage.compareTo(a.percentage));
  }

  // ── Shared helpers ────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunitoSans()),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  Color _percentageColor(double pct) {
    if (pct < 60) return AppColors.error;
    if (pct < 75) return AppColors.warning;
    if (pct < 85) return const Color(0xFFF59E0B); // yellow-orange
    return AppColors.success;
  }

  Color _classPercentageColor(double pct) {
    if (pct < 75) return AppColors.error;
    if (pct < 85) return AppColors.warning;
    return AppColors.success;
  }

  static const _kMonthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  InputDecoration _inputDecor(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.nunitoSans(color: AppColors.textLight, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: AppColors.navy),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          borderSide: const BorderSide(color: AppColors.navy, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        isDense: true,
      );

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attendance Analytics',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          Text('Analyze attendance trends and identify at-risk students',
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          // ── Tab bar ───────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.creamDark,
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.nunitoSans(fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'At-Risk Students'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildOverviewTab(), _buildAtRiskTab()],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // OVERVIEW TAB
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildOverviewTab() => Column(children: [
        _buildOverviewFilterBar(),
        const SizedBox(height: 16),
        Expanded(child: _buildOverviewBody()),
      ]);

  Widget _buildOverviewFilterBar() => Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: _selectedClass,
                  decoration:
                      _inputDecor('All Classes', Icons.school_outlined),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Classes',
                          style: GoogleFonts.nunitoSans(fontSize: 13)),
                    ),
                    ...SchoolConstants.baseClasses.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c,
                              style: GoogleFonts.nunitoSans(fontSize: 13)),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedClass = v),
                ),
              ),
              SizedBox(
                width: 130,
                child: TextField(
                    controller: _yearCtrl,
                    decoration: _inputDecor(
                        'Academic Year', Icons.calendar_today_outlined)),
              ),
              ElevatedButton.icon(
                onPressed: _loading ? null : _loadAnalytics,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.analytics_outlined, size: 16),
                label: Text(_loading ? 'Loading...' : 'Analyze'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12)),
              ),
            ],
          ),
        ),
      );

  Widget _buildOverviewBody() {
    if (_loading) return _buildShimmer();
    if (_error != null) return _buildError(_error!, _loadAnalytics);
    if (!_loaded) {
      return _buildIdle('Select filters and tap Analyze to view analytics');
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(),
          const SizedBox(height: 20),
          _buildMonthlyTrendChart(),
          const SizedBox(height: 20),
          if (_selectedClass == null) _buildClassBreakdown(),
        ],
      ),
    );
  }

  // ── Stats cards row ───────────────────────────────────────────────────

  Widget _buildStatsRow() => LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          final cards = [
            _buildStatCard(
              'Overall Attendance',
              '${_overallPercentage.toStringAsFixed(1)}%',
              Icons.trending_up_rounded,
              AppColors.success,
            ),
            _buildStatCard(
              'Total Students',
              '$_totalStudents',
              Icons.people_rounded,
              AppColors.info,
            ),
            _buildStatCard(
              'Total Days',
              '$_totalDays',
              Icons.calendar_month_rounded,
              AppColors.navy,
            ),
            _buildStatCard(
              'At-Risk Students',
              '$_atRiskCount',
              Icons.warning_amber_rounded,
              AppColors.error,
            ),
          ];
          if (isNarrow) {
            return Column(
              children: [
                Row(children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[3]),
                ]),
              ],
            );
          }
          return Row(
            children: cards
                .map((c) => Expanded(child: c))
                .expand((w) => [w, const SizedBox(width: 12)])
                .toList()
              ..removeLast(),
          );
        },
      );

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.nunitoSans(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── Monthly trend chart ───────────────────────────────────────────────

  Widget _buildMonthlyTrendChart() => Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Monthly Attendance Trend',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy)),
              const SizedBox(height: 4),
              Text('Attendance percentage by month',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              _monthlyData.isEmpty
                  ? _buildNoChartData()
                  : SizedBox(height: 250, child: _buildBarChart()),
            ],
          ),
        ),
      );

  Widget _buildNoChartData() => Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 48, color: AppColors.textLight.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text('No data available',
                style: GoogleFonts.nunitoSans(
                    fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _buildBarChart() {
    final maxY = 100.0;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final monthIndex = group.x.toInt();
              final label = monthIndex >= 0 && monthIndex < 12
                  ? _kMonthLabels[monthIndex]
                  : '';
              return BarTooltipItem(
                '$label\n${rod.toY.toStringAsFixed(1)}%',
                GoogleFonts.nunitoSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= 12) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _kMonthLabels[idx],
                    style: GoogleFonts.nunitoSans(
                        fontSize: 10, color: AppColors.textSecondary),
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 20,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 10, color: AppColors.textSecondary),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border.withOpacity(0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _monthlyData.map((m) {
          return BarChartGroupData(
            x: m.month - 1,
            barRods: [
              BarChartRodData(
                toY: m.percentage,
                color: AppColors.success,
                width: 18,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: AppColors.success.withOpacity(0.08),
                ),
              ),
            ],
            showingTooltipIndicators: [0],
          );
        }).toList(),
      ),
    );
  }

  // ── Class-wise breakdown ──────────────────────────────────────────────

  Widget _buildClassBreakdown() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Class-wise Breakdown',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text('Average attendance per class',
              style: GoogleFonts.nunitoSans(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          if (_classBreakdown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No class data available',
                    style: GoogleFonts.nunitoSans(
                        fontSize: 14, color: AppColors.textSecondary)),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children:
                  _classBreakdown.map((c) => _buildClassTile(c)).toList(),
            ),
        ],
      );

  Widget _buildClassTile(_ClassBreakdown cb) {
    final color = _classPercentageColor(cb.percentage);
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(cb.className,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ),
                  Text('${cb.percentage.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ],
              ),
              const SizedBox(height: 4),
              Text('${cb.studentCount} students',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: cb.percentage / 100,
                  minHeight: 8,
                  backgroundColor: color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // AT-RISK STUDENTS TAB
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildAtRiskTab() => Column(children: [
        _buildAtRiskFilterBar(),
        const SizedBox(height: 16),
        Expanded(child: _buildAtRiskBody()),
      ]);

  Widget _buildAtRiskFilterBar() => Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    child: TextField(
                        controller: _arYearCtrl,
                        decoration: _inputDecor(
                            'Academic Year', Icons.calendar_today_outlined)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _arLoading ? null : _loadAtRisk,
                    icon: _arLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search_rounded, size: 16),
                    label: Text(
                        _arLoading ? 'Loading...' : 'Find At-Risk Students'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12)),
                  ),
                  if (_arLoaded)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _sortAscending = !_sortAscending;
                          _sortStudents();
                        });
                      },
                      icon: Icon(
                        _sortAscending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 16,
                      ),
                      label: Text(_sortAscending
                          ? 'Lowest First'
                          : 'Highest First'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.navy),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Threshold: ',
                      style: GoogleFonts.nunitoSans(
                          fontSize: 13, color: AppColors.textSecondary)),
                  Text('${_threshold.toInt()}%',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy)),
                  Expanded(
                    child: Slider(
                      value: _threshold,
                      min: 50,
                      max: 100,
                      divisions: 50,
                      activeColor: AppColors.navy,
                      inactiveColor: AppColors.navy.withOpacity(0.15),
                      label: '${_threshold.toInt()}%',
                      onChanged: (v) => setState(() => _threshold = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildAtRiskBody() {
    if (_arLoading) return _buildShimmer();
    if (_arError != null) return _buildError(_arError!, _loadAtRisk);
    if (!_arLoaded) {
      return _buildIdle(
          'Set threshold and tap Find At-Risk Students to view results');
    }
    if (_atRiskStudents.isEmpty) return _buildAtRiskEmpty();
    return ListView.separated(
      itemCount: _atRiskStudents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _buildAtRiskCard(_atRiskStudents[i]),
    );
  }

  Widget _buildAtRiskEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 60, color: AppColors.success.withOpacity(0.6)),
            const SizedBox(height: 14),
            Text('No at-risk students found',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success)),
            const SizedBox(height: 6),
            Text(
                'All students are above the ${_threshold.toInt()}% threshold',
                style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );

  Widget _buildAtRiskCard(_AtRiskStudent student) {
    final pctColor = _atRiskPercentageColor(student.percentage);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.error.withOpacity(0.1),
                  child: Text(
                    student.name.isNotEmpty
                        ? student.name[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name,
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error.withOpacity(0.85))),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.navy.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(student.className,
                            style: GoogleFonts.nunitoSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${student.percentage.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: pctColor)),
                    Text('Attendance',
                        style: GoogleFonts.nunitoSans(
                            fontSize: 10, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildCountChip(
                    'Present', student.presentCount, AppColors.success),
                const SizedBox(width: 10),
                _buildCountChip(
                    'Absent', student.absentCount, AppColors.error),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: student.percentage / 100,
                minHeight: 6,
                backgroundColor: AppColors.error.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountChip(String label, int count, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: ',
                style: GoogleFonts.nunitoSans(
                    fontSize: 11, color: AppColors.textSecondary)),
            Text('$count',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      );

  Color _atRiskPercentageColor(double pct) {
    if (pct < 60) return AppColors.error;
    if (pct < 75) return AppColors.warning;
    return const Color(0xFFF59E0B); // yellow
  }

  // ── Shared widgets ────────────────────────────────────────────────────

  Widget _buildIdle(String message) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights_rounded,
                size: 60, color: AppColors.textLight.withOpacity(0.4)),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );

  Widget _buildShimmer() => ListView.builder(
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 48,
          decoration: BoxDecoration(
              color: AppColors.creamDark,
              borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
        ),
      );

  Widget _buildError(String error, VoidCallback retry) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppColors.error, size: 52),
            const SizedBox(height: 12),
            Text('Failed to load',
                style: GoogleFonts.nunitoSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error)),
            const SizedBox(height: 6),
            Text(error,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: retry, child: const Text('Retry')),
          ],
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// LOCAL DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════

class _MonthlyData {
  final int month;
  final double percentage;

  _MonthlyData({required this.month, required this.percentage});
}

class _ClassBreakdown {
  final String className;
  final double percentage;
  final int studentCount;

  _ClassBreakdown({
    required this.className,
    required this.percentage,
    required this.studentCount,
  });
}

class _AtRiskStudent {
  final String name;
  final String className;
  final double percentage;
  final int presentCount;
  final int absentCount;

  _AtRiskStudent({
    required this.name,
    required this.className,
    required this.percentage,
    required this.presentCount,
    required this.absentCount,
  });
}
