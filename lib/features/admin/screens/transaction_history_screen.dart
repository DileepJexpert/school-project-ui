import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final _searchCtrl = TextEditingController();
  late final _TxnSource _source;

  List<TransactionRecord> _all = [];
  List<TransactionRecord> _filtered = [];
  bool _loading = true;
  String _error = '';
  DateTimeRange? _range;
  String _preset = '30D';
  String _modeFilter = 'ALL';

  final _currency = NumberFormat.currency(symbol: '\u20B9', decimalDigits: 0);
  final _dateFmt = DateFormat('dd MMM yyyy');
  final _shortFmt = DateFormat('dd MMM');

  static const _modes = {
    'ALL': 'All',
    'CASH': 'Cash',
    'CHEQUE': 'Cheque',
    'DIGITAL_PAYMENT': 'Digital',
    'CHALLAN': 'Challan',
  };
  static const _presets = ['7D', '30D', '3M', 'Year', 'Custom'];

  @override
  void initState() {
    super.initState();
    _source = _TxnSource([], _currency, _dateFmt);
    _range = _rangeFor('30D');
    _searchCtrl.addListener(_applySearch);
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applySearch);
    _searchCtrl.dispose();
    _source.dispose();
    super.dispose();
  }

  DateTimeRange _rangeFor(String preset) {
    final now = DateTime.now();
    return switch (preset) {
      '7D' => DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        ),
      '30D' => DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        ),
      '3M' => DateTimeRange(
          start: DateTime(now.year, now.month - 2, 1),
          end: now,
        ),
      'Year' => DateTimeRange(start: DateTime(now.year, 1, 1), end: now),
      _ => _range ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    };
  }

  String get _rangeLabel {
    if (_range == null) return 'Select dates';
    return '${_shortFmt.format(_range!.start)} - ${_shortFmt.format(_range!.end)}';
  }

  double get _totalCollected =>
      _filtered.fold(0, (sum, t) => sum + t.amountPaid);
  double get _totalDiscount => _filtered.fold(0, (sum, t) => sum + t.discount);

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final report = await FeeApiService.getFeeReport(
        startDate: _range?.start.toIso8601String().substring(0, 10),
        endDate: _range?.end.toIso8601String().substring(0, 10),
        paymentMode: _modeFilter == 'ALL' ? null : _modeFilter,
      );
      if (!mounted) return;
      _all = report.transactions;
      _applySearch();
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load transactions: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySearch() {
    if (!mounted) return;
    final query = _searchCtrl.text.trim().toLowerCase();
    final results = query.isEmpty
        ? List<TransactionRecord>.from(_all)
        : _all
            .where((t) =>
                t.studentName.toLowerCase().contains(query) ||
                t.receiptNumber.toLowerCase().contains(query) ||
                t.className.toLowerCase().contains(query))
            .toList();
    setState(() => _filtered = results);
    _source.updateData(results);
  }

  Future<void> _pickCustomRange() async {
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
      setState(() {
        _range = picked;
        _preset = 'Custom';
      });
      _fetch();
    }
  }

  void _selectPreset(String preset) {
    if (preset == 'Custom') {
      _pickCustomRange();
      return;
    }
    setState(() {
      _preset = preset;
      _range = _rangeFor(preset);
    });
    _fetch();
  }

  void _selectMode(String mode) {
    setState(() => _modeFilter = mode);
    _fetch();
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
          'Transaction History',
          style: GoogleFonts.nunitoSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _fetch,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(children: [
        _buildFilterPanel(),
        if (!_loading && _error.isEmpty && _all.isNotEmpty)
          _buildSummaryStrip(),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border(bottom: BorderSide(color: context.palette.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search name, receipt or class...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                isDense: true,
                filled: true,
                fillColor: context.palette.canvas,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _rangeChip(),
        ]),
        const SizedBox(height: 12),
        _chipRow(
          label: 'Period:',
          children: _presets.map((preset) {
            return _choiceChip(
              label: preset,
              active: _preset == preset,
              icon: preset == 'Custom' ? Icons.calendar_month_outlined : null,
              onTap: () => _selectPreset(preset),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        _chipRow(
          label: 'Mode:',
          trailing: _recordBadge(),
          children: _modes.entries.map((entry) {
            return _choiceChip(
              label: entry.value,
              active: _modeFilter == entry.key,
              accent: AppColors.gold,
              onTap: () => _selectMode(entry.key),
            );
          }).toList(),
        ),
      ]),
    );
  }

  Widget _rangeChip() {
    final active = _preset == 'Custom';
    return InkWell(
      onTap: _pickCustomRange,
      borderRadius: BorderRadius.circular(AppSizes.radiusMD),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: active ? context.palette.brand.withValues(alpha: 0.08) : null,
          border: Border.all(
            color: active ? context.palette.brand : context.palette.border,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            Icons.date_range_rounded,
            size: 16,
            color: active ? context.palette.brand : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            _rangeLabel,
            style: GoogleFonts.nunitoSans(
              fontSize: 12,
              color: active ? context.palette.brand : AppColors.textSecondary,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: active ? context.palette.brand : AppColors.textLight,
          ),
        ]),
      ),
    );
  }

  Widget _chipRow({
    required String label,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Row(children: [
      Text(
        label,
        style: GoogleFonts.nunitoSans(
          fontSize: 12,
          color: AppColors.textLight,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: children),
        ),
      ),
      if (trailing != null) ...[
        const SizedBox(width: 8),
        trailing,
      ],
    ]);
  }

  Widget _choiceChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    Color? accent,
    IconData? icon,
  }) {
    final activeColor = accent ?? context.palette.brand;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? activeColor.withValues(alpha: 0.13) : null,
            border: Border.all(
              color: active ? activeColor : context.palette.border,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: activeColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.nunitoSans(
                fontSize: 12,
                color: active ? AppColors.navy : AppColors.textSecondary,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _recordBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.palette.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
      ),
      child: Text(
        '${_filtered.length} records',
        style: GoogleFonts.nunitoSans(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: context.palette.brand,
        ),
      ),
    );
  }

  Widget _buildSummaryStrip() {
    final average = _filtered.isEmpty ? 0 : _totalCollected / _filtered.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth > 760 ? 4 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        final cards = [
          _StripStat('Total Collected', _currency.format(_totalCollected),
              Icons.account_balance_wallet_outlined, AppColors.success),
          _StripStat('Discount Given', _currency.format(_totalDiscount),
              Icons.discount_outlined, AppColors.warning),
          _StripStat('Transactions', '${_filtered.length}',
              Icons.receipt_long_outlined, context.palette.brand),
          _StripStat('Avg / Txn', _currency.format(average),
              Icons.trending_up_rounded, AppColors.info),
        ];
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards
              .map((stat) => SizedBox(width: width, child: _stripCard(stat)))
              .toList(),
        );
      }),
    );
  }

  Widget _stripCard(_StripStat stat) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            ),
            child: Icon(stat.icon, color: stat.color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                stat.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              Text(
                stat.label,
                style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) return _errorState();
    if (_filtered.isEmpty) return _emptyTransactions();
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite
          ? (constraints.maxWidth > 900 ? constraints.maxWidth - 32 : 900.0)
          : 900.0;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: PaginatedDataTable(
                rowsPerPage: _filtered.length < 15 ? _filtered.length : 15,
                showFirstLastButtons: true,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Receipt')),
                  DataColumn(label: Text('Student')),
                  DataColumn(label: Text('Class')),
                  DataColumn(label: Text('Installments')),
                  DataColumn(label: Text('Gross'), numeric: true),
                  DataColumn(label: Text('Discount'), numeric: true),
                  DataColumn(label: Text('Net'), numeric: true),
                  DataColumn(label: Text('Mode')),
                ],
                source: _source,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _errorState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 48),
        const SizedBox(height: 12),
        Text(
          'Could not load transactions',
          style: GoogleFonts.nunitoSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _error,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _fetch,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
        ),
      ]),
    );
  }

  Widget _emptyTransactions() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(
          Icons.receipt_long_outlined,
          size: 56,
          color: AppColors.textLight.withValues(alpha: 0.45),
        ),
        const SizedBox(height: 14),
        Text(
          'No transactions found',
          style: GoogleFonts.nunitoSans(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _searchCtrl.text.isNotEmpty
              ? 'No match for "${_searchCtrl.text}"'
              : 'Try a wider date range or different mode filter',
          style: GoogleFonts.nunitoSans(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            _searchCtrl.clear();
            setState(() => _modeFilter = 'ALL');
            _selectPreset('Year');
          },
          icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
          label: const Text('Clear Filters'),
        ),
      ]),
    );
  }
}

