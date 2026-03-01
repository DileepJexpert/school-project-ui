import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  final _dateFmt  = DateFormat('dd MMM yyyy');

  // ── Expenses tab ──────────────────────────────────────────────────────
  List<Expense> _expenses = [];
  bool     _loading     = true;
  String   _eError      = '';
  DateTime? _filterMonth; // null = show all

  // ── Monthly Report tab ────────────────────────────────────────────────
  DateTime      _rMonth    = DateTime.now();
  List<Expense> _rExpenses = [];
  double        _rIncome   = 0;
  bool          _rLoading  = false;
  bool          _rLoaded   = false;
  String        _rError    = '';

  // ─────────────────────────────────────────────────────────────────────

  static const _categories = [
    'Salaries', 'Infrastructure', 'Utilities', 'Events', 'Maintenance',
    'Stationery', 'Transport', 'IT & Software', 'Others',
  ];

  static const _catColors = <String, Color>{
    'Salaries':       AppColors.navy,
    'Infrastructure': AppColors.info,
    'Utilities':      AppColors.warning,
    'Events':         AppColors.gold,
    'Maintenance':    Color(0xFF7C3AED),
    'Stationery':     AppColors.success,
    'Transport':      Color(0xFF0D9488),
    'IT & Software':  Color(0xFFDB2777),
    'Others':         AppColors.textSecondary,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchExpenses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Expenses tab helpers ──────────────────────────────────────────────

  Future<void> _fetchExpenses() async {
    setState(() { _loading = true; _eError = ''; });
    try {
      final List<Expense> data;
      if (_filterMonth != null) {
        data = await FeeApiService.getExpenses(
          from: _fmtDate(_firstDay(_filterMonth!)),
          to:   _fmtDate(_lastDay(_filterMonth!)),
        );
      } else {
        data = await FeeApiService.getExpenses();
      }
      setState(() => _expenses = data);
    } catch (e) {
      setState(() => _eError = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickFilterMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterMonth ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select any day in the month',
      builder: _dpTheme,
    );
    if (picked != null) {
      setState(() => _filterMonth = DateTime(picked.year, picked.month));
      _fetchExpenses();
    }
  }

  void _clearFilter() {
    setState(() => _filterMonth = null);
    _fetchExpenses();
  }

  Future<void> _showAddDialog() async {
    final titleCtrl   = TextEditingController();
    final paidToCtrl  = TextEditingController();
    final amountCtrl  = TextEditingController();
    final remarksCtrl = TextEditingController();
    String? category;
    DateTime date = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Add Expense',
              style: GoogleFonts.cormorantGaramond(
                  fontWeight: FontWeight.w700, fontSize: 22)),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Expense Title *',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                      labelText: 'Category *',
                      border: OutlineInputBorder()),
                  items: _categories
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDlg(() => category = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Amount (₹) *',
                      border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: paidToCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Paid To *',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Text('Date: ${_dateFmt.format(date)}',
                        style: GoogleFonts.nunitoSans(
                            color: AppColors.textSecondary)),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined,
                        size: 16),
                    label: const Text('Change'),
                    onPressed: () async {
                      final p = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (p != null) setDlg(() => date = p);
                    },
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: remarksCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Remarks',
                      border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty ||
                    category == null ||
                    amountCtrl.text.trim().isEmpty ||
                    paidToCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Fill all required fields.')),
                  );
                  return;
                }
                final expense = Expense(
                  title:    titleCtrl.text.trim(),
                  category: category!,
                  amount:
                      double.tryParse(amountCtrl.text.trim()) ?? 0.0,
                  date:     date,
                  paidTo:   paidToCtrl.text.trim(),
                  remarks:  remarksCtrl.text.trim().isEmpty
                      ? null
                      : remarksCtrl.text.trim(),
                );
                try {
                  await FeeApiService.addExpense(expense);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _fetchExpenses();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Expense added!'),
                          backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Failed: $e'),
                          backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(Expense expense) async {
    if (expense.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete "${expense.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await FeeApiService.deleteExpense(expense.id!);
        _fetchExpenses();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Delete failed: $e'),
                backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  // ── Monthly Report helpers ─────────────────────────────────────────────

  Future<void> _pickReportMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _rMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select any day in the month',
      builder: _dpTheme,
    );
    if (picked != null) {
      setState(() => _rMonth = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _loadReport() async {
    setState(() { _rLoading = true; _rError = ''; _rLoaded = false; });
    try {
      final fromStr = _fmtDate(_firstDay(_rMonth));
      final toStr   = _fmtDate(_lastDay(_rMonth));

      final results = await Future.wait([
        FeeApiService.getExpenses(from: fromStr, to: toStr),
        FeeApiService.getFeeReport(startDate: fromStr, endDate: toStr),
      ]);

      _rExpenses = results[0] as List<Expense>;
      _rIncome   =
          (results[1] as FeeReportResponse).summary.totalCollected;
      setState(() => _rLoaded = true);
    } catch (e) {
      setState(() => _rError = e.toString());
    } finally {
      setState(() => _rLoading = false);
    }
  }

  // ── Shared helpers ────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  DateTime _firstDay(DateTime m) => DateTime(m.year, m.month, 1);
  DateTime _lastDay(DateTime m)  => DateTime(m.year, m.month + 1, 0);

  String _monthLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  Color _catColor(String cat) =>
      _catColors[cat] ?? AppColors.textSecondary;

  Widget _dpTheme(BuildContext ctx, Widget? child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.navy, onPrimary: Colors.white),
        ),
        child: child!,
      );

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Page header ─────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Expenses',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              Text('Track salaries, purchases and all school outgoings',
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary, fontSize: 13)),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Expense'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12)),
          ),
        ]),
        const SizedBox(height: 16),
        // ── Tab bar ────────────────────────────────────────────────
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
              Tab(text: 'Expenses'),
              Tab(text: 'Monthly Report'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildExpensesTab(), _buildReportTab()],
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // EXPENSES TAB
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildExpensesTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_eError.isNotEmpty) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(_eError,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              ElevatedButton(
                  onPressed: _fetchExpenses,
                  child: const Text('Retry')),
            ]),
      );
    }

    final total = _expenses.fold<double>(0, (s, e) => s + e.amount);

    return Column(children: [
      // ── Filter + total bar ───────────────────────────────────────
      Row(children: [
        InkWell(
          onTap: _pickFilterMonth,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _filterMonth != null
                  ? AppColors.navy
                  : AppColors.creamDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _filterMonth != null
                      ? AppColors.navy
                      : AppColors.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_month_outlined,
                  size: 16,
                  color: _filterMonth != null
                      ? Colors.white
                      : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                _filterMonth != null
                    ? _monthLabel(_filterMonth!)
                    : 'All months',
                style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    color: _filterMonth != null
                        ? Colors.white
                        : AppColors.textSecondary),
              ),
              if (_filterMonth != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _clearFilter,
                  child: const Icon(Icons.close,
                      size: 14, color: Colors.white),
                ),
              ],
            ]),
          ),
        ),
        const Spacer(),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: AppColors.error.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.trending_down_rounded,
                size: 16, color: AppColors.error),
            const SizedBox(width: 6),
            Text('Total: ${_currency.format(total)}',
                style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error)),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      // ── Expense list ─────────────────────────────────────────────
      Expanded(
        child: _expenses.isEmpty
            ? Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.paid_outlined,
                          size: 60, color: AppColors.textLight),
                      const SizedBox(height: 12),
                      Text('No expenses recorded yet.',
                          style: GoogleFonts.nunitoSans(
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text('Tap "Add Expense" to get started.',
                          style: GoogleFonts.nunitoSans(
                              color: AppColors.textLight, fontSize: 12)),
                    ]))
            : ListView.separated(
                itemCount: _expenses.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final e   = _expenses[i];
                  final col = _catColor(e.category);
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppSizes.radiusLG)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: col.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                              AppSizes.radiusMD),
                        ),
                        child: Icon(Icons.paid_outlined,
                            color: col, size: 22),
                      ),
                      title: Text(e.title,
                          style: GoogleFonts.nunitoSans(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      subtitle: Text(
                        '${e.category}  ·  ${e.paidTo}'
                        '  ·  ${_dateFmt.format(e.date)}',
                        style: GoogleFonts.nunitoSans(
                            color: AppColors.textSecondary,
                            fontSize: 12),
                      ),
                      trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_currency.format(e.amount),
                                style: GoogleFonts.cormorantGaramond(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.error)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppColors.error, size: 18),
                              onPressed: () => _delete(e),
                            ),
                          ]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════
  // MONTHLY REPORT TAB
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildReportTab() {
    return Column(children: [
      // ── Filter bar ─────────────────────────────────────────────────
      Row(children: [
        InkWell(
          onTap: _pickReportMonth,
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              color: Colors.white,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 18, color: AppColors.navy),
              const SizedBox(width: 8),
              Text(_monthLabel(_rMonth),
                  style: GoogleFonts.nunitoSans(
                      fontSize: 14, color: AppColors.textPrimary)),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _rLoading ? null : _loadReport,
          icon: _rLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.bar_chart_rounded, size: 16),
          label: Text(_rLoading ? 'Loading…' : 'Load Report'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12)),
        ),
      ]),
      const SizedBox(height: 16),
      Expanded(child: _buildReportBody()),
    ]);
  }

  Widget _buildReportBody() {
    if (_rLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rError.isNotEmpty) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(_rError,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              ElevatedButton(
                  onPressed: _loadReport,
                  child: const Text('Retry')),
            ]),
      );
    }
    if (!_rLoaded) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.analytics_outlined,
                  size: 60, color: AppColors.textLight),
              const SizedBox(height: 14),
              Text('Select a month and tap Load Report',
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary, fontSize: 14)),
            ]),
      );
    }

    final totalExpenses =
        _rExpenses.fold<double>(0, (s, e) => s + e.amount);
    final net = _rIncome - totalExpenses;

    // Category totals sorted by amount descending
    final Map<String, double> catTotals = {};
    for (final e in _rExpenses) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }
    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // ── Net Position card ──────────────────────────────────────
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppSizes.radiusXL)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Net Position — ${_monthLabel(_rMonth)}',
                      style: GoogleFonts.cormorantGaramond(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy)),
                  const SizedBox(height: 2),
                  Text(
                      'Fee income collected vs total expenses recorded',
                      style: GoogleFonts.nunitoSans(
                          color: AppColors.textSecondary,
                          fontSize: 12)),
                  const SizedBox(height: 16),
                  LayoutBuilder(builder: (ctx, constraints) {
                    final wide = constraints.maxWidth > 500;
                    final plCards = [
                      _plCard('Fee Income', _rIncome,
                          AppColors.success,
                          Icons.trending_up_rounded),
                      _plCard('Total Expenses', totalExpenses,
                          AppColors.error,
                          Icons.trending_down_rounded),
                      _plCard(
                          'Net',
                          net,
                          net >= 0
                              ? AppColors.success
                              : AppColors.error,
                          net >= 0
                              ? Icons.account_balance_wallet
                              : Icons.warning_amber_rounded),
                    ];
                    if (wide) {
                      return Row(
                        children: plCards
                            .map((w) => Expanded(
                                  child: Padding(
                                      padding: const EdgeInsets
                                          .symmetric(horizontal: 4),
                                      child: w),
                                ))
                            .toList(),
                      );
                    }
                    return Column(
                      children: plCards
                          .map((w) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 8),
                              child: SizedBox(
                                  width: double.infinity,
                                  child: w)))
                          .toList(),
                    );
                  }),
                ]),
          ),
        ),
        const SizedBox(height: 20),
        // ── Category breakdown ────────────────────────────────────
        if (sortedCats.isNotEmpty) ...[
          Text('Breakdown by Category',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 12),
          ...sortedCats.map((entry) {
            final pct = totalExpenses == 0
                ? 0.0
                : entry.value / totalExpenses;
            final col = _catColor(entry.key);
            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusLG)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: col, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Text(entry.key,
                        style: GoogleFonts.nunitoSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimary)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 7,
                          backgroundColor: col.withOpacity(0.12),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(col),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text(
                            '${(pct * 100).toStringAsFixed(1)}%',
                            style: GoogleFonts.nunitoSans(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                        const Spacer(),
                        Text(_currency.format(entry.value),
                            style: GoogleFonts.nunitoSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                      ]),
                    ]),
                  ),
                ]),
              ),
            );
          }),
        ] else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                  'No expenses for ${_monthLabel(_rMonth)}',
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary)),
            ),
          ),
        const SizedBox(height: 80),
      ]),
    );
  }

  // ── P&L mini-card ─────────────────────────────────────────────────────

  Widget _plCard(
      String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 6),
            Text(_currency.format(amount.abs()),
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ]),
    );
  }
}
