import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/academic_year.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';
import '../../../core/widgets/searchable_dropdown.dart';

// Holds stable TextEditingControllers for one fee component row.
// Created once per component — survives StatefulBuilder rebuilds.
class _ComponentEntry {
  final TextEditingController nameCtrl;
  final TextEditingController amtCtrl;
  String frequency;

  _ComponentEntry(
      {String name = '', double amount = 0, String frequency = 'YEARLY'})
      : nameCtrl = TextEditingController(text: name),
        amtCtrl = TextEditingController(
            text: amount > 0 ? amount.toStringAsFixed(0) : ''),
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
  String _selectedYear = AcademicYear.currentLong();
  int _fetchGeneration = 0;
  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  List<String> get _years => AcademicYear.choices(include: _selectedYear);

  static const _frequencies = ['YEARLY', 'MONTHLY', 'ONE_TIME'];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final generation = ++_fetchGeneration;
    final year = _selectedYear;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final data = await FeeApiService.getFeeStructures(year: year);
      if (mounted && generation == _fetchGeneration && year == _selectedYear) {
        setState(() => _structures = data);
      }
    } catch (_) {
      if (mounted && generation == _fetchGeneration) {
        setState(
            () => _error = 'Fee structures could not be loaded right now.');
      }
    } finally {
      if (mounted && generation == _fetchGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  void _showAddOrEditDialog({FeeStructure? existing}) {
    final isEdit = existing != null;
    bool saving = false;

    // Parse existing class + section using shared SchoolConstants
    var (selectedClass, selectedSection) = existing != null
        ? SchoolConstants.parseClassName(existing.className)
        : (SchoolConstants.baseClasses.first, SchoolConstants.sections.first);

    // Build persistent component entries — created once, not on every rebuild
    final entries = existing != null
        ? existing.components
            .map((c) => _ComponentEntry(
                name: c.name, amount: c.amount, frequency: c.frequency))
            .toList()
        : <_ComponentEntry>[];

    final availableFeeNames = (() {
      final namesSet = <String>{...SchoolConstants.masterFeeComponents};
      for (final s in _structures) {
        for (final c in s.components) {
          if (c.name.trim().isNotEmpty) {
            namesSet.add(c.name.trim());
          }
        }
      }
      return namesSet.toList();
    })();

    void disposeAll() {
      for (final e in entries) e.dispose();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        final bool showSection =
            !SchoolConstants.noSectionClasses.contains(selectedClass);

        return AlertDialog(
          title: Text(isEdit ? 'Edit Fee Structure' : 'Add Fee Structure',
              style:
                  GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // ── Class + Section Row ───────────────────────────────────
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: SearchableDropdownFormField<String>(
                      labelText: 'Class *',
                      initialValue: selectedClass,
                      items: SchoolConstants.baseClasses,
                      onChanged: (v) => setDlg(() {
                        selectedClass = v!;
                        if (SchoolConstants.noSectionClasses
                            .contains(selectedClass)) {
                          selectedSection = SchoolConstants.sections.first;
                        }
                      }),
                    ),
                  ),
                  if (showSection) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SearchableDropdownFormField<String>(
                        labelText: 'Section *',
                        initialValue: selectedSection,
                        items: SchoolConstants.sections,
                        itemLabel: (s) => 'Section $s',
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
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  child: Text(_selectedYear,
                      style: GoogleFonts.nunitoSans(fontSize: 15)),
                ),
                const SizedBox(height: 16),
                // ── Fee Components header ─────────────────────────────────
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Fee Components',
                          style: GoogleFonts.nunitoSans(
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy)),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Component'),
                        onPressed: () =>
                            setDlg(() => entries.add(_ComponentEntry())),
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
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: RawAutocomplete<String>(
                              textEditingController: comp.nameCtrl,
                              focusNode: FocusNode(),
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                final query = textEditingValue.text.trim();
                                if (query.isEmpty) {
                                  return availableFeeNames;
                                }
                                final matches = availableFeeNames
                                    .where((name) => name
                                        .toLowerCase()
                                        .contains(query.toLowerCase()))
                                    .toList();
                                if (!availableFeeNames.any((name) =>
                                    name.toLowerCase() ==
                                    query.toLowerCase())) {
                                  matches.add('+ Add "$query"');
                                }
                                return matches;
                              },
                              onSelected: (String selection) {
                                if (selection.startsWith('+ Add "') &&
                                    selection.endsWith('"')) {
                                  final customName = selection.substring(
                                      7, selection.length - 1);
                                  comp.nameCtrl.text = customName;
                                } else {
                                  comp.nameCtrl.text = selection;
                                }
                              },
                              fieldViewBuilder: (context, controller, focusNode,
                                  onFieldSubmitted) {
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Fee Name *',
                                    hintText: 'Select or type fee name',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 12),
                                  ),
                                );
                              },
                              optionsViewBuilder:
                                  (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 6,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 230,
                                      constraints:
                                          const BoxConstraints(maxHeight: 220),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border:
                                            Border.all(color: AppColors.border),
                                      ),
                                      child: ListView.separated(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final option =
                                              options.elementAt(index);
                                          final isAddCustom =
                                              option.startsWith('+ Add "');
                                          return InkWell(
                                            onTap: () => onSelected(option),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isAddCustom
                                                        ? Icons
                                                            .add_circle_outline
                                                        : Icons.sell_outlined,
                                                    size: 16,
                                                    color: isAddCustom
                                                        ? AppColors.gold
                                                        : AppColors.navy,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      option,
                                                      style: GoogleFonts
                                                          .nunitoSans(
                                                        fontSize: 13,
                                                        fontWeight: isAddCustom
                                                            ? FontWeight.w700
                                                            : FontWeight.w500,
                                                        color: isAddCustom
                                                            ? AppColors.gold
                                                            : AppColors
                                                                .textPrimary,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
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
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 12),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: comp.frequency,
                              decoration: const InputDecoration(
                                labelText: 'Frequency',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 12),
                              ),
                              items: _frequencies
                                  .map((f) => DropdownMenuItem(
                                        value: f,
                                        child: Text(f,
                                            style:
                                                const TextStyle(fontSize: 12)),
                                      ))
                                  .toList(),
                              // Only update frequency, doesn't recreate controllers
                              onChanged: (v) =>
                                  setDlg(() => comp.frequency = v!),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: AppColors.error),
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
              onPressed: () {
                disposeAll();
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white),
              onPressed: saving
                  ? null
                  : () async {
                      // Validate
                      if (entries.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Add at least one fee component.')),
                        );
                        return;
                      }
                      final invalidEntry = entries.any((e) =>
                          e.nameCtrl.text.trim().isEmpty ||
                          e.amtCtrl.text.trim().isEmpty);
                      if (invalidEntry) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'All components need a name and amount.')),
                        );
                        return;
                      }
                      final amounts = entries
                          .map((e) => double.tryParse(e.amtCtrl.text.trim()))
                          .toList();
                      if (amounts
                          .any((a) => a == null || !a.isFinite || a <= 0)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Fee amounts must be positive numbers.')),
                        );
                        return;
                      }
                      final names = entries
                          .map((e) => e.nameCtrl.text.trim().toLowerCase())
                          .toSet();
                      if (names.length != entries.length) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Fee component names must be unique.')),
                        );
                        return;
                      }

                      // Build stored class name via SchoolConstants helper
                      final fullClassName = SchoolConstants.buildClassName(
                          selectedClass, selectedSection);

                      if (!isEdit &&
                          _structures.any((s) =>
                              s.className == fullClassName &&
                              s.academicYear == _selectedYear)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'A fee structure already exists for this class and year.')),
                        );
                        return;
                      }

                      final structure = FeeStructure(
                        id: existing?.id,
                        className: fullClassName,
                        academicYear: _selectedYear,
                        components:
                            entries.map((e) => e.toComponent()).toList(),
                      );

                      setDlg(() => saving = true);
                      try {
                        final existingId = existing?.id;
                        if (existingId != null) {
                          await FeeApiService.updateFeeStructure(
                              existingId, structure);
                        } else {
                          await FeeApiService.saveFeeStructure(structure);
                        }
                        disposeAll();
                        if (ctx.mounted) Navigator.pop(ctx);
                        _fetch();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEdit
                                  ? 'Fee structure updated for ${structure.className}.'
                                  : 'Fee structure saved for ${structure.className}.'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Save failed: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setDlg(() => saving = false);
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
        content: Text(
            'Delete fee structure for ${s.className} (${s.academicYear})?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
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
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Fee structure could not be deleted. Please retry.'),
                backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.brand,
        foregroundColor: Colors.white,
        title: Text('Fee Structure Setup',
            style: GoogleFonts.cormorantGaramond(
                fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: DropdownButton<String>(
              value: _selectedYear,
              dropdownColor: palette.brand,
              style: GoogleFonts.nunitoSans(color: Colors.white),
              iconEnabledColor: Colors.white,
              underline: const SizedBox(),
              items: _years
                  .map((y) => DropdownMenuItem(
                        value: y,
                        child: Text(y,
                            style: GoogleFonts.nunitoSans(color: Colors.white)),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() => _selectedYear = v!);
                _fetch();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: palette.brand,
        foregroundColor: Colors.white,
        onPressed: _showAddOrEditDialog,
        icon: const Icon(Icons.add),
        label: Text('Add Structure',
            style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(22),
                    constraints: const BoxConstraints(maxWidth: 460),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.25)),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.cloud_off_rounded,
                          size: 42,
                          color: AppColors.error.withValues(alpha: 0.8)),
                      const SizedBox(height: 12),
                      Text('Could not load fee structures',
                          style: GoogleFonts.nunitoSans(
                              color: palette.brand,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(_error,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunitoSans(
                              color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                          onPressed: _fetch,
                          icon: const Icon(Icons.refresh_rounded, size: 17),
                          label: const Text('Retry')),
                    ]),
                  ),
                )
              : _structures.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_outlined,
                                size: 64, color: AppColors.textLight),
                            const SizedBox(height: 16),
                            Text('No fee structures for $_selectedYear.',
                                style: GoogleFonts.nunitoSans(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Set up a fee structure for each class before admitting students. '
                                'Students admitted without a matching fee structure will have no fee profile generated.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunitoSans(
                                    color: AppColors.textLight, fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.navy,
                                  foregroundColor: Colors.white),
                              icon: const Icon(Icons.add),
                              label: const Text('Add First Fee Structure'),
                              onPressed: _showAddOrEditDialog,
                            ),
                          ]),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: palette.heroGradient,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusLG),
                          ),
                          child: Wrap(
                            spacing: 28,
                            runSpacing: 14,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _setupSummary(
                                  'Configured classes',
                                  '${_structures.length}',
                                  Icons.school_outlined),
                              _setupSummary(
                                  'Fee heads',
                                  '${_structures.fold<int>(0, (sum, item) => sum + item.components.length)}',
                                  Icons.account_balance_wallet_outlined),
                              _setupSummary('Academic year', _selectedYear,
                                  Icons.calendar_month_outlined),
                            ],
                          ),
                        ),
                        ..._structures.map((s) => Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppSizes.radiusLG)),
                              child: ExpansionTile(
                                title: Text(s.className,
                                    style: GoogleFonts.nunitoSans(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy)),
                                subtitle: Text(s.academicYear,
                                    style: GoogleFonts.nunitoSans(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                                trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_fmt.format(s.totalFee),
                                          style: GoogleFonts.cormorantGaramond(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.gold)),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined,
                                            color: AppColors.navy, size: 18),
                                        onPressed: () =>
                                            _showAddOrEditDialog(existing: s),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: AppColors.error, size: 18),
                                        onPressed: () => _delete(s),
                                      ),
                                    ]),
                                children: s.components
                                    .map((c) => ListTile(
                                          title: Text(c.name,
                                              style: GoogleFonts.nunitoSans()),
                                          subtitle: Text(c.frequency,
                                              style: GoogleFonts.nunitoSans(
                                                  fontSize: 11,
                                                  color: AppColors.textLight)),
                                          trailing: Text(_fmt.format(c.amount),
                                              style: GoogleFonts.nunitoSans(
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      AppColors.textPrimary)),
                                          dense: true,
                                        ))
                                    .toList(),
                              ),
                            )),
                      ]),
                    ),
    );
  }

  Widget _setupSummary(String label, String value, IconData icon) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
      const SizedBox(width: 9),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: GoogleFonts.nunitoSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        Text(label,
            style: GoogleFonts.nunitoSans(
                color: Colors.white.withValues(alpha: 0.78), fontSize: 11)),
      ]),
    ]);
  }
}
