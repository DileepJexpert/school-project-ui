import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';

class FeeReportsScreen extends StatefulWidget {
  const FeeReportsScreen({super.key});

  @override
  State<FeeReportsScreen> createState() => _FeeReportsScreenState();
}

class _FeeReportsScreenState extends State<FeeReportsScreen> {
  FeeReportResponse? _report;
  bool _loading = false;
  String? _error;
  DateTimeRange? _range;
  String? _classFilter;
  String? _modeFilter;
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  final _dateFmt = DateFormat('dd MMM yyyy');

  final _classes = ['All Classes', 'Class 9 A', 'Class 10 A', 'Class 11 Science', 'Class 12 Science'];
  final _modes = ['All Modes', 'CASH', 'CHEQUE', 'DIGITAL_PAYMENT', 'CHALLAN'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await FeeApiService.getFeeReport(
        startDate: _range?.start.toIso8601String().substring(0, 10),
        endDate: _range?.end.toIso8601String().substring(0, 10),
        className: (_classFilter == null || _classFilter == 'All Classes') ? null : _classFilter,
        paymentMode: (_modeFilter == null || _modeFilter == 'All Modes') ? null : _modeFilter,
      );
      setState(() => _report = r);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.navy),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _range = picked);
      _fetchReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text('Fee Reports',
            style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReport,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Filters
          _buildFilters(),
          const SizedBox(height: 20),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Center(child: Text(_error!, style: GoogleFonts.nunitoSans(color: AppColors.error))),
          if (_report != null) ...[
            // Summary cards
            _buildSummaryCards(_report!.summary),
            const SizedBox(height: 24),
            // Charts row
            LayoutBuilder(builder: (ctx, constraints) {
              final wide = constraints.maxWidth > 700;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildBarChart(_report!.classSummaries)),
                    const SizedBox(width: 16),
                    SizedBox(width: 240, child: _buildPieChart(_report!.paymentModeSummary)),
                  ],
                );
              }
              return Column(children: [
                _buildBarChart(_report!.classSummaries),
                const SizedBox(height: 16),
                _buildPieChart(_report!.paymentModeSummary),
              ]);
            }),
            const SizedBox(height: 24),
            // Transaction table
            _buildTransactionTable(_report!.transactions),
          ],
        ]),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          // Date range
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(
              _range != null
                  ? '${_dateFmt.format(_range!.start)} – ${_dateFmt.format(_range!.end)}'
                  : 'Select Date Range',
              style: GoogleFonts.nunitoSans(fontSize: 13),
            ),
            onPressed: _pickRange,
          ),
          // Class filter
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              value: _classFilter ?? 'All Classes',
              decoration: InputDecoration(
                labelText: 'Class',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                isDense: true,
              ),
              items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.nunitoSans(fontSize: 13)))).toList(),
              onChanged: (v) { setState(() => _classFilter = v); _fetchReport(); },
            ),
          ),
          // Mode filter
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String>(
              value: _modeFilter ?? 'All Modes',
              decoration: InputDecoration(
                labelText: 'Payment Mode',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                isDense: true,
              ),
              items: _modes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: GoogleFonts.nunitoSans(fontSize: 13)))).toList(),
              onChanged: (v) { setState(() => _modeFilter = v); _fetchReport(); },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSummaryCards(FeeReportSummary s) {
    final cards = [
      _SummaryCard('Total Collected', _currency.format(s.totalCollected), Icons.account_balance_wallet, AppColors.success),
      _SummaryCard('Total Due', _currency.format(s.totalDue), Icons.pending_actions, AppColors.error),
      _SummaryCard('Total Discount', _currency.format(s.totalDiscountGiven), Icons.discount, AppColors.warning),
      _SummaryCard('Transactions', '${s.totalTransactions}', Icons.receipt_long, AppColors.navy),
    ];
    return LayoutBuilder(builder: (ctx, constraints) {
      final cols = constraints.maxWidth > 700 ? 4 : 2;
      final w = (constraints.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards.map((c) => SizedBox(width: w, child: _buildSummaryCard(c))).toList(),
      );
    });
  }

  Widget _buildSummaryCard(_SummaryCard c) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: c.color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
            child: Icon(c.icon, color: c.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.value,
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(c.label,
                  style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildBarChart(List<ClassWiseFeeSummary> data) {
    if (data.isEmpty) return const SizedBox();
    final maxVal = data.fold<double>(0, (m, c) => c.totalCollected > m ? c.totalCollected : m);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Collection by Class',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy)),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                maxY: maxVal * 1.2,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 56,
                      getTitlesWidget: (v, _) => Text(
                        _currency.format(v),
                        style: GoogleFonts.nunitoSans(color: AppColors.textLight, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= data.length) return const SizedBox();
                        final label = data[idx].className;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            label.length > 8 ? label.substring(0, 8) : label,
                            style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: data.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.totalCollected,
                        color: AppColors.navy,
                        width: 18,
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
    );
  }

  Widget _buildPieChart(List<PaymentModeSummary> data) {
    if (data.isEmpty) return const SizedBox();
    final total = data.fold<double>(0, (s, m) => s + m.totalAmount);
    final colors = [AppColors.navy, AppColors.gold, AppColors.info, AppColors.success, AppColors.warning];
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Payment Modes',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sections: data.asMap().entries.map((e) {
                  final pct = total > 0 ? (e.value.totalAmount / total * 100) : 0.0;
                  return PieChartSectionData(
                    value: e.value.totalAmount,
                    color: colors[e.key % colors.length],
                    title: '${pct.toStringAsFixed(1)}%',
                    titleStyle: GoogleFonts.nunitoSans(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                    radius: 60,
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...data.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                        color: colors[e.key % colors.length], shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.value.paymentMode,
                        style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12)),
                  ),
                  Text(_currency.format(e.value.totalAmount),
                      style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600, fontSize: 12)),
                ]),
              )),
        ]),
      ),
    );
  }

  Widget _buildTransactionTable(List<TransactionRecord> transactions) {
    if (transactions.isEmpty) return const SizedBox();
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      clipBehavior: Clip.antiAlias,
      child: PaginatedDataTable(
        header: Text('Recent Transactions',
            style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, color: AppColors.navy)),
        rowsPerPage: 10,
        columns: ['Date', 'Receipt', 'Student', 'Class', 'Amount', 'Discount', 'Mode']
            .map((h) => DataColumn(
                label: Text(h,
                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 12))))
            .toList(),
        source: _TxnDataSource(transactions, _currency, _dateFmt),
      ),
    );
  }
}

class _TxnDataSource extends DataTableSource {
  final List<TransactionRecord> data;
  final NumberFormat currency;
  final DateFormat dateFmt;
  _TxnDataSource(this.data, this.currency, this.dateFmt);

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final t = data[index];
    return DataRow(cells: [
      DataCell(Text(dateFmt.format(t.paymentDate),
          style: GoogleFonts.nunitoSans(fontSize: 12))),
      DataCell(Text(t.receiptNumber,
          style: GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.w600))),
      DataCell(Text(t.studentName, style: GoogleFonts.nunitoSans(fontSize: 12))),
      DataCell(Text(t.className, style: GoogleFonts.nunitoSans(fontSize: 12))),
      DataCell(Text(currency.format(t.amountPaid),
          style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600))),
      DataCell(Text(currency.format(t.discount),
          style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.warning))),
      DataCell(Text(t.paymentMode, style: GoogleFonts.nunitoSans(fontSize: 12))),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => data.length;
  @override
  int get selectedRowCount => 0;
}

class _SummaryCard {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard(this.label, this.value, this.icon, this.color);
}
