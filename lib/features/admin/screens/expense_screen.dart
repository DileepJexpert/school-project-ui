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

class _ExpenseScreenState extends State<ExpenseScreen> {
  List<Expense> _expenses = [];
  bool _loading = true;
  String _error = '';
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  final _dateFmt = DateFormat('dd MMM yyyy');

  final _categories = [
    'Salaries', 'Infrastructure', 'Utilities', 'Events', 'Maintenance',
    'Stationery', 'Transport', 'IT & Software', 'Others',
  ];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final data = await FeeApiService.getExpenses();
      setState(() => _expenses = data);
    } catch (e) {
      setState(() => _error = 'Failed to load expenses: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  double get _totalAmount => _expenses.fold(0.0, (s, e) => s + e.amount);

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final paidToCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    String? category;
    DateTime date = DateTime.now();
    final fmt = DateFormat('dd MMM yyyy');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          title: Text('Add New Expense',
              style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, fontSize: 22)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Expense Title *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                      labelText: 'Category *', border: OutlineInputBorder()),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDlg(() => category = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Amount (₹) *', border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: paidToCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Paid To *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Text('Date: ${fmt.format(date)}',
                        style: GoogleFonts.nunitoSans(color: AppColors.textSecondary)),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: const Text('Change'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDlg(() => date = picked);
                    },
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: remarksCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Remarks', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy, foregroundColor: Colors.white),
              onPressed: () async {
                if (titleCtrl.text.isEmpty || category == null ||
                    amountCtrl.text.isEmpty || paidToCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fill all required fields.')),
                  );
                  return;
                }
                final expense = Expense(
                  title: titleCtrl.text.trim(),
                  category: category!,
                  amount: double.tryParse(amountCtrl.text) ?? 0.0,
                  date: date,
                  paidTo: paidToCtrl.text.trim(),
                  remarks: remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
                );
                try {
                  await FeeApiService.addExpense(expense);
                  Navigator.pop(ctx);
                  _fetch();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Expense added!'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Save Expense'),
            ),
          ],
        );
      }),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await FeeApiService.deleteExpense(expense.id!);
        _fetch();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Color _categoryColor(String cat) {
    const map = {
      'Salaries': AppColors.navy,
      'Infrastructure': AppColors.info,
      'Utilities': AppColors.warning,
      'Events': AppColors.gold,
      'Maintenance': const Color(0xFF7C3AED),
      'Stationery': AppColors.success,
      'Transport': const Color(0xFF0D9488),
      'IT & Software': const Color(0xFFDB2777),
      'Others': AppColors.textSecondary,
    };
    return map[cat] ?? AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text('Expense Management',
            style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: Text('Add Expense', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: GoogleFonts.nunitoSans(color: AppColors.error)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Total card
                    Card(
                      color: AppColors.navy,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(children: [
                          const Icon(Icons.account_balance_outlined, color: Colors.white, size: 32),
                          const SizedBox(width: 16),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Total Expenses',
                                style: GoogleFonts.nunitoSans(color: Colors.white70, fontSize: 13)),
                            Text(_currency.format(_totalAmount),
                                style: GoogleFonts.cormorantGaramond(
                                    color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                            Text('${_expenses.length} records',
                                style: GoogleFonts.nunitoSans(color: AppColors.goldLight, fontSize: 12)),
                          ]),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_expenses.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48),
                          child: Column(children: [
                            const Icon(Icons.paid_outlined, size: 64, color: AppColors.textLight),
                            const SizedBox(height: 12),
                            Text('No expenses recorded yet.',
                                style: GoogleFonts.nunitoSans(color: AppColors.textSecondary)),
                          ]),
                        ),
                      )
                    else
                      ..._expenses.map((e) => Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _categoryColor(e.category).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                                ),
                                child: Icon(Icons.paid_outlined,
                                    color: _categoryColor(e.category), size: 22),
                              ),
                              title: Text(e.title,
                                  style: GoogleFonts.nunitoSans(
                                      fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              subtitle: Text(
                                '${e.category} · ${e.paidTo} · ${_dateFmt.format(e.date)}',
                                style: GoogleFonts.nunitoSans(
                                    color: AppColors.textSecondary, fontSize: 12),
                              ),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(_currency.format(e.amount),
                                    style: GoogleFonts.cormorantGaramond(
                                        fontSize: 18, fontWeight: FontWeight.w700,
                                        color: AppColors.error)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                  onPressed: () => _delete(e),
                                ),
                              ]),
                            ),
                          )),
                  ]),
                ),
    );
  }
}
