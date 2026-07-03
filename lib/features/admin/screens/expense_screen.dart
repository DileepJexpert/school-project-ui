import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/shared_widgets.dart';
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

  final _currency = NumberFormat.currency(symbol: '\u20B9', decimalDigits: 0);
  final _dateFmt = DateFormat('dd MMM yyyy');
  final _monthFmt = DateFormat('MMM yyyy');

  List<Expense> _expenses = [];
  bool _loading = true;
  String? _error;
  DateTime? _filterMonth;

  DateTime _reportMonth = DateTime.now();
  List<Expense> _reportExpenses = [];
  double _reportIncome = 0;
  bool _reportLoading = false;
  bool _reportLoaded = false;
  String? _reportError;

  static const _categories = [
    'Salaries',
    'Infrastructure',
    'Utilities',
    'Events',
    'Maintenance',
    'Stationery',
    'Transport',
    'IT & Software',
    'Others',
  ];

  static const _categoryColors = <String, Color>{
    'Salaries': AppColors.navy,
    'Infrastructure': AppColors.info,
    'Utilities': AppColors.warning,
    'Events': AppColors.gold,
    'Maintenance': Color(0xFF7C3AED),
    'Stationery': AppColors.success,
    'Transport': Color(0xFF0D9488),
    'IT & Software': Color(0xFFDB2777),
    'Others': AppColors.textSecondary,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchExpenses();
    _loadMonthlyReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchExpenses() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await FeeApiService.getExpenses(
        from: _filterMonth == null ? null : _fmtDate(_firstDay(_filterMonth!)),
        to: _filterMonth == null ? null : _fmtDate(_lastDay(_filterMonth!)),
      );
      if (mounted) setState(() => _expenses = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMonthlyReport() async {
    if (!mounted) return;
    setState(() {
      _reportLoading = true;
      _reportError = null;
      _reportLoaded = false;
    });
    try {
      final from = _fmtDate(_firstDay(_reportMonth));
      final to = _fmtDate(_lastDay(_reportMonth));
      final results = await Future.wait([
        FeeApiService.getExpenses(from: from, to: to),
        FeeApiService.getFeeReport(startDate: from, endDate: to),
      ]);
      if (!mounted) return;
      setState(() {
        _reportExpenses = results[0] as List<Expense>;
        _reportIncome =
            (results[1] as FeeReportResponse).summary.totalCollected;
        _reportLoaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _reportError = e.toString());
    } finally {
      if (mounted) setState(() => _reportLoading = false);
    }
  }

  String _fmtDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _firstDay(DateTime month) => DateTime(month.year, month.month, 1);

  DateTime _lastDay(DateTime month) => DateTime(month.year, month.month + 1, 0);

  Color _categoryColor(String category) =>
      _categoryColors[category] ?? AppColors.textSecondary;

  double get _totalExpenses =>
      _expenses.fold(0.0, (sum, expense) => sum + expense.amount);

  double get _averageExpense =>
      _expenses.isEmpty ? 0 : _totalExpenses / _expenses.length;

  Map<String, double> _categoryTotals(List<Expense> expenses) {
    final totals = <String, double>{};
    for (final expense in expenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }
    return totals;
  }

  String get _topCategory {
    final totals = _categoryTotals(_expenses).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return totals.isEmpty ? 'No category' : totals.first.key;
  }

  Future<void> _pickExpenseMonth() async {
    final picked = await _pickMonth(_filterMonth ?? DateTime.now());
    if (picked == null) return;
    setState(() => _filterMonth = DateTime(picked.year, picked.month));
    _fetchExpenses();
  }

  Future<void> _pickReportMonth() async {
    final picked = await _pickMonth(_reportMonth);
    if (picked == null) return;
    setState(() => _reportMonth = DateTime(picked.year, picked.month));
    _loadMonthlyReport();
  }

  Future<DateTime?> _pickMonth(DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial.isAfter(DateTime.now()) ? DateTime.now() : initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select month',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: context.palette.brand,
                surface: context.palette.surface,
              ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
            child: child!,
          ),
        ),
      ),
    );
  }

  void _clearMonthFilter() {
    setState(() => _filterMonth = null);
    _fetchExpenses();
  }

  Future<void> _showAddDialog() async {
    final titleCtrl = TextEditingController();
    final paidToCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    String category = _categories.first;
    DateTime date = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(
              'Add Expense',
              style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w900),
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                    controller: titleCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Expense title *'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category *'),
                    items: _categories
                        .map((item) =>
                            DropdownMenuItem(value: item, child: Text(item)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => category = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Amount (INR) *'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: paidToCtrl,
                    decoration: const InputDecoration(labelText: 'Paid to *'),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.palette.canvas,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSM),
                      border: Border.all(color: context.palette.border),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined, size: 17),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_dateFmt.format(date))),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => date = picked);
                          }
                        },
                        child: const Text('Change'),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksCtrl,
                    decoration: const InputDecoration(labelText: 'Remarks'),
                    maxLines: 2,
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                  if (titleCtrl.text.trim().isEmpty ||
                      paidToCtrl.text.trim().isEmpty ||
                      amount <= 0) {
                    _snack('Fill title, paid to and a valid amount.',
                        isError: true);
                    return;
                  }
                  try {
                    await FeeApiService.addExpense(
                      Expense(
                        title: titleCtrl.text.trim(),
                        category: category,
                        amount: amount,
                        date: date,
                        paidTo: paidToCtrl.text.trim(),
                        remarks: remarksCtrl.text.trim().isEmpty
                            ? null
                            : remarksCtrl.text.trim(),
                      ),
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    _snack('Expense added.');
                    _fetchExpenses();
                    _loadMonthlyReport();
                  } catch (e) {
                    _snack('Failed to add expense: $e', isError: true);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _deleteExpense(Expense expense) async {
    final id = expense.id;
    if (id == null || id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete "${expense.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FeeApiService.deleteExpense(id);
      _snack('Expense deleted.');
      _fetchExpenses();
      _loadMonthlyReport();
    } catch (e) {
      _snack('Delete failed: $e', isError: true);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(
        Responsive.isMobile(context) ? AppSizes.paddingMD : AppSizes.paddingLG,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdminPageHeader(
          title: 'Expenses',
          subtitle:
              'Track school outgoings, compare against fee income, and keep a clean audit trail.',
          icon: Icons.payments_outlined,
          actions: [
            OutlinedButton.icon(
              onPressed: _loading ? null : _fetchExpenses,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Refresh'),
            ),
            ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Expense'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _summaryCards(),
        const SizedBox(height: 16),
        _tabBar(),
        const SizedBox(height: 14),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_expensesTab(), _monthlyReportTab()],
          ),
        ),
      ]),
    );
  }

  Widget _summaryCards() {
    final cards = [
      AdminMetricCard(
        title: 'Total Expenses',
        value: _currency.format(_totalExpenses),
        icon: Icons.trending_down_rounded,
        color: AppColors.error,
        caption: _filterMonth == null
            ? 'All months'
            : _monthFmt.format(_filterMonth!),
      ),
      AdminMetricCard(
        title: 'Records',
        value: '${_expenses.length}',
        icon: Icons.receipt_long_outlined,
        color: AppColors.info,
        caption: 'Expense entries',
      ),
      AdminMetricCard(
        title: 'Average Spend',
        value: _currency.format(_averageExpense),
        icon: Icons.calculate_outlined,
        color: AppColors.warning,
        caption: 'Per expense',
      ),
      AdminMetricCard(
        title: 'Top Category',
        value: _topCategory,
        icon: Icons.category_outlined,
        color: AppColors.success,
        caption: 'By amount',
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final columns = Responsive.isDesktop(context)
          ? 4
          : constraints.maxWidth > 720
              ? 2
              : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children:
            cards.map((card) => SizedBox(width: width, child: card)).toList(),
      );
    });
  }

  Widget _tabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        border: Border.all(color: context.palette.border),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: context.palette.brand,
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: GoogleFonts.nunitoSans(
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'Expense Register'),
          Tab(text: 'Monthly Position'),
        ],
      ),
    );
  }

  Widget _expensesTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _errorState(_error!, _fetchExpenses);

    return Column(children: [
      _expenseToolbar(),
      const SizedBox(height: 12),
      Expanded(
        child: _expenses.isEmpty
            ? _emptyState(
                icon: Icons.paid_outlined,
                title: 'No expenses recorded',
                subtitle: 'Add the first expense to start tracking outgoings.',
                action: ElevatedButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Add Expense'),
                ),
              )
            : ListView.separated(
                itemCount: _expenses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) => _expenseRow(_expenses[index]),
              ),
      ),
    ]);
  }

  Widget _expenseToolbar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          InkWell(
            onTap: _pickExpenseMonth,
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _filterMonth == null
                    ? context.palette.canvas
                    : context.palette.brand.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                border: Border.all(
                  color: _filterMonth == null
                      ? context.palette.border
                      : context.palette.brand,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_month_outlined,
                    size: 17, color: context.palette.brand),
                const SizedBox(width: 7),
                Text(
                  _filterMonth == null
                      ? 'All months'
                      : _monthFmt.format(_filterMonth!),
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_filterMonth != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _clearMonthFilter,
                    child: const Icon(Icons.close_rounded, size: 15),
                  ),
                ],
              ]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_expenses.length} records - ${_currency.format(_totalExpenses)} total',
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _expenseRow(Expense expense) {
    final color = _categoryColor(expense.category);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            ),
            child: Icon(Icons.payments_outlined, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                expense.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${expense.category} - ${expense.paidTo} - ${_dateFmt.format(expense.date)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if ((expense.remarks ?? '').isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  expense.remarks!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    color: AppColors.textLight,
                    fontSize: 11,
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(width: 12),
          Text(
            _currency.format(expense.amount),
            style: GoogleFonts.nunitoSans(
              color: AppColors.error,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _deleteExpense(expense),
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 19),
          ),
        ]),
      ),
    );
  }

  Widget _monthlyReportTab() {
    return Column(children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            InkWell(
              onTap: _pickReportMonth,
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: context.palette.canvas,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  border: Border.all(color: context.palette.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.calendar_month_outlined,
                      size: 17, color: context.palette.brand),
                  const SizedBox(width: 7),
                  Text(
                    _monthFmt.format(_reportMonth),
                    style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _reportLoading ? null : _loadMonthlyReport,
              icon: _reportLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.analytics_outlined, size: 17),
              label: Text(_reportLoading ? 'Loading' : 'Load'),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Expanded(child: _monthlyReportBody()),
    ]);
  }

  Widget _monthlyReportBody() {
    if (_reportLoading) return const Center(child: CircularProgressIndicator());
    if (_reportError != null) {
      return _errorState(_reportError!, _loadMonthlyReport);
    }
    if (!_reportLoaded) {
      return _emptyState(
        icon: Icons.analytics_outlined,
        title: 'Load a monthly position',
        subtitle: 'Choose a month to compare fee income against expenses.',
      );
    }

    final totalExpenses =
        _reportExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
    final net = _reportIncome - totalExpenses;
    final categories = _categoryTotals(_reportExpenses).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth > 780 ? 3 : 1;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          final cards = [
            _PositionCard(
              'Fee Income',
              _reportIncome,
              Icons.trending_up_rounded,
              AppColors.success,
            ),
            _PositionCard(
              'Expenses',
              totalExpenses,
              Icons.trending_down_rounded,
              AppColors.error,
            ),
            _PositionCard(
              'Net Position',
              net,
              net >= 0 ? Icons.account_balance_wallet : Icons.warning_rounded,
              net >= 0 ? AppColors.success : AppColors.error,
            ),
          ];
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map((card) =>
                    SizedBox(width: width, child: _positionCard(card)))
                .toList(),
          );
        }),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Category Breakdown',
                style: GoogleFonts.nunitoSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_reportExpenses.length} expenses in ${_monthFmt.format(_reportMonth)}',
                style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              if (categories.isEmpty)
                _emptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No expenses this month',
                  subtitle: 'There are no outgoing entries for this month.',
                  embedded: true,
                )
              else
                ...categories.map((entry) {
                  final pct =
                      totalExpenses <= 0 ? 0.0 : entry.value / totalExpenses;
                  final color = _categoryColor(entry.key);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _breakdownRow(entry.key, entry.value, pct, color),
                  );
                }),
            ]),
          ),
        ),
        const SizedBox(height: 70),
      ]),
    );
  }

  Widget _positionCard(_PositionCard card) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: card.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            ),
            child: Icon(card.icon, color: card.color, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _currency.format(card.amount.abs()),
                style: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: card.color,
                ),
              ),
              Text(
                card.label,
                style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _breakdownRow(String label, double amount, double pct, Color color) {
    return Row(children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 2,
        child: Text(
          label,
          style: GoogleFonts.nunitoSans(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
        ),
      ),
      Expanded(
        flex: 3,
        child: Column(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct.clamp(0, 1),
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Text(
              '${(pct * 100).toStringAsFixed(1)}%',
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Text(
              _currency.format(amount),
              style: GoogleFonts.nunitoSans(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
    bool embedded = false,
  }) {
    final content = Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 52, color: AppColors.textLight.withValues(alpha: 0.55)),
      const SizedBox(height: 12),
      Text(
        title,
        style: GoogleFonts.nunitoSans(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: GoogleFonts.nunitoSans(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
      if (action != null) ...[const SizedBox(height: 16), action],
    ]);

    if (embedded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: content),
      );
    }
    return Center(child: content);
  }

  Widget _errorState(String error, VoidCallback retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 48),
          const SizedBox(height: 12),
          Text(
            'Could not load expenses',
            style: GoogleFonts.nunitoSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Retry'),
          ),
        ]),
      ),
    );
  }
}

class _PositionCard {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _PositionCard(this.label, this.amount, this.icon, this.color);
}
