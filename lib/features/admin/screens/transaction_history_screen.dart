import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<TransactionRecord> _all = [];
  List<TransactionRecord> _filtered = [];
  bool _loading = true;
  String _error = '';

  final _searchCtrl = TextEditingController();
  DateTimeRange? _range;
  String _preset = '30D';
  String _modeFilter = 'ALL';

  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  final _dateFmt  = DateFormat('dd MMM yyyy');
  final _shortFmt = DateFormat('dd MMM');

  // ── IMPORTANT: source created ONCE and updated via updateData()
  // Never recreate inside build() — PaginatedDataTable breaks if source changes.
  late _TxnSource _source;

  static const _modes = {
    'ALL':             'All',
    'CASH':            'Cash',
    'CHEQUE':          'Cheque',
    'DIGITAL_PAYMENT': 'Digital',
    'CHALLAN':         'Challan',
  };
  static const _presets = ['7D', '30D', '3M', 'Year', 'Custom'];

  // ── helpers ──────────────────────────────────────────────────────────────

  DateTimeRange _rangeFor(String preset) {
    final now = DateTime.now();
    switch (preset) {
      case '7D':   return DateTimeRange(start: now.subtract(const Duration(days: 7)),  end: now);
      case '30D':  return DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
      case '3M':   return DateTimeRange(start: DateTime(now.year, now.month - 2, 1),   end: now);
      case 'Year': return DateTimeRange(start: DateTime(now.year, 1, 1),               end: now);
      default:     return _range ?? DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
    }
  }

  String get _rangeLabel {
    if (_range == null) return 'Select dates';
    return '${_shortFmt.format(_range!.start)} – ${_shortFmt.format(_range!.end)}';
  }

  double get _totalCollected => _filtered.fold(0, (s, t) => s + t.amountPaid);
  double get _totalDiscount  => _filtered.fold(0, (s, t) => s + t.discount);

  // ── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _source = _TxnSource([], _currency, _dateFmt);
    _range  = _rangeFor('30D');
    _fetch();
    _searchCtrl.addListener(_applySearch);
  }

  @override
  void dispose() {
    // Remove listener BEFORE disposing the controller
    _searchCtrl.removeListener(_applySearch);
    _searchCtrl.dispose();
    _source.dispose();
    super.dispose();
  }

  // ── data ─────────────────────────────────────────────────────────────────

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = ''; });
    try {
      final report = await FeeApiService.getFeeReport(
        startDate:   _range?.start.toIso8601String().substring(0, 10),
        endDate:     _range?.end.toIso8601String().substring(0, 10),
        paymentMode: _modeFilter == 'ALL' ? null : _modeFilter,
      );
      if (!mounted) return;
      _all = report.transactions;
      // Apply current search and push to source in one step
      _applySearch();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load transactions: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Called by searchCtrl listener AND internally after _fetch loads data.
  void _applySearch() {
    if (!mounted) return;
    final q = _searchCtrl.text.toLowerCase();
    final results = q.isEmpty
        ? List<TransactionRecord>.from(_all)
        : _all.where((t) =>
            t.studentName.toLowerCase().contains(q) ||
            t.receiptNumber.toLowerCase().contains(q) ||
            t.className.toLowerCase().contains(q)).toList();
    setState(() => _filtered = results);
    // Notify PaginatedDataTable via the stable source object — no rebuild needed
    _source.updateData(results);
  }

  Future<void> _pickCustomRange() async {
    // Use Dialog with insetPadding so it appears small in the top-right corner.
    // This correctly constrains CalendarDatePicker's height.
    final picked = await showDialog<DateTimeRange>(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => Dialog(
        alignment: Alignment.topRight,
        // Left padding = large → dialog pushed to the right
        insetPadding: const EdgeInsets.only(
            top: 148, right: 12, bottom: 16, left: 80),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: _CompactRangePicker(
          initial: _range,
          onConfirm: (r) => Navigator.pop(ctx, r),
          onCancel:  () => Navigator.pop(ctx),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() { _range = picked; _preset = 'Custom'; });
      _fetch();
    }
  }

  void _selectPreset(String p) {
    if (p == 'Custom') { _pickCustomRange(); return; }
    setState(() { _preset = p; _range = _rangeFor(p); });
    _fetch();
  }

  void _selectMode(String mode) {
    setState(() => _modeFilter = mode);
    _fetch();
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Transaction History',
            style: GoogleFonts.cormorantGaramond(
                fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loading ? null : _fetch,
              tooltip: 'Refresh'),
        ],
      ),
      body: Column(children: [
        _buildFilterPanel(),
        if (!_loading && _error.isEmpty && _all.isNotEmpty) _buildSummaryStrip(),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  // ── filter panel ─────────────────────────────────────────────────────────

  Widget _buildFilterPanel() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Row 1 — search + calendar chip
        Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search name, receipt or class…',
                hintStyle: GoogleFonts.nunitoSans(
                    fontSize: 13, color: AppColors.textLight),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: AppColors.textLight),
                isDense: true,
                filled: true,
                fillColor: AppColors.cream,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    borderSide:
                        const BorderSide(color: AppColors.navy, width: 1.5)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Small calendar chip — opens the compact range picker
          InkWell(
            onTap: _pickCustomRange,
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                border: Border.all(
                    color: _preset == 'Custom'
                        ? AppColors.navy
                        : AppColors.border),
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                color: _preset == 'Custom'
                    ? AppColors.navy.withOpacity(0.06)
                    : Colors.transparent,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.date_range_rounded,
                    size: 16,
                    color: _preset == 'Custom'
                        ? AppColors.navy
                        : AppColors.textSecondary),
                const SizedBox(width: 5),
                Text(_rangeLabel,
                    style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        color: _preset == 'Custom'
                            ? AppColors.navy
                            : AppColors.textSecondary,
                        fontWeight: _preset == 'Custom'
                            ? FontWeight.w600
                            : FontWeight.w400)),
                const SizedBox(width: 3),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: _preset == 'Custom'
                        ? AppColors.navy
                        : AppColors.textLight),
              ]),
            ),
          ),
        ]),

        const SizedBox(height: 12),

        // Row 2 — date preset chips
        Row(children: [
          Text('Period:',
              style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _presets.map((p) {
                  final active = _preset == p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _selectPreset(p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: active ? AppColors.navy : Colors.transparent,
                          border: Border.all(
                              color: active ? AppColors.navy : AppColors.border),
                          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                        ),
                        child: p == 'Custom'
                            ? Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.calendar_month_outlined,
                                    size: 13,
                                    color: active
                                        ? Colors.white
                                        : AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text('Custom',
                                    style: GoogleFonts.nunitoSans(
                                        fontSize: 12,
                                        color: active
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                        fontWeight: FontWeight.w500)),
                              ])
                            : Text(p,
                                style: GoogleFonts.nunitoSans(
                                    fontSize: 12,
                                    color: active
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w500)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 10),

        // Row 3 — mode chips + record count badge
        Row(children: [
          Text('Mode:',
              style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _modes.entries.map((e) {
                  final active = _modeFilter == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _selectMode(e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.gold.withOpacity(0.15)
                              : Colors.transparent,
                          border: Border.all(
                              color: active ? AppColors.gold : AppColors.border),
                          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                        ),
                        child: Text(e.value,
                            style: GoogleFonts.nunitoSans(
                                fontSize: 12,
                                color: active
                                    ? AppColors.navy
                                    : AppColors.textSecondary,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w400)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.navy.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            ),
            child: Text('${_filtered.length} records',
                style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
          ),
        ]),
      ]),
    );
  }

  // ── summary strip ─────────────────────────────────────────────────────────

  Widget _buildSummaryStrip() {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        _statCell('Total Collected',
            _currency.format(_totalCollected), AppColors.goldLight),
        _vDivider(),
        _statCell('Discount Given',
            _currency.format(_totalDiscount), Colors.orange.shade200),
        _vDivider(),
        _statCell('Transactions', '${_filtered.length}', Colors.white),
        _vDivider(),
        _statCell(
            'Avg / Txn',
            _filtered.isEmpty
                ? '—'
                : _currency.format(_totalCollected / _filtered.length),
            Colors.white70),
      ]),
    );
  }

  Widget _statCell(String label, String value, Color valueColor) =>
      Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(value,
              style: GoogleFonts.nunitoSans(
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.nunitoSans(
                  color: Colors.white54, fontSize: 10)),
        ]),
      );

  Widget _vDivider() => Container(
      width: 1,
      height: 32,
      color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 4));

  // ── body ─────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 48),
          const SizedBox(height: 12),
          Text('Could not load transactions',
              style: GoogleFonts.nunitoSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error)),
          const SizedBox(height: 6),
          Text(_error,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy, foregroundColor: Colors.white),
            onPressed: _fetch,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ]),
      );
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.receipt_long_outlined,
              size: 56, color: AppColors.textLight.withOpacity(0.4)),
          const SizedBox(height: 14),
          Text('No transactions found',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 6),
          Text(
            _searchCtrl.text.isNotEmpty
                ? 'No match for "${_searchCtrl.text}"'
                : 'Try a wider date range or different mode filter',
            style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary, fontSize: 13),
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
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                side: const BorderSide(color: AppColors.navy)),
          ),
        ]),
      );
    }

    // ── data table — uses the STABLE _source field, never recreated ──────────
    return LayoutBuilder(
      builder: (context, tc) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: tc.maxWidth > 880 ? tc.maxWidth - 32 : 880,
              ),
              child: PaginatedDataTable(
                rowsPerPage: 15,
                showFirstLastButtons: true,
                headingRowColor: WidgetStateProperty.all(AppColors.creamDark),
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Receipt')),
                  DataColumn(label: Text('Student')),
                  DataColumn(label: Text('Class')),
                  DataColumn(label: Text('Installments')),
                  DataColumn(label: Text('Gross'),    numeric: true),
                  DataColumn(label: Text('Discount'), numeric: true),
                  DataColumn(label: Text('Net'),      numeric: true),
                  DataColumn(label: Text('Mode')),
                ],
                source: _source,   // stable — NEVER pass a new instance here
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── compact date-range picker ─────────────────────────────────────────────────
// Shows as a small dialog in the top-right corner.
// Two-step: tap start date → calendar advances to pick end date.

