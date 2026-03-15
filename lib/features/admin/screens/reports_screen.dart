import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  SchoolSummary? _summary;
  bool _loading = true;
  String? _error;

  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await FeeApiService.getSchoolSummary();
      setState(() => _summary = summary);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off, size: 60, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text('Failed to load report',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 8),
          Text(_error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white),
          ),
        ]),
      );

  Widget _buildContent() {
    final s = _summary!;
    final monthly = s.monthlyCollections;
    final maxAmount = monthly.isEmpty
        ? 1.0
        : monthly.map((m) => m.amount).reduce((a, b) => a > b ? a : b);
    final peakMonth = monthly.isEmpty
        ? '—'
        : monthly.reduce((a, b) => a.amount > b.amount ? a : b).label;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('School Reports',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              Text('Live data from all school modules',
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary, fontSize: 13)),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.navy),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ]),
        const SizedBox(height: 20),

        // ── Summary stat tiles ──
        LayoutBuilder(builder: (ctx, constraints) {
          final cols = constraints.maxWidth > 700 ? 4 : 2;
          final w = (constraints.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
              width: w,
              child: _statTile(
                label: 'Total Students',
                value: '${s.totalStudents}',
                icon: Icons.people_alt_rounded,
                color: AppColors.navy,
                sub: 'enrolled',
              ),
            ),
            SizedBox(
              width: w,
              child: _statTile(
                label: 'Total Collected',
                value: _currency.format(s.totalFeesCollected),
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.success,
                sub: '${s.totalTransactions} transactions',
              ),
            ),
            SizedBox(
              width: w,
              child: _statTile(
                label: 'Outstanding Due',
                value: _currency.format(s.totalFeesDue),
                icon: Icons.warning_amber_rounded,
                color: AppColors.error,
                sub: 'pending collection',
              ),
            ),
            SizedBox(
              width: w,
              child: _statTile(
                label: 'Peak Month',
                value: peakMonth,
                icon: Icons.trending_up_rounded,
                color: AppColors.gold,
                sub: monthly.isEmpty
                    ? 'no data'
                    : _currency.format(monthly
                        .reduce((a, b) => a.amount > b.amount ? a : b)
                        .amount),
              ),
            ),
          ]);
        }),

        const SizedBox(height: 24),

        // ── Monthly fee collection bar chart ──
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Monthly Fee Collection',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              const SizedBox(height: 4),
              Text(
                monthly.isEmpty
                    ? 'No payment records found'
                    : '${monthly.length} months of data',
                style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
              monthly.isEmpty
                  ? _buildNoData('No payment transactions recorded yet')
                  : SizedBox(
                      height: 260,
                      child: BarChart(
                        BarChartData(
                          maxY: maxAmount * 1.2,
                          gridData: FlGridData(
                            show: true,
                            horizontalInterval: maxAmount / 5,
                            getDrawingHorizontalLine: (v) => const FlLine(
                                color: AppColors.border, strokeWidth: 1),
                            drawVerticalLine: false,
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 60,
                                interval: maxAmount / 5,
                                getTitlesWidget: (v, _) => Text(
                                  v >= 100000
                                      ? '₹${(v / 1000).toStringAsFixed(0)}K'
                                      : '₹${v.toStringAsFixed(0)}',
                                  style: GoogleFonts.nunitoSans(
                                      color: AppColors.textLight,
                                      fontSize: 10),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, _) {
                                  final idx = v.toInt();
                                  if (idx < 0 || idx >= monthly.length) {
                                    return const SizedBox();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      monthly[idx].label,
                                      style: GoogleFonts.nunitoSans(
                                          color: AppColors.textSecondary,
                                          fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(
                                sideTitles:
                                    SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles:
                                    SideTitles(showTitles: false)),
                          ),
                          barGroups: monthly.asMap().entries.map((e) {
                            final isMax =
                                e.value.amount == maxAmount;
                            return BarChartGroupData(
                              x: e.key,
                              barRods: [
                                BarChartRodData(
                                  toY: e.value.amount,
                                  gradient: LinearGradient(
                                    colors: isMax
                                        ? [
                                            AppColors.gold
                                                .withOpacity(0.8),
                                            AppColors.gold
                                          ]
                                        : [
                                            AppColors.navyLight,
                                            AppColors.navy
                                          ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  width: 18,
                                  borderRadius:
                                      const BorderRadius.vertical(
                                          top: Radius.circular(4)),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ]),
          ),
        ),

        const SizedBox(height: 16),

        // ── Enrollment + Fee Breakdown row ──
        LayoutBuilder(builder: (ctx, constraints) {
          final wide = constraints.maxWidth > 600;
          return wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildEnrollmentChart(s)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildFeeBreakdownCard(s)),
                  ],
                )
              : Column(children: [
                  _buildEnrollmentChart(s),
                  const SizedBox(height: 16),
                  _buildFeeBreakdownCard(s),
                ]);
        }),

        const SizedBox(height: 16),

        // ── Payment mode breakdown ──
        _buildPaymentModeCard(s),

        const SizedBox(height: 80),
      ]),
    );
  }

  // ── Stat tile ─────────────────────────────────────────────────────────────

  Widget _statTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required String sub,
  }) =>
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text(label,
                        style: GoogleFonts.nunitoSans(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    Text(sub,
                        style: GoogleFonts.nunitoSans(
                            color: AppColors.textLight, fontSize: 10)),
                  ]),
            ),
          ]),
        ),
      );

  // ── Enrollment pie chart ──────────────────────────────────────────────────

  Widget _buildEnrollmentChart(SchoolSummary s) {
    final enrollment = s.enrollmentByClass;
    final colors = [
      AppColors.navy,
      AppColors.gold,
      AppColors.info,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      AppColors.navyLight,
    ];
    final entries = enrollment.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total =
        entries.fold<int>(0, (sum, e) => sum + e.value);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Enrollment by Class',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text('$total students total',
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          enrollment.isEmpty
              ? _buildNoData('No student records found')
              : Column(children: [
                  SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sections: entries.asMap().entries.map((e) {
                          final pct =
                              total > 0 ? e.value.value / total * 100 : 0.0;
                          return PieChartSectionData(
                            value: e.value.value.toDouble(),
                            color: colors[e.key % colors.length],
                            title:
                                '${pct.toStringAsFixed(0)}%',
                            titleStyle: GoogleFonts.nunitoSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11),
                            radius: 70,
                          );
                        }).toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...entries.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                                color: colors[e.key % colors.length],
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(e.value.key,
                                style: GoogleFonts.nunitoSans(
                                    fontSize: 13,
                                    color: AppColors.textSecondary)),
                          ),
                          Text('${e.value.value}',
                              style: GoogleFonts.nunitoSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.textPrimary)),
                        ]),
                      )),
                ]),
        ]),
      ),
    );
  }

  // ── Fee collected vs due breakdown ───────────────────────────────────────

  Widget _buildFeeBreakdownCard(SchoolSummary s) {
    final total = s.totalFeesCollected + s.totalFeesDue;
    final collectedPct = total > 0 ? s.totalFeesCollected / total : 0.0;
    final duePct = total > 0 ? s.totalFeesDue / total : 0.0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Fee Collection Status',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text('Collected vs pending',
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 20),
          _progressRow(
              label: 'Collected',
              value: s.totalFeesCollected,
              pct: collectedPct,
              color: AppColors.success),
          const SizedBox(height: 14),
          _progressRow(
              label: 'Outstanding',
              value: s.totalFeesDue,
              pct: duePct,
              color: AppColors.error),
          const SizedBox(height: 14),
          _progressRow(
              label: 'Discount Given',
              value: s.totalDiscountGiven,
              pct: total > 0 ? s.totalDiscountGiven / total : 0,
              color: AppColors.warning),
          const Divider(height: 28),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total Transactions',
                style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary, fontSize: 13)),
            Text('${s.totalTransactions}',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
          ]),
        ]),
      ),
    );
  }

  Widget _progressRow({
    required String label,
    required double value,
    required double pct,
    required Color color,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.nunitoSans(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Text(_currency.format(value),
              style: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary)),
          const SizedBox(width: 8),
          Text('(${(pct * 100).toStringAsFixed(1)}%)',
              style: GoogleFonts.nunitoSans(
                  fontSize: 11, color: color)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ]);

  // ── Payment mode card ─────────────────────────────────────────────────────

  Widget _buildPaymentModeCard(SchoolSummary s) {
    final modes = s.paymentModeSummary;
    if (modes.isEmpty) return const SizedBox.shrink();

    final modeTotal =
        modes.fold<double>(0, (sum, m) => sum + m.totalAmount);
    final modeColors = {
      'CASH': AppColors.success,
      'CHEQUE': AppColors.info,
      'DIGITAL_PAYMENT': AppColors.navy,
      'CHALLAN': AppColors.warning,
    };

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Payment Mode Breakdown',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text('How fees were collected',
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ...modes.map((m) {
            final pct =
                modeTotal > 0 ? m.totalAmount / modeTotal : 0.0;
            final color =
                modeColors[m.paymentMode] ?? AppColors.textSecondary;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _progressRow(
                  label: _modeLabel(m.paymentMode),
                  value: m.totalAmount,
                  pct: pct,
                  color: color),
            );
          }),
        ]),
      ),
    );
  }

  String _modeLabel(String mode) => switch (mode.toUpperCase()) {
        'CASH' => 'Cash',
        'CHEQUE' => 'Cheque',
        'DIGITAL_PAYMENT' => 'Digital Payment',
        'CHALLAN' => 'Challan',
        _ => mode,
      };

  Widget _buildNoData(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: AppColors.textLight.withOpacity(0.4)),
            const SizedBox(height: 10),
            Text(msg,
                style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary, fontSize: 13)),
          ]),
        ),
      );
}
