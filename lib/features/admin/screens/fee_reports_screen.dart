import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
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
  String _classFilter = 'All Classes';
  String _modeFilter = 'All Modes';

  final _currency = NumberFormat.currency(symbol: '\u20B9', decimalDigits: 0);
  final _dateFmt = DateFormat('dd MMM yyyy');

  List<String> get _classes => ['All Classes', ...SchoolConstants.allClasses];
  final _modes = ['All Modes', 'CASH', 'CHEQUE', 'DIGITAL_PAYMENT', 'CHALLAN'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await FeeApiService.getFeeReport(
        startDate: _range?.start.toIso8601String().substring(0, 10),
        endDate: _range?.end.toIso8601String().substring(0, 10),
        className: _classFilter == 'All Classes' ? null : _classFilter,
        paymentMode: _modeFilter == 'All Modes' ? null : _modeFilter,
      );
      if (mounted) setState(() => _report = report);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
                  primary: context.palette.brand,
                  surface: context.palette.surface,
                ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
              child: child!,
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _range = picked);
      _fetchReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.canvas,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: context.palette.border)),
        title: Text(
          'Fee Reports',
          style: GoogleFonts.nunitoSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _fetchReport,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchReport,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildHeader(),
            const SizedBox(height: 14),
            _buildFilters(),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 42),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _buildError()
            else if (_report != null)
              _buildReport(_report!),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: context.palette.heroGradient,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppSizes.radiusLG),
          ),
          child: const Icon(Icons.insights_rounded, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Fee Intelligence',
              style: GoogleFonts.nunitoSans(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Collections, discounts, payment modes and receipts.',
              style: GoogleFonts.nunitoSans(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(
                _range == null
                    ? 'Select Date Range'
                    : '${_dateFmt.format(_range!.start)} - ${_dateFmt.format(_range!.end)}',
                style: GoogleFonts.nunitoSans(fontSize: 13),
              ),
              onPressed: _pickRange,
            ),
            _filterDropdown(
              label: 'Class',
              value: _classFilter,
              items: _classes,
              width: 170,
              onChanged: (value) {
                setState(() => _classFilter = value ?? 'All Classes');
                _fetchReport();
              },
            ),
            _filterDropdown(
              label: 'Payment Mode',
              value: _modeFilter,
              items: _modes,
              width: 190,
              onChanged: (value) {
                setState(() => _modeFilter = value ?? 'All Modes');
                _fetchReport();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required double width,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          isDense: true,
        ),
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item.replaceAll('_', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(fontSize: 13),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildError() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.nunitoSans(color: AppColors.error),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildReport(FeeReportResponse report) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSummaryCards(report.summary),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 7, child: _buildBarChart(report.classSummaries)),
            const SizedBox(width: 14),
            Expanded(flex: 4, child: _buildPieChart(report.paymentModeSummary)),
          ]);
        }
        return Column(children: [
          _buildBarChart(report.classSummaries),
          const SizedBox(height: 14),
          _buildPieChart(report.paymentModeSummary),
        ]);
      }),
      const SizedBox(height: 16),
      _buildTransactionTable(report.transactions),
    ]);
  }

  Widget _buildSummaryCards(FeeReportSummary summary) {
    final cards = [
      _SummaryCard('Collected', _currency.format(summary.totalCollected),
          Icons.account_balance_wallet, AppColors.success),
      _SummaryCard('Due', _currency.format(summary.totalDue),
          Icons.pending_actions, AppColors.error),
      _SummaryCard('Discount', _currency.format(summary.totalDiscountGiven),
          Icons.discount, AppColors.warning),
      _SummaryCard('Transactions', '${summary.totalTransactions}',
          Icons.receipt_long, AppColors.navy),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 860
          ? 4
          : constraints.maxWidth > 520
              ? 2
              : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards
            .map((card) => SizedBox(width: width, child: _statCard(card)))
            .toList(),
      );
    });
  }

  Widget _statCard(_SummaryCard card) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: card.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            ),
            child: Icon(card.icon, color: card.color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                card.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                card.label,
                style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildBarChart(List<ClassWiseFeeSummary> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle('Collection by Class', Icons.bar_chart_rounded),
          const SizedBox(height: 14),
          if (data.isEmpty)
            _emptyState('No class-wise collection in this period.')
          else
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  maxY: data.fold<double>(
                          0,
                          (m, c) =>
                              c.totalCollected > m ? c.totalCollected : m) *
                      1.2,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: context.palette.border, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 56,
                        getTitlesWidget: (value, _) => Text(
                          _currency.format(value),
                          style: GoogleFonts.nunitoSans(
                              color: AppColors.textLight, fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length) {
                            return const SizedBox.shrink();
                          }
                          final label = data[index].className;
                          return Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              label.length > 10
                                  ? label.substring(0, 10)
                                  : label,
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
                  barGroups: data.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.totalCollected,
                          color: context.palette.brand,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
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

  Widget _buildPieChart(List<PaymentModeSummary> data) {
    final total = data.fold<double>(0, (sum, item) => sum + item.totalAmount);
    final colors = [
      AppColors.navy,
      AppColors.gold,
      AppColors.info,
      AppColors.success,
      AppColors.warning,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle('Payment Modes', Icons.donut_large_rounded),
          const SizedBox(height: 14),
          if (data.isEmpty)
            _emptyState('No payment mode data in this period.')
          else ...[
            SizedBox(
              height: 170,
              child: PieChart(
                PieChartData(
                  sections: data.asMap().entries.map((entry) {
                    final percent =
                        total > 0 ? entry.value.totalAmount / total * 100 : 0.0;
                    return PieChartSectionData(
                      value: entry.value.totalAmount,
                      color: colors[entry.key % colors.length],
                      title: '${percent.toStringAsFixed(1)}%',
                      titleStyle: GoogleFonts.nunitoSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                      radius: 62,
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 34,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...data.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[entry.key % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value.paymentMode.replaceAll('_', ' '),
                      style: GoogleFonts.nunitoSans(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _currency.format(entry.value.totalAmount),
                    style: GoogleFonts.nunitoSans(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ]),
              );
            }),
          ],
        ]),
      ),
    );
  }

  Widget _buildTransactionTable(List<TransactionRecord> transactions) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle('Recent Transactions', Icons.receipt_long_rounded),
          const SizedBox(height: 10),
          if (transactions.isEmpty)
            _emptyState('No transactions in this period.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 920,
                child: PaginatedDataTable(
                  headingRowHeight: 42,
                  dataRowMinHeight: 42,
                  dataRowMaxHeight: 48,
                  rowsPerPage:
                      transactions.length < 10 ? transactions.length : 10,
                  columns: [
                    'Date',
                    'Receipt',
                    'Student',
                    'Class',
                    'Amount',
                    'Discount',
                    'Mode',
                  ]
                      .map(
                        (header) => DataColumn(
                          label: Text(
                            header,
                            style: GoogleFonts.nunitoSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  source: _TxnDataSource(transactions, _currency, _dateFmt),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(children: [
      Icon(icon, color: AppColors.navy, size: 19),
      const SizedBox(width: 8),
      Text(
        title,
        style: GoogleFonts.nunitoSans(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: AppColors.navy,
        ),
      ),
    ]);
  }

  Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.canvas,
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        border: Border.all(color: context.palette.border),
      ),
      child: Text(
        message,
        style: GoogleFonts.nunitoSans(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
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
    final record = data[index];
    return DataRow(cells: [
      DataCell(Text(dateFmt.format(record.paymentDate),
          style: GoogleFonts.nunitoSans(fontSize: 12))),
      DataCell(Text(record.receiptNumber,
          style: GoogleFonts.nunitoSans(
              fontSize: 12, fontWeight: FontWeight.w700))),
      DataCell(Text(record.studentName,
          style: GoogleFonts.nunitoSans(fontSize: 12))),
      DataCell(
          Text(record.className, style: GoogleFonts.nunitoSans(fontSize: 12))),
      DataCell(Text(currency.format(record.amountPaid),
          style: GoogleFonts.nunitoSans(
              fontSize: 12,
              color: AppColors.success,
              fontWeight: FontWeight.w800))),
      DataCell(Text(currency.format(record.discount),
          style:
              GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.warning))),
      DataCell(Text(record.paymentMode.replaceAll('_', ' '),
          style: GoogleFonts.nunitoSans(fontSize: 12))),
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
