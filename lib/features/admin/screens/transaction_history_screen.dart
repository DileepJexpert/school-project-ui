import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<TransactionRecord> _all = [];
  List<TransactionRecord> _filtered = [];
  bool _loading = true;
  String _error = '';
  final _searchCtrl = TextEditingController();
  DateTimeRange? _range;
  String? _modeFilter;
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  final _dateFmt = DateFormat('dd MMM yyyy');

  final _modes = ['All Modes', 'CASH', 'CHEQUE', 'DIGITAL_PAYMENT', 'CHALLAN'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
    _fetch();
    _searchCtrl.addListener(_applyFilters);
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final report = await FeeApiService.getFeeReport(
        startDate: _range?.start.toIso8601String().substring(0, 10),
        endDate: _range?.end.toIso8601String().substring(0, 10),
        paymentMode: (_modeFilter == null || _modeFilter == 'All Modes') ? null : _modeFilter,
      );
      setState(() { _all = report.transactions; _filtered = report.transactions; });
    } catch (e) {
      setState(() => _error = 'Failed to load transactions: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((t) =>
          t.studentName.toLowerCase().contains(q) ||
          t.receiptNumber.toLowerCase().contains(q) ||
          t.className.toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.navy)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _range = picked);
      _fetch();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text('Transaction History',
            style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch, tooltip: 'Refresh'),
        ],
      ),
      body: Column(children: [
        // Filter bar
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            // Search
            SizedBox(
              width: 220,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search name, receipt…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            // Date range
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(
                _range != null
                    ? '${_dateFmt.format(_range!.start)} – ${_dateFmt.format(_range!.end)}'
                    : 'Date Range',
                style: GoogleFonts.nunitoSans(fontSize: 12),
              ),
              onPressed: _pickRange,
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            ),
            // Mode
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                value: _modeFilter ?? 'All Modes',
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  isDense: true,
                ),
                items: _modes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: GoogleFonts.nunitoSans(fontSize: 13)))).toList(),
                onChanged: (v) { setState(() => _modeFilter = v); _fetch(); },
              ),
            ),
            // Count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.navy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
              child: Text('${_filtered.length} records',
                  style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w600, color: AppColors.navy, fontSize: 13)),
            ),
          ]),
        ),
        // Table
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                  ? Center(child: Text(_error, style: GoogleFonts.nunitoSans(color: AppColors.error)))
                  : _filtered.isEmpty
                      ? Center(
                          child: Text('No transactions found.',
                              style: GoogleFonts.nunitoSans(color: AppColors.textSecondary)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
                            clipBehavior: Clip.antiAlias,
                            child: PaginatedDataTable(
                              rowsPerPage: 15,
                              columns: ['Date', 'Receipt', 'Student', 'Class', 'Installments', 'Gross', 'Discount', 'Net', 'Mode']
                                  .map((h) => DataColumn(
                                      label: Text(h,
                                          style: GoogleFonts.nunitoSans(
                                              fontWeight: FontWeight.w700, fontSize: 12))))
                                  .toList(),
                              source: _TxnSource(_filtered, _currency, _dateFmt),
                            ),
                          ),
                        ),
        ),
      ]),
    );
  }
}

class _TxnSource extends DataTableSource {
  final List<TransactionRecord> data;
  final NumberFormat currency;
  final DateFormat dateFmt;
  _TxnSource(this.data, this.currency, this.dateFmt);

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final t = data[index];
    final net = t.amountPaid;
    final gross = net + t.discount;
    return DataRow(cells: [
      DataCell(Text(dateFmt.format(t.paymentDate),
          style: GoogleFonts.nunitoSans(fontSize: 12))),
      DataCell(Text(t.receiptNumber,
          style: GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy))),
      DataCell(Text(t.studentName, style: GoogleFonts.nunitoSans(fontSize: 12))),
      DataCell(Text(t.className, style: GoogleFonts.nunitoSans(fontSize: 12))),
      DataCell(Text(t.paidForMonths.join(', '),
          style: GoogleFonts.nunitoSans(fontSize: 11, color: AppColors.textSecondary))),
      DataCell(Text(currency.format(gross), style: GoogleFonts.nunitoSans(fontSize: 12))),
      DataCell(Text(
        t.discount > 0 ? currency.format(t.discount) : '—',
        style: GoogleFonts.nunitoSans(
            fontSize: 12, color: t.discount > 0 ? AppColors.warning : AppColors.textLight),
      )),
      DataCell(Text(currency.format(net),
          style: GoogleFonts.nunitoSans(
              fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success))),
      DataCell(Text(t.paymentMode, style: GoogleFonts.nunitoSans(fontSize: 11))),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => data.length;
  @override
  int get selectedRowCount => 0;
}