class _TxnSource extends DataTableSource {
  List<TransactionRecord> _data;
  final NumberFormat currency;
  final DateFormat dateFmt;

  _TxnSource(List<TransactionRecord> data, this.currency, this.dateFmt)
      : _data = data;

  void updateData(List<TransactionRecord> data) {
    _data = data;
    notifyListeners();
  }

  static const _modeIcons = {
    'CASH': Icons.money_rounded,
    'CHEQUE': Icons.account_balance_rounded,
    'DIGITAL_PAYMENT': Icons.phonelink_rounded,
    'CHALLAN': Icons.receipt_rounded,
  };

  @override
  DataRow? getRow(int index) {
    if (index >= _data.length) return null;
    final transaction = _data[index];
    final gross = transaction.amountPaid + transaction.discount;
    return DataRow(cells: [
      DataCell(Text(dateFmt.format(transaction.paymentDate),
          style: GoogleFonts.nunitoSans(fontSize: 12))),
      DataCell(Text(transaction.receiptNumber,
          style: GoogleFonts.nunitoSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.navy))),
      DataCell(Text(transaction.studentName,
          style: GoogleFonts.nunitoSans(
              fontSize: 12, fontWeight: FontWeight.w600))),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppSizes.radiusSM),
        ),
        child: Text(transaction.className,
            style: GoogleFonts.nunitoSans(
                fontSize: 11,
                color: AppColors.navy,
                fontWeight: FontWeight.w700)),
      )),
      DataCell(Text(
        transaction.paidForMonths.join(', '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.nunitoSans(fontSize: 12),
      )),
      DataCell(Text(currency.format(gross),
          style: GoogleFonts.nunitoSans(fontSize: 12))),
      DataCell(Text(
        transaction.discount > 0 ? currency.format(transaction.discount) : '-',
        style: GoogleFonts.nunitoSans(
            fontSize: 12,
            color: transaction.discount > 0
                ? AppColors.warning
                : AppColors.textLight),
      )),
      DataCell(Text(currency.format(transaction.amountPaid),
          style: GoogleFonts.nunitoSans(
              fontSize: 12,
              color: AppColors.success,
              fontWeight: FontWeight.w800))),
      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_modeIcons[transaction.paymentMode] ?? Icons.payments_outlined,
            size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Text(transaction.paymentMode.replaceAll('_', ' '),
            style: GoogleFonts.nunitoSans(fontSize: 12)),
      ])),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _data.length;

  @override
  int get selectedRowCount => 0;
}

class _StripStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StripStat(this.label, this.value, this.icon, this.color);
}
