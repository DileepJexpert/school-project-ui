import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';

// Holds stable TextEditingControllers for one fee component row.
// Created once per component — survives StatefulBuilder rebuilds.
class _ComponentEntry {
  final TextEditingController nameCtrl;
  final TextEditingController amtCtrl;
  String frequency;

  _ComponentEntry({String name = '', double amount = 0, String frequency = 'YEARLY'})
      : nameCtrl = TextEditingController(text: name),
        amtCtrl = TextEditingController(text: amount > 0 ? amount.toStringAsFixed(0) : ''),
        frequency = frequency;

  FeeComponent toComponent() => FeeComponent(
        name: nameCtrl.text.trim(),
        amount: double.tryParse(amtCtrl.text.trim()) ?? 0,
        frequency: frequency,
      );

  void dispose() {
    nameCtrl.dispose();
    amtCtrl.dispose();
  }
}

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

  static const _classes = [
    'Nursery', 'LKG', 'UKG',
    'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6',
    'Class 7', 'Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12',
  ];
  static const _sections = ['A', 'B'];
  static const _frequencies = ['YEARLY', 'MONTHLY', 'ONE_TIME'];

  // Pre-primary classes have no meaningful section
  static const _noSection = ['Nursery', 'LKG', 'UKG'];

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

  // Parse "Class 5 - B" → ('Class 5', 'B')  or "Nursery" → ('Nursery', 'A')
  (String, String) _parseClassName(String className) {
    final parts = className.split(' - ');
    if (parts.length >= 2) {
      final cls = parts[0].trim();
      final sec = parts[1].trim();
      return (_classes.contains(cls) ? cls : _classes.first, sec);
    }
    return (_classes.contains(className) ? className : _classes.first, 'A');
  }

  void _showAddOrEditDialog({FeeStructure? existing}) {
    final isEdit = existing != null;

    // Parse existing class + section
    var (selectedClass, selectedSection) = existing != null
        ? _parseClassName(existing.className)
        : (_classes.first, 'A');

    // Build persistent component entries — created once, not on every rebuild
    final entries = existing != null
        ? existing.components
            .map((c) => _ComponentEntry(name: c.name, amount: c.amount, frequency: c.frequency))
            .toList()
        : <_ComponentEntry>[];

    void disposeAll() { for (final e in entries) e.dispose(); }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        final bool showSection = !_noSection.contains(selectedClass);

        return AlertDialog(
          title: Text(isEdit ? 'Edit Fee Structure' : 'Add Fee Structure',
              style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // ── Class + Section Row ───────────────────────────────────
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: selectedClass,
                      decoration: const InputDecoration(
                        labelText: 'Class *',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      items: _classes
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setDlg(() {
                        selectedClass = v!;
                        // Reset section if switching to pre-primary
                        if (_noSection.contains(selectedClass)) selectedSection = 'A';
                      }),
                    ),
                  ),
                  if (showSection) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: selectedSection,
                        decoration: const InputDecoration(
                          labelText: 'Section *',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        items: _sections
                            .map((s) => DropdownMenuItem(value: s, child: Text('Section $s')))
                            .toList(),
                        onChanged: (v) => setDlg(() => selectedSection = v!),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 12),
                // ── Academic Year (read-only) ─────────────────────────────
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Academic Year',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  child: Text(_selectedYear, style: GoogleFonts.nunitoSans(fontSize: 15)),
                ),
                const SizedBox(height: 16),
                // ── Fee Components header ─────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Fee Components',
                      style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w700, color: AppColors.navy)),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Component'),
                    onPressed: () => setDlg(() => entries.add(_ComponentEntry())),
                  ),
                ]),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('No components yet. Tap "Add Component".',
                        style: GoogleFonts.nunitoSans(
                            color: AppColors.textLight, fontSize: 13)),
                  ),
                // ── Component Rows (stable controllers) ───────────────────
                ...entries.asMap().entries.map((entry) {
                  final i = entry.key;
                  final comp = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: comp.nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Fee Name *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: comp.amtCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Amount ₹ *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: comp.frequency,
                          decoration: const InputDecoration(
                            labelText: 'Frequency',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                          items: _frequencies
                              .map((f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(f, style: const TextStyle(fontSize: 12)),
                                  ))
                              .toList(),
                          // Only update frequency, doesn't recreate controllers
                          onChanged: (v) => setDlg(() => comp.frequency = v!),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                        onPressed: () {
                          entries[i].dispose();
                          setDlg(() => entries.removeAt(i));
                        },
                      ),
                    ]),
                  );
                }),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () { disposeAll(); Navigator.pop(ctx); },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy, foregroundColor: Colors.white),
              onPressed: () async {
                // Validate
                if (entries.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Add at least one fee component.')),
                  );
                  return;
                }
                final invalidEntry = entries.any(
                    (e) => e.nameCtrl.text.trim().isEmpty || e.amtCtrl.text.trim().isEmpty);
                if (invalidEntry) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All components need a name and amount.')),
                  );
                  return;
                }

                // Build class name: "Class 5 - A" or just "Nursery"
                final fullClassName = _noSection.contains(selectedClass)
                    ? selectedClass
                    : '$selectedClass - $selectedSection';

                final structure = FeeStructure(
                  id: existing?.id,
                  className: fullClassName,
                  academicYear: _selectedYear,
                  components: entries.map((e) => e.toComponent()).toList(),
                );

                try {
                  if (isEdit && existing!.id != null) {
                    await FeeApiService.updateFeeStructure(existing.id!, structure);
                  } else {
                    await FeeApiService.saveFeeStructure(structure);
                  }
                  disposeAll();
                  if (ctx.mounted) Navigator.pop(ctx);
                  _fetch();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Save failed: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
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
              items: _years
                  .map((y) => DropdownMenuItem(
                        value: y,
                        child: Text(y, style: GoogleFonts.nunitoSans(color: Colors.white)),
                      ))
                  .toList(),
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
                        Text('Tap + to create one.',
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
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.gold)),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        color: AppColors.navy, size: 18),
                                    onPressed: () => _showAddOrEditDialog(existing: s),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: AppColors.error, size: 18),
                                    onPressed: () => _delete(s),
                                  ),
                                ]),
                                children: s.components.map((c) => ListTile(
                                      title: Text(c.name, style: GoogleFonts.nunitoSans()),
                                      subtitle: Text(c.frequency,
                                          style: GoogleFonts.nunitoSans(
                                              fontSize: 11, color: AppColors.textLight)),
                                      trailing: Text(_fmt.format(c.amount),
                                          style: GoogleFonts.nunitoSans(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary)),
                                      dense: true,
                                    )).toList(),
                              ),
                            )),
                      ]),
                    ),
    );
  }
}
