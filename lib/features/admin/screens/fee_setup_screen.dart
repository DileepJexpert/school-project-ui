import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';

class FeeSetupScreen extends StatefulWidget {
  const FeeSetupScreen({super.key});

  @override
  State<FeeSetupScreen> createState() => _FeeSetupScreenState();
}

class _FeeSetupScreenState extends State<FeeSetupScreen> {
  List<FeeStructure> _structures = [];
  bool _loading = true;
  String _error = '';
  String _selectedYear = '2025-2026';
  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  final _years = ['2024-2025', '2025-2026', '2026-2027'];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final data = await FeeApiService.getFeeStructures(year: _selectedYear);
      setState(() => _structures = data);
    } catch (e) {
      setState(() => _error = 'Failed to load fee structures: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showAddOrEditDialog({FeeStructure? existing}) {
    final isEdit = existing != null;
    final classCtrl = TextEditingController(text: existing?.className ?? '');
    final yearCtrl = TextEditingController(text: existing?.academicYear ?? _selectedYear);
    final components = existing != null
        ? existing.components.map((c) => FeeComponent(name: c.name, amount: c.amount)).toList()
        : <FeeComponent>[];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        void addComponent() {
          setDlg(() => components.add(FeeComponent(name: '', amount: 0)));
        }

        return AlertDialog(
          title: Text(isEdit ? 'Edit Fee Structure' : 'Add Fee Structure',
              style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: classCtrl,
                  decoration: const InputDecoration(labelText: 'Class Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yearCtrl,
                  decoration: const InputDecoration(labelText: 'Academic Year *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Fee Components',
                      style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, color: AppColors.navy)),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    onPressed: addComponent,
                  ),
                ]),
                ...components.asMap().entries.map((entry) {
                  final i = entry.key;
                  final comp = entry.value;
                  final nameCtrl = TextEditingController(text: comp.name);
                  final amtCtrl = TextEditingController(text: comp.amount.toStringAsFixed(0));
                  nameCtrl.addListener(() => comp.name = nameCtrl.text);
                  amtCtrl.addListener(() => comp.amount = double.tryParse(amtCtrl.text) ?? 0);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Fee Name', border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: amtCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Amount ₹', border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                        onPressed: () => setDlg(() => components.removeAt(i)),
                      ),
                    ]),
                  );
                }),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy, foregroundColor: Colors.white),
              onPressed: () async {
                if (classCtrl.text.isEmpty || yearCtrl.text.isEmpty) return;
                final structure = FeeStructure(
                  id: existing?.id,
                  className: classCtrl.text.trim(),
                  academicYear: yearCtrl.text.trim(),
                  components: components,
                );
                try {
                  if (isEdit && existing!.id != null) {
                    await FeeApiService.updateFeeStructure(existing.id!, structure);
                  } else {
                    await FeeApiService.saveFeeStructure(structure);
                  }
                  Navigator.pop(ctx);
                  _fetch();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Save failed: $e'), backgroundColor: AppColors.error),
                  );
                }
              },
              child: Text(isEdit ? 'Update' : 'Save'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _delete(FeeStructure s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Fee Structure'),
        content: Text('Delete fee structure for ${s.className} (${s.academicYear})?'),
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
    if (confirmed == true && s.id != null) {
      try {
        await FeeApiService.deleteFeeStructure(s.id!);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text('Fee Structure Setup',
            style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: DropdownButton<String>(
              value: _selectedYear,
              dropdownColor: AppColors.navy,
              style: GoogleFonts.nunitoSans(color: Colors.white),
              iconEnabledColor: Colors.white,
              underline: const SizedBox(),
              items: _years.map((y) => DropdownMenuItem(
                    value: y,
                    child: Text(y, style: GoogleFonts.nunitoSans(color: Colors.white)),
                  )).toList(),
              onChanged: (v) { setState(() => _selectedYear = v!); _fetch(); },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        onPressed: _showAddOrEditDialog,
        icon: const Icon(Icons.add),
        label: Text('Add Structure', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: GoogleFonts.nunitoSans(color: AppColors.error)))
              : _structures.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textLight),
                        const SizedBox(height: 16),
                        Text('No fee structures for $_selectedYear.',
                            style: GoogleFonts.nunitoSans(color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Text('Tap the + button to create one.',
                            style: GoogleFonts.nunitoSans(color: AppColors.textLight, fontSize: 13)),
                      ]),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        ..._structures.map((s) => Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
                              child: ExpansionTile(
                                title: Text(s.className,
                                    style: GoogleFonts.nunitoSans(
                                        fontWeight: FontWeight.w700, color: AppColors.navy)),
                                subtitle: Text(s.academicYear,
                                    style: GoogleFonts.nunitoSans(
                                        color: AppColors.textSecondary, fontSize: 12)),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(_fmt.format(s.totalFee),
                                      style: GoogleFonts.cormorantGaramond(
                                          fontSize: 18, fontWeight: FontWeight.w700,
                                          color: AppColors.gold)),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: AppColors.navy, size: 18),
                                    onPressed: () => _showAddOrEditDialog(existing: s),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                    onPressed: () => _delete(s),
                                  ),
                                ]),
                                children: s.components.map((c) => ListTile(
                                      title: Text(c.name, style: GoogleFonts.nunitoSans()),
                                      trailing: Text(_fmt.format(c.amount),
                                          style: GoogleFonts.nunitoSans(
                                              fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                      dense: true,
                                    )).toList(),
                              ),
                            )),
                      ]),
                    ),
    );
  }
}
