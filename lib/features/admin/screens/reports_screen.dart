import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  static const _monthlyCollections = [
    _MonthData('Apr', 420000),
    _MonthData('May', 380000),
    _MonthData('Jun', 250000),
    _MonthData('Jul', 510000),
    _MonthData('Aug', 480000),
    _MonthData('Sep', 445000),
    _MonthData('Oct', 530000),
    _MonthData('Nov', 490000),
    _MonthData('Dec', 210000),
    _MonthData('Jan', 560000),
    _MonthData('Feb', 390000),
    _MonthData('Mar', 470000),
  ];

  static const _enrollmentData = [
    _ClassData('Class 9', 180),
    _ClassData('Class 10', 200),
    _ClassData('Class 11', 120),
    _ClassData('Class 12', 140),
  ];

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final totalCollection = _monthlyCollections.fold<double>(0, (s, m) => s + m.amount);
    final maxMonth = _monthlyCollections.reduce((a, b) => a.amount > b.amount ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('School Reports',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.navy)),
        const SizedBox(height: 4),
        Text('Annual overview — connect to Spring Boot APIs for live data.',
            style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 24),

        // Summary tiles
        LayoutBuilder(builder: (ctx, constraints) {
          final cols = constraints.maxWidth > 700 ? 4 : 2;
          final w = (constraints.maxWidth - (cols - 1) * 12) / cols;
          final tiles = [
            _Tile('Annual Collection', currency.format(totalCollection), Icons.account_balance_wallet, AppColors.success),
            _Tile('Total Students', '2,400', Icons.people_alt, AppColors.navy),
            _Tile('Staff Members', '180', Icons.badge, AppColors.info),
            _Tile('Peak Month', maxMonth.label, Icons.trending_up, AppColors.gold),
          ];
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: tiles.map((t) => SizedBox(width: w, child: _buildTile(t))).toList(),
          );
        }),

        const SizedBox(height: 24),

        // Monthly fee collection bar chart
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Monthly Fee Collection (2024–25)',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.navy)),
              const SizedBox(height: 4),
              Text('Sample data — wire to GET /api/fees/reports',
                  style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 20),
              SizedBox(
                height: 260,
                child: BarChart(
                  BarChartData(
                    maxY: 650000,
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: 100000,
                      getDrawingHorizontalLine: (v) => const FlLine(color: AppColors.border, strokeWidth: 1),
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 56,
                          interval: 100000,
                          getTitlesWidget: (v, _) => Text(
                            '₹${(v / 1000).toStringAsFixed(0)}K',
                            style: GoogleFonts.nunitoSans(color: AppColors.textLight, fontSize: 10),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= _monthlyCollections.length) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(_monthlyCollections[idx].label,
                                  style: GoogleFonts.nunitoSans(
                                      color: AppColors.textSecondary, fontSize: 10)),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    barGroups: _monthlyCollections.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.amount.toDouble(),
                            gradient: const LinearGradient(
                              colors: [AppColors.navyLight, AppColors.navy],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            width: 16,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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

        // Enrollment chart
        LayoutBuilder(builder: (ctx, constraints) {
          final wide = constraints.maxWidth > 600;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildEnrollmentChart()),
              if (wide) ...[
                const SizedBox(width: 16),
                Expanded(child: _buildQuickReports(context)),
              ],
            ],
          );
        }),

        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _buildTile(_Tile t) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: t.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            ),
            child: Icon(t.icon, color: t.color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.value,
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(t.label,
                  style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 11)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildEnrollmentChart() {
    final colors = [AppColors.navy, AppColors.gold, AppColors.info, AppColors.success];
    final total = _enrollmentData.fold<int>(0, (s, d) => s + d.count);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Enrollment by Class',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy)),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sections: _enrollmentData.asMap().entries.map((e) {
                  final pct = e.value.count / total * 100;
                  return PieChartSectionData(
                    value: e.value.count.toDouble(),
                    color: colors[e.key % colors.length],
                    title: '${pct.toStringAsFixed(0)}%',
                    titleStyle: GoogleFonts.nunitoSans(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                    radius: 70,
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 24,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._enrollmentData.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                        color: colors[e.key % colors.length], shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.value.label,
                        style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.textSecondary)),
                  ),
                  Text('${e.value.count}',
                      style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
                ]),
              )),
        ]),
      ),
    );
  }

  Widget _buildQuickReports(BuildContext context) {
    final reports = [
      _QuickReport('Fee Collection Summary', Icons.receipt_long, '/api/fees/reports/collection-summary'),
      _QuickReport('Student Attendance Report', Icons.rule_folder, '/api/attendance/report'),
      _QuickReport('Expense Summary', Icons.paid, '/api/expenses/report'),
      _QuickReport('Class-wise Results', Icons.assessment, '/api/results/class-report'),
    ];
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Quick Reports',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy)),
          const SizedBox(height: 12),
          ...reports.map((r) => ListTile(
                dense: true,
                leading: Icon(r.icon, color: AppColors.navy, size: 20),
                title: Text(r.label, style: GoogleFonts.nunitoSans(fontSize: 14)),
                subtitle: Text(r.endpoint,
                    style: GoogleFonts.nunitoSans(color: AppColors.textLight, fontSize: 11)),
                trailing: const Icon(Icons.download_outlined, size: 18, color: AppColors.textLight),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('GET ${r.endpoint}'),
                      backgroundColor: AppColors.navy),
                ),
              )),
        ]),
      ),
    );
  }
}

class _MonthData {
  final String label;
  final int amount;
  const _MonthData(this.label, this.amount);
}

class _ClassData {
  final String label;
  final int count;
  const _ClassData(this.label, this.count);
}

class _Tile {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Tile(this.label, this.value, this.icon, this.color);
}

class _QuickReport {
  final String label;
  final IconData icon;
  final String endpoint;
  const _QuickReport(this.label, this.icon, this.endpoint);
}
