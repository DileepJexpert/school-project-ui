import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/searchable_dropdown.dart';
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
  String   _searchQuery = '';
  String?  _selectedCategory; // null = show all
  String   _sortBy      = 'date_desc'; // date_desc, date_asc, amount_desc, amount_asc
  final    _searchCtrl  = TextEditingController();

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

  static const _catIcons = <String, IconData>{
    'Salaries':       Icons.payments_outlined,
    'Infrastructure': Icons.domain_outlined,
    'Utilities':      Icons.bolt_outlined,
    'Events':         Icons.celebration_outlined,
    'Maintenance':    Icons.build_outlined,
    'Stationery':     Icons.edit_note_outlined,
    'Transport':      Icons.directions_bus_outlined,
    'IT & Software':  Icons.devices_outlined,
    'Others':         Icons.more_horiz_outlined,
  };

  IconData _catIcon(String cat) =>
      _catIcons[cat] ?? Icons.receipt_long_outlined;

  List<Expense> get _filteredExpenses {
    final list = _expenses.where((e) {
      if (_selectedCategory != null && e.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = e.title.toLowerCase().contains(q);
        final matchPayee = e.paidTo.toLowerCase().contains(q);
        final matchRemarks = (e.remarks ?? '').toLowerCase().contains(q);
        final matchCat = e.category.toLowerCase().contains(q);
        if (!matchTitle && !matchPayee && !matchRemarks && !matchCat) {
          return false;
        }
      }
      return true;
    }).toList();

    list.sort((a, b) {
      switch (_sortBy) {
        case 'amount_desc':
          return b.amount.compareTo(a.amount);
        case 'amount_asc':
          return a.amount.compareTo(b.amount);
        case 'date_asc':
          return a.date.compareTo(b.date);
        case 'date_desc':
        default:
          return b.date.compareTo(a.date);
      }
    });

    return list;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchExpenses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
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

  Future<void> _showAddDialog() => _showExpenseFormDialog();

  Future<void> _showExpenseFormDialog({Expense? expenseToEdit}) async {
    final isEditing = expenseToEdit != null;
    final titleCtrl   = TextEditingController(text: expenseToEdit?.title ?? '');
    final paidToCtrl  = TextEditingController(text: expenseToEdit?.paidTo ?? '');
    final amountCtrl  = TextEditingController(
      text: expenseToEdit != null
          ? (expenseToEdit.amount.truncateToDouble() == expenseToEdit.amount
              ? expenseToEdit.amount.toInt().toString()
              : expenseToEdit.amount.toString())
          : '',
    );
    final remarksCtrl = TextEditingController(text: expenseToEdit?.remarks ?? '');
    String? category = expenseToEdit?.category;
    DateTime date = expenseToEdit?.date ?? DateTime.now();
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (isEditing ? AppColors.info : AppColors.navy)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEditing ? Icons.edit_note_rounded : Icons.receipt_long_rounded,
                        color: isEditing ? AppColors.info : AppColors.navy,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit School Expense' : 'Add School Expense',
                            style: GoogleFonts.cormorantGaramond(
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                                color: AppColors.navy),
                          ),
                          Text(
                            isEditing
                                ? 'Update payment record details or remarks'
                                : 'Record outgoings, vendor bills, or utility payments',
                            style: GoogleFonts.nunitoSans(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                      onPressed: isSaving ? null : () => Navigator.pop(ctx),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 20),

                  // Title field
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Expense Title *',
                      hintText: 'e.g., Science Lab Equipment, Diesel, Staff Salary',
                      prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category dropdown
                  SearchableDropdownFormField<String>(
                    labelText: 'Category *',
                    hintText: 'Select or search category…',
                    initialValue: category,
                    items: _categories,
                    onChanged: (v) => setDlg(() => category = v),
                  ),
                  const SizedBox(height: 8),

                  // Quick Category chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _categories.take(6).map((cat) {
                      final selected = category == cat;
                      final col = _catColor(cat);
                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_catIcon(cat), size: 13,
                                color: selected ? Colors.white : col),
                            const SizedBox(width: 4),
                            Text(cat, style: GoogleFonts.nunitoSans(fontSize: 11)),
                          ],
                        ),
                        selected: selected,
                        selectedColor: col,
                        backgroundColor: col.withValues(alpha: 0.08),
                        labelStyle: TextStyle(
                            color: selected ? Colors.white : AppColors.textPrimary,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                        onSelected: (val) {
                          setDlg(() => category = val ? cat : null);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Amount and Paid To row
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: TextField(
                        controller: amountCtrl,
                        decoration: InputDecoration(
                          labelText: 'Amount (₹) *',
                          hintText: '0.00',
                          prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: paidToCtrl,
                        decoration: InputDecoration(
                          labelText: 'Paid To *',
                          hintText: 'e.g., Ramesh Sharma, BESCOM',
                          prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Date selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                      color: AppColors.creamDark,
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppColors.navy),
                      const SizedBox(width: 10),
                      Text('Payment Date: ',
                          style: GoogleFonts.nunitoSans(
                              color: AppColors.textSecondary, fontSize: 13)),
                      Text(_dateFmt.format(date),
                          style: GoogleFonts.nunitoSans(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontSize: 13)),
                      const Spacer(),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit_calendar_outlined, size: 15),
                        label: const Text('Change Date'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.navy,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: ctx,
                            initialDate: date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            builder: _dpTheme,
                          );
                          if (p != null) setDlg(() => date = p);
                        },
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Remarks
                  TextField(
                    controller: remarksCtrl,
                    decoration: InputDecoration(
                      labelText: 'Remarks / Invoice No. (Optional)',
                      hintText: 'e.g., Bill #4092, Paid via UPI',
                      prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                      onPressed: isSaving ? null : () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (titleCtrl.text.trim().isEmpty ||
                                  category == null ||
                                  amountCtrl.text.trim().isEmpty ||
                                  paidToCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Please fill all required fields.')),
                                );
                                return;
                              }
                              setDlg(() => isSaving = true);
                              final expense = Expense(
                                id:       expenseToEdit?.id,
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
                                if (isEditing && expenseToEdit.id != null) {
                                  await FeeApiService.updateExpense(
                                      expenseToEdit.id!, expense);
                                } else {
                                  await FeeApiService.addExpense(expense);
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                                _fetchExpenses();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(isEditing
                                            ? 'Expense updated successfully!'
                                            : 'Expense added successfully!'),
                                        backgroundColor: AppColors.success),
                                  );
                                }
                              } catch (e) {
                                setDlg(() => isSaving = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Failed: $e'),
                                        backgroundColor: AppColors.error),
                                  );
                                }
                              }
                            },
                      icon: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(isSaving
                          ? (isEditing ? 'Updating…' : 'Saving…')
                          : (isEditing ? 'Update Expense' : 'Save Expense')),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showViewDialog(Expense expense) async {
    final col = _catColor(expense.category);
    final icon = _catIcon(expense.category);

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Voucher Header
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: col.withValues(alpha: 0.25)),
                    ),
                    child: Icon(icon, color: col, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Expense Voucher',
                            style: GoogleFonts.cormorantGaramond(
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                                color: AppColors.navy)),
                        Text(
                          expense.id != null
                              ? 'Ref: #${expense.id!.length > 8 ? expense.id!.substring(0, 8) : expense.id!}'
                              : 'Official School Outgoing Record',
                          style: GoogleFonts.nunitoSans(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
                const SizedBox(height: 18),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 18),

                // Amount Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.creamDark,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Amount Paid',
                            style: GoogleFonts.nunitoSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(_currency.format(expense.amount),
                            style: GoogleFonts.cormorantGaramond(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error)),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: col.withValues(alpha: 0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(icon, size: 14, color: col),
                          const SizedBox(width: 5),
                          Text(expense.category,
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: col)),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Details Rows
                _voucherRow('Title / Purpose', expense.title, Icons.description_outlined),
                const SizedBox(height: 12),
                _voucherRow('Beneficiary / Paid To', expense.paidTo, Icons.business_outlined),
                const SizedBox(height: 12),
                _voucherRow('Payment Date', _dateFmt.format(expense.date), Icons.calendar_today_outlined),
                if (expense.remarks != null && expense.remarks!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _voucherRow('Remarks / Invoice', expense.remarks!, Icons.sticky_note_2_outlined),
                ],
                const SizedBox(height: 24),

                // Actions: Delete, Close, Edit
                Row(children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _delete(expense);
                    },
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                    label: const Text('Delete', style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showExpenseFormDialog(expenseToEdit: expense);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Expense'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _voucherRow(String label, String value, IconData icon) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: AppColors.textLight),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.nunitoSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 1),
          Text(value,
              style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ]),
      ),
    ]);
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Page header ─────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Expenses',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 26,
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
                    horizontal: 18, vertical: 10)),
          ),
        ]),
        const SizedBox(height: 12),
        // ── Tab bar (Segmented pill) ────────────────────────────────
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 300,
            height: 38,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.creamDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(17),
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
        ),
        const SizedBox(height: 12),
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

    final filtered = _filteredExpenses;
    final totalFiltered = filtered.fold<double>(0, (s, e) => s + e.amount);

    // Category breakdown maps
    final Map<String, int> catCounts = {};
    final Map<String, double> catTotals = {};
    for (final e in _expenses) {
      catCounts[e.category] = (catCounts[e.category] ?? 0) + 1;
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }

    // Top Category
    String? topCategory;
    double topCategoryAmount = 0;
    catTotals.forEach((cat, amt) {
      if (amt > topCategoryAmount) {
        topCategoryAmount = amt;
        topCategory = cat;
      }
    });

    final hasActiveFilter =
        _selectedCategory != null || _searchQuery.isNotEmpty || _filterMonth != null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── 1. Summary Metrics Cards ──────────────────────────────────
      LayoutBuilder(builder: (ctx, constraints) {
        final isWide = constraints.maxWidth > 720;
        final metrics = [
          _buildMetricCard(
            label: _selectedCategory != null
                ? '$_selectedCategory Spend'
                : 'Total Spend',
            value: _currency.format(totalFiltered),
            subtitle: _filterMonth != null
                ? _monthLabel(_filterMonth!)
                : '${filtered.length} transactions',
            icon: Icons.trending_down_rounded,
            color: AppColors.error,
          ),
          _buildMetricCard(
            label: 'Transactions',
            value: '${filtered.length}',
            subtitle: _expenses.length == filtered.length
                ? 'Total recorded'
                : 'Filtered from ${_expenses.length}',
            icon: Icons.receipt_long_outlined,
            color: AppColors.navy,
          ),
          _buildMetricCard(
            label: 'Top Category',
            value: topCategory ?? 'None',
            subtitle: topCategoryAmount > 0
                ? _currency.format(topCategoryAmount)
                : 'No data',
            icon: _catIcon(topCategory ?? 'Others'),
            color: _catColor(topCategory ?? 'Others'),
          ),
          _buildMetricCard(
            label: 'Average / Item',
            value: filtered.isNotEmpty
                ? _currency.format(totalFiltered / filtered.length)
                : '₹0',
            subtitle: 'Average transaction size',
            icon: Icons.query_stats_rounded,
            color: AppColors.info,
          ),
        ];

        if (isWide) {
          return Row(
            children: metrics
                .map((m) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: m,
                      ),
                    ))
                .toList(),
          );
        }
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: metrics,
        );
      }),
      const SizedBox(height: 16),

      // ── 2. Search & Filter Bar ────────────────────────────────────
      Row(children: [
        // Search textfield
        Expanded(
          flex: 3,
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              style: GoogleFonts.nunitoSans(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by title, payee, or notes…',
                hintStyle: GoogleFonts.nunitoSans(
                    fontSize: 13, color: AppColors.textLight),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Month Picker Chip
        InkWell(
          onTap: _pickFilterMonth,
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _filterMonth != null ? AppColors.navy : Colors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
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
              const SizedBox(width: 8),
              Text(
                _filterMonth != null
                    ? _monthLabel(_filterMonth!)
                    : 'All Months',
                style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _filterMonth != null
                        ? Colors.white
                        : AppColors.textPrimary),
              ),
              if (_filterMonth != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _clearFilter,
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(width: 10),

        // Sort popup
        PopupMenuButton<String>(
          initialValue: _sortBy,
          tooltip: 'Sort Expenses',
          onSelected: (val) => setState(() => _sortBy = val),
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'date_desc', child: Text('Date: Newest first')),
            PopupMenuItem(value: 'date_asc', child: Text('Date: Oldest first')),
            PopupMenuItem(value: 'amount_desc', child: Text('Amount: High to Low')),
            PopupMenuItem(value: 'amount_asc', child: Text('Amount: Low to High')),
          ],
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.sort_rounded, size: 16, color: AppColors.navy),
              const SizedBox(width: 6),
              Text(
                _sortLabel(_sortBy),
                style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const Icon(Icons.arrow_drop_down,
                  size: 18, color: AppColors.textSecondary),
            ]),
          ),
        ),

        // Reset Filter Action
        if (hasActiveFilter) ...[
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: () {
              _searchCtrl.clear();
              setState(() {
                _searchQuery = '';
                _selectedCategory = null;
                _filterMonth = null;
              });
              _fetchExpenses();
            },
            icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
            label: const Text('Reset'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              textStyle: GoogleFonts.nunitoSans(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 12),

      // ── 3. Horizontal Category Filter Pills ───────────────────────
      SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            // "All" chip
            _buildCategoryFilterChip(
              label: 'All Categories',
              count: _expenses.length,
              icon: Icons.dashboard_outlined,
              color: AppColors.navy,
              isSelected: _selectedCategory == null,
              onTap: () => setState(() => _selectedCategory = null),
            ),
            const SizedBox(width: 8),

            // Individual category chips
            ..._categories.map((cat) {
              final isSel = _selectedCategory == cat;
              final col = _catColor(cat);
              final icon = _catIcon(cat);
              final count = catCounts[cat] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildCategoryFilterChip(
                  label: cat,
                  count: count,
                  icon: icon,
                  color: col,
                  isSelected: isSel,
                  onTap: () {
                    setState(() {
                      _selectedCategory = isSel ? null : cat;
                    });
                  },
                ),
              );
            }),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // ── 4. Expense List View ──────────────────────────────────────
      Expanded(
        child: filtered.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: AppColors.creamDark,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          hasActiveFilter
                              ? Icons.filter_list_off_rounded
                              : Icons.receipt_long_outlined,
                          size: 28,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        hasActiveFilter
                            ? 'No expenses match your filters'
                            : 'No expenses recorded yet',
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasActiveFilter
                            ? 'Try clearing search terms or selecting another category.'
                            : 'Click "Add Expense" above to record your first operational expense.',
                        style: GoogleFonts.nunitoSans(
                            color: AppColors.textSecondary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      if (hasActiveFilter) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: const Text('Clear All Filters'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.navy,
                            side: const BorderSide(color: AppColors.navy),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            textStyle: GoogleFonts.nunitoSans(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _searchQuery = '';
                              _selectedCategory = null;
                              _filterMonth = null;
                            });
                            _fetchExpenses();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final e = filtered[i];
                  final col = _catColor(e.category);
                  final icon = _catIcon(e.category);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showViewDialog(e),
                      borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Squircle category icon
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: col.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: col.withValues(alpha: 0.25), width: 1),
                                ),
                                child: Icon(icon, color: col, size: 24),
                              ),
                              const SizedBox(width: 14),

                              // Title, tags & details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                        child: Text(
                                          e.title,
                                          style: GoogleFonts.nunitoSans(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: AppColors.textPrimary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // Category Pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: col.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                              color: col.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: col,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              e.category,
                                              style: GoogleFonts.nunitoSans(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: col),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ]),
                                    const SizedBox(height: 6),

                                    // Payee & Date metadata
                                    Row(children: [
                                      Icon(Icons.business_outlined,
                                          size: 13,
                                          color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Paid to: ${e.paidTo}',
                                        style: GoogleFonts.nunitoSans(
                                            fontSize: 12,
                                            color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(Icons.calendar_today_outlined,
                                          size: 12,
                                          color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        _dateFmt.format(e.date),
                                        style: GoogleFonts.nunitoSans(
                                            fontSize: 12,
                                            color: AppColors.textSecondary),
                                      ),
                                    ]),

                                    // Optional remarks preview
                                    if (e.remarks != null &&
                                        e.remarks!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.creamDark,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                                Icons.sticky_note_2_outlined,
                                                size: 12,
                                                color: AppColors.textSecondary),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                e.remarks!,
                                                style: GoogleFonts.nunitoSans(
                                                    fontSize: 11,
                                                    fontStyle: FontStyle.italic,
                                                    color:
                                                        AppColors.textSecondary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Amount and Action buttons (View, Edit, Delete)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _currency.format(e.amount),
                                    style: GoogleFonts.cormorantGaramond(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.error),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility_outlined,
                                            color: AppColors.textSecondary, size: 17),
                                        tooltip: 'View Voucher',
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _showViewDialog(e),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined,
                                            color: AppColors.navy, size: 17),
                                        tooltip: 'Edit Expense',
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                        onPressed: () =>
                                            _showExpenseFormDialog(expenseToEdit: e),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded,
                                            color: AppColors.error, size: 17),
                                        tooltip: 'Delete Expense',
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _delete(e),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  // ── Helper Widgets for Expenses Tab ─────────────────────────────────

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: GoogleFonts.nunitoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 1),
              Text(value,
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis),
              Text(subtitle,
                  style: GoogleFonts.nunitoSans(
                      fontSize: 10, color: AppColors.textLight),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildCategoryFilterChip({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: isSelected ? Colors.white : color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.nunitoSans(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.25)
                  : AppColors.creamDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.nunitoSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  String _sortLabel(String sort) {
    switch (sort) {
      case 'date_asc':
        return 'Oldest first';
      case 'amount_desc':
        return 'Amount: High';
      case 'amount_asc':
        return 'Amount: Low';
      case 'date_desc':
      default:
        return 'Newest first';
    }
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: col.withValues(alpha: 0.2)),
                    ),
                    child: Icon(_catIcon(entry.key), color: col, size: 18),
                  ),
                  const SizedBox(width: 12),
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
                          backgroundColor: col.withValues(alpha: 0.12),
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