class _CompactRangePicker extends StatefulWidget {
  final DateTimeRange? initial;
  final ValueChanged<DateTimeRange> onConfirm;
  final VoidCallback onCancel;

  const _CompactRangePicker({
    this.initial,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_CompactRangePicker> createState() => _CompactRangePickerState();
}

class _CompactRangePickerState extends State<_CompactRangePicker> {
  DateTime? _start;
  DateTime? _end;
  bool _pickingEnd = false;
  final _fmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _start = widget.initial?.start;
    _end   = widget.initial?.end;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Width is determined by Dialog.insetPadding; just set a max.
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── header ─────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusLG)),
            ),
            child: Row(children: [
              Expanded(
                child: _dateTab('From', _start, !_pickingEnd,
                    () => setState(() => _pickingEnd = false)),
              ),
              Container(
                  width: 1,
                  height: 36,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 10)),
              Expanded(
                child: _dateTab('To', _end, _pickingEnd,
                    () => setState(() => _pickingEnd = true)),
              ),
            ]),
          ),

          // ── calendar ───────────────────────────────────────────────────────
          // Key changes when switching start↔end so CalendarDatePicker resets
          CalendarDatePicker(
            key: ValueKey(_pickingEnd),
            initialDate: _pickingEnd
                ? (_end ?? _start ?? DateTime.now())
                : (_start ?? DateTime.now()),
            firstDate: _pickingEnd && _start != null
                ? _start!
                : DateTime(2020),
            lastDate: DateTime.now(),
            onDateChanged: (date) {
              setState(() {
                if (!_pickingEnd) {
                  _start     = date;
                  _end       = null;
                  _pickingEnd = true;   // auto-advance to pick end date
                } else {
                  _end = date;
                }
              });
            },
          ),

          // ── footer buttons ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(children: [
              Expanded(
                child: Text(
                  _start != null && _end != null
                      ? '${_fmt.format(_start!)} → ${_fmt.format(_end!)}'
                      : _start != null
                          ? 'Now pick end date'
                          : 'Pick start date',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel')),
              const SizedBox(width: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8)),
                onPressed: _start != null && _end != null
                    ? () => widget.onConfirm(
                        DateTimeRange(start: _start!, end: _end!))
                    : null,
                child: const Text('Apply'),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _dateTab(
      String label, DateTime? date, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
              color: active ? AppColors.gold : Colors.transparent,
              width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.nunitoSans(
                  fontSize: 10,
                  color: active ? AppColors.gold : Colors.white54,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            date != null ? _fmt.format(date) : 'Select…',
            style: GoogleFonts.nunitoSans(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }
}

// ── data-table source ─────────────────────────────────────────────────────────
// Mutable source: data is updated in-place via updateData() which calls
// notifyListeners(). This keeps PaginatedDataTable's page state intact.

class _TxnSource extends DataTableSource {
  List<TransactionRecord> _data;
  final NumberFormat currency;
  final DateFormat dateFmt;

  _TxnSource(List<TransactionRecord> data, this.currency, this.dateFmt)
      : _data = data;

  /// Call this instead of recreating the source.
  void updateData(List<TransactionRecord> data) {
    _data = data;
    notifyListeners();
  }

  static const _modeIcons = {
    'CASH':            Icons.money_rounded,
    'CHEQUE':          Icons.account_balance_rounded,
    'DIGITAL_PAYMENT': Icons.phonelink_rounded,
    'CHALLAN':         Icons.receipt_rounded,
  };

  @override
  DataRow? getRow(int index) {
    if (index >= _data.length) return null;
    final t     = _data[index];
    final net   = t.amountPaid;
    final gross = net + t.discount;

    return DataRow(cells: [
      DataCell(Text(dateFmt.format(t.paymentDate),
          style: GoogleFonts.nunitoSans(fontSize: 12))),
      DataCell(Text(t.receiptNumber,
          style: GoogleFonts.nunitoSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.navy))),
      DataCell(Text(t.studentName,
          style: GoogleFonts.nunitoSans(
              fontSize: 12, fontWeight: FontWeight.w500))),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.navy.withOpacity(0.07),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(t.className,
            style: GoogleFonts.nunitoSans(
                fontSize: 11,
                color: AppColors.navy,
                fontWeight: FontWeight.w600)),
      )),
      DataCell(Text(
        t.paidForMonths.isEmpty ? '—' : t.paidForMonths.join(', '),
        style:
            GoogleFonts.nunitoSans(fontSize: 11, color: AppColors.textSecondary),
      )),
      DataCell(Text(currency.format(gross),
          style: GoogleFonts.nunitoSans(fontSize: 12))),
      DataCell(Text(
        t.discount > 0 ? currency.format(t.discount) : '—',
        style: GoogleFonts.nunitoSans(
            fontSize: 12,
            color: t.discount > 0 ? AppColors.warning : AppColors.textLight),
      )),
      DataCell(Text(currency.format(net),
          style: GoogleFonts.nunitoSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.success))),
      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_modeIcons[t.paymentMode] ?? Icons.payment_rounded,
            size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          t.paymentMode
              .replaceAll('_', ' ')
              .toLowerCase()
              .split(' ')
              .map((w) => w.isEmpty
                  ? ''
                  : '${w[0].toUpperCase()}${w.substring(1)}')
              .join(' '),
          style: GoogleFonts.nunitoSans(fontSize: 11),
        ),
      ])),
    ]);
  }

  @override bool get isRowCountApproximate => false;
  @override int  get rowCount              => _data.length;
  @override int  get selectedRowCount      => 0;
}
