import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _currency = NumberFormat.currency(symbol: '\u20B9', decimalDigits: 0);

  SchoolSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await FeeApiService.getSchoolSummary();
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdminPageHeader(
          title: 'School Reports',
          subtitle:
              'Live operating summary across enrollment, fees, dues and collection channels.',
          icon: Icons.assessment_outlined,
          actions: [
            OutlinedButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_loading)
          const SizedBox(
            height: 280,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _errorState()
        else
          _content(_summary!),
      ]),
    );
  }

  Widget _content(SchoolSummary summary) {
    final totalDemand = summary.totalFeesCollected + summary.totalFeesDue;
    final coverage =
        totalDemand <= 0 ? 0.0 : summary.totalFeesCollected / totalDemand;
    final averageTransaction = summary.totalTransactions == 0
        ? 0.0
        : summary.totalFeesCollected / summary.totalTransactions;
    final monthly = summary.monthlyCollections;
    final peak = monthly.isEmpty
        ? null
        : monthly.reduce((a, b) => a.amount >= b.amount ? a : b);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, constraints) {
        final columns = Responsive.isDesktop(context)
            ? 4
            : constraints.maxWidth > 720
                ? 2
                : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        final cards = [
          AdminMetricCard(
            title: 'Students',
            value: '${summary.totalStudents}',
            icon: Icons.people_alt_outlined,
            color: context.palette.brand,
            caption: 'Enrolled',
          ),
          AdminMetricCard(
            title: 'Collected',
            value: _currency.format(summary.totalFeesCollected),
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.success,
            caption: '${summary.totalTransactions} transactions',
          ),
          AdminMetricCard(
            title: 'Outstanding',
            value: _currency.format(summary.totalFeesDue),
            icon: Icons.pending_actions_outlined,
            color: AppColors.error,
            caption:
                '${((1 - coverage) * 100).clamp(0, 100).toStringAsFixed(0)}% pending',
          ),
          AdminMetricCard(
            title: 'Avg Transaction',
            value: _currency.format(averageTransaction),
            icon: Icons.receipt_long_outlined,
            color: AppColors.warning,
            caption: peak == null ? 'No peak yet' : 'Peak ${peak.label}',
          ),
        ];
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children:
              cards.map((card) => SizedBox(width: width, child: card)).toList(),
        );
      }),
      const SizedBox(height: 16),
      _insightStrip(summary, coverage, peak),
      const SizedBox(height: 16),
      _monthlyCollectionCard(monthly),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 940;
        if (!wide) {
          return Column(children: [
            _feeHealthCard(summary, coverage),
            const SizedBox(height: 16),
            _enrollmentCard(summary),
            const SizedBox(height: 16),
            _paymentModesCard(summary),
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _feeHealthCard(summary, coverage)),
          const SizedBox(width: 16),
          Expanded(child: _enrollmentCard(summary)),
          const SizedBox(width: 16),
          Expanded(child: _paymentModesCard(summary)),
        ]);
      }),
      const SizedBox(height: 70),
    ]);
  }

  Widget _insightStrip(
    SchoolSummary summary,
    double coverage,
    MonthlyFeeSummary? peak,
  ) {
    final dueRatio = (1 - coverage).clamp(0.0, 1.0);
    final insights = [
      _Insight(
        label: 'Collection Coverage',
        value: '${(coverage * 100).toStringAsFixed(0)}%',
        note: 'Collected against fee demand',
        icon: Icons.verified_outlined,
        color: coverage >= 0.75 ? AppColors.success : AppColors.warning,
      ),
      _Insight(
        label: 'Due Pressure',
        value: '${(dueRatio * 100).toStringAsFixed(0)}%',
        note: summary.totalFeesDue <= 0
            ? 'No pending amount'
            : _currency.format(summary.totalFeesDue),
        icon: Icons.warning_amber_rounded,
        color: dueRatio >= 0.35 ? AppColors.error : AppColors.info,
      ),
      _Insight(
        label: 'Discount Given',
        value: _currency.format(summary.totalDiscountGiven),
        note: 'Total concession tracked',
        icon: Icons.discount_outlined,
        color: AppColors.warning,
      ),
      _Insight(
        label: 'Peak Month',
        value: peak?.label ?? 'No data',
        note: peak == null ? 'No payments yet' : _currency.format(peak.amount),
        icon: Icons.trending_up_rounded,
        color: context.palette.brand,
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 860 ? 4 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: insights
            .map((insight) =>
                SizedBox(width: width, child: _insightCard(insight)))
            .toList(),
      );
    });
  }

  Widget _insightCard(_Insight insight) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: insight.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            ),
            child: Icon(insight.icon, color: insight.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                insight.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                insight.label,
                style: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                insight.note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  color: insight.color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _monthlyCollectionCard(List<MonthlyFeeSummary> monthly) {
    final maxAmount = monthly.isEmpty
        ? 1.0
        : monthly.map((item) => item.amount).reduce((a, b) => a > b ? a : b);
    final axisInterval = maxAmount <= 0 ? 1.0 : maxAmount / 4;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cardHeader(
            title: 'Monthly Collection Trend',
            subtitle: monthly.isEmpty
                ? 'No payment records found'
                : '${monthly.length} month(s) of fee data',
            icon: Icons.bar_chart_rounded,
            color: context.palette.brand,
          ),
          const SizedBox(height: 18),
          if (monthly.isEmpty)
            _noData('No payment transactions recorded yet')
          else
            SizedBox(
              height: 270,
              child: BarChart(
                BarChartData(
                  maxY: maxAmount <= 0 ? 1 : maxAmount * 1.2,
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: axisInterval,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: AppColors.border, strokeWidth: 1),
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 58,
                        interval: axisInterval,
                        getTitlesWidget: (value, _) => Text(
                          _shortMoney(value),
                          style: GoogleFonts.nunitoSans(
                            color: AppColors.textLight,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index < 0 || index >= monthly.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              monthly[index].label,
                              style: GoogleFonts.nunitoSans(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: monthly.asMap().entries.map((entry) {
                    final item = entry.value;
                    final isPeak = item.amount == maxAmount;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: item.amount,
                          width: 18,
                          color: isPeak
                              ? AppColors.warning
                              : context.palette.brand,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _feeHealthCard(SchoolSummary summary, double coverage) {
    final total = summary.totalFeesCollected + summary.totalFeesDue;
    final duePct = total <= 0 ? 0.0 : summary.totalFeesDue / total;
    final discountPct = total <= 0 ? 0.0 : summary.totalDiscountGiven / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cardHeader(
            title: 'Fee Health',
            subtitle: 'Collected, due and discount split',
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.success,
          ),
          const SizedBox(height: 16),
          _progressRow(
            label: 'Collected',
            value: summary.totalFeesCollected,
            percent: coverage,
            color: AppColors.success,
          ),
          const SizedBox(height: 14),
          _progressRow(
            label: 'Outstanding',
            value: summary.totalFeesDue,
            percent: duePct,
            color: AppColors.error,
          ),
          const SizedBox(height: 14),
          _progressRow(
            label: 'Discount',
            value: summary.totalDiscountGiven,
            percent: discountPct,
            color: AppColors.warning,
          ),
        ]),
      ),
    );
  }

  Widget _enrollmentCard(SchoolSummary summary) {
    final entries = summary.enrollmentByClass.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);
    final colors = [
      context.palette.brand,
      AppColors.info,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      const Color(0xFF7C3AED),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cardHeader(
            title: 'Enrollment Mix',
            subtitle: '$total students across classes',
            icon: Icons.groups_outlined,
            color: AppColors.info,
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            _noData('No student records found')
          else ...[
            SizedBox(
              height: 170,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 34,
                  sections: entries.asMap().entries.map((entry) {
                    final percent =
                        total <= 0 ? 0.0 : entry.value.value / total * 100;
                    return PieChartSectionData(
                      value: entry.value.value.toDouble(),
                      color: colors[entry.key % colors.length],
                      title: '${percent.toStringAsFixed(0)}%',
                      radius: 62,
                      titleStyle: GoogleFonts.nunitoSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...entries.take(6).toList().asMap().entries.map((entry) {
              final color = colors[entry.key % colors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _legendRow(
                  entry.value.key,
                  '${entry.value.value}',
                  color,
                ),
              );
            }),
          ],
        ]),
      ),
    );
  }

  Widget _paymentModesCard(SchoolSummary summary) {
    final modes = summary.paymentModeSummary;
    final total = modes.fold<double>(0, (sum, mode) => sum + mode.totalAmount);
    final colors = {
      'CASH': AppColors.success,
      'CHEQUE': AppColors.info,
      'DIGITAL_PAYMENT': context.palette.brand,
      'CHALLAN': AppColors.warning,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cardHeader(
            title: 'Payment Modes',
            subtitle: 'How fees are coming in',
            icon: Icons.payments_outlined,
            color: AppColors.warning,
          ),
          const SizedBox(height: 16),
          if (modes.isEmpty)
            _noData('No payment mode data')
          else
            ...modes.map((mode) {
              final percent = total <= 0 ? 0.0 : mode.totalAmount / total;
              final color =
                  colors[mode.paymentMode.toUpperCase()] ?? AppColors.info;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _progressRow(
                  label: _modeLabel(mode.paymentMode),
                  value: mode.totalAmount,
                  percent: percent,
                  color: color,
                ),
              );
            }),
        ]),
      ),
    );
  }

  Widget _cardHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            title,
            style: GoogleFonts.nunitoSans(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _progressRow({
    required String label,
    required double value,
    required double percent,
    required Color color,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          _currency.format(value),
          style: GoogleFonts.nunitoSans(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(percent * 100).clamp(0, 999).toStringAsFixed(1)}%',
          style: GoogleFonts.nunitoSans(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: percent.clamp(0, 1),
          minHeight: 7,
          backgroundColor: color.withValues(alpha: 0.12),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }

  Widget _legendRow(String label, String value, Color color) {
    return Row(children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.nunitoSans(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
      Text(
        value,
        style: GoogleFonts.nunitoSans(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    ]);
  }

  Widget _noData(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Center(
        child: Column(children: [
          Icon(Icons.inbox_outlined,
              size: 44, color: AppColors.textLight.withValues(alpha: 0.45)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _errorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded,
                size: 52, color: AppColors.warning),
            const SizedBox(height: 12),
            Text(
              'Failed to load report',
              style: GoogleFonts.nunitoSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Retry'),
            ),
          ]),
        ),
      ),
    );
  }

  String _shortMoney(double value) {
    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }

  String _modeLabel(String mode) => switch (mode.toUpperCase()) {
        'CASH' => 'Cash',
        'CHEQUE' => 'Cheque',
        'DIGITAL_PAYMENT' => 'Digital Payment',
        'CHALLAN' => 'Challan',
        _ => mode,
      };
}

class _Insight {
  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;

  const _Insight({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
  });
}
