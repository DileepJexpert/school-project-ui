import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';
import 'fee_collection_screen.dart';

enum _DuesSort { highestDue, highestPercent, lowestDue, nameAZ, byClass }

class OutstandingDuesScreen extends StatefulWidget {
  const OutstandingDuesScreen({super.key});

  @override
  State<OutstandingDuesScreen> createState() => _OutstandingDuesScreenState();
}

class _OutstandingDuesScreenState extends State<OutstandingDuesScreen> {
  final _searchCtrl = TextEditingController();
  final _currency = NumberFormat.currency(symbol: '\u20B9', decimalDigits: 0);
  final _dateFmt = DateFormat('dd MMM yyyy');
  final Set<String> _expanded = {};

  List<StudentFeeProfile> _all = [];
  List<StudentFeeProfile> _filtered = [];
  bool _loading = true;
  String? _error;
  String? _classFilter;
  _DuesSort _sort = _DuesSort.highestDue;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyFilter);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _expanded.clear();
    });
    try {
      final data = await FeeApiService.getOutstandingDues();
      if (!mounted) return;
      _all = data;
      _applyFilter();
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load dues: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    if (!mounted) return;
    final query = _searchCtrl.text.trim().toLowerCase();
    final list = _all.where((student) {
      if (_classFilter != null && student.className != _classFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return student.name.toLowerCase().contains(query) ||
          student.rollNumber.toLowerCase().contains(query) ||
          student.className.toLowerCase().contains(query) ||
          student.parentName.toLowerCase().contains(query);
    }).toList();

    list.sort((a, b) {
      return switch (_sort) {
        _DuesSort.highestDue => b.dueFees.compareTo(a.dueFees),
        _DuesSort.lowestDue => a.dueFees.compareTo(b.dueFees),
        _DuesSort.nameAZ => a.name.compareTo(b.name),
        _DuesSort.byClass => a.className.compareTo(b.className),
        _DuesSort.highestPercent => _dueRatio(b).compareTo(_dueRatio(a)),
      };
    });

    setState(() => _filtered = list);
  }

  List<String> get _availableClasses {
    final seen = <String>{};
    return _all
        .map((student) => student.className)
        .where((className) => className.isNotEmpty && seen.add(className))
        .toList()
      ..sort();
  }

  double get _totalDue =>
      _filtered.fold(0.0, (sum, student) => sum + student.dueFees);

  double get _totalPaid =>
      _filtered.fold(0.0, (sum, student) => sum + student.paidFees);

  double get _avgDue => _filtered.isEmpty ? 0 : _totalDue / _filtered.length;

  int get _criticalCount =>
      _filtered.where((student) => _dueRatio(student) >= 0.75).length;

  int get _highCount =>
      _filtered.where((student) => _dueRatio(student) >= 0.5).length;

  double get _collectionCoverage {
    final total = _totalPaid + _totalDue;
    return total <= 0 ? 0 : _totalPaid / total;
  }

  double _dueRatio(StudentFeeProfile student) {
    if (student.totalFees <= 0) return student.dueFees > 0 ? 1 : 0;
    return (student.dueFees / student.totalFees).clamp(0, 1);
  }

  String _studentKey(StudentFeeProfile student) => student.id.isNotEmpty
      ? student.id
      : '${student.name}-${student.className}';

  _Severity _severity(StudentFeeProfile student) {
    final ratio = _dueRatio(student);
    if (ratio >= 0.75) return _Severity.critical;
    if (ratio >= 0.5) return _Severity.high;
    return _Severity.medium;
  }

  Color _severityColor(_Severity severity) => switch (severity) {
        _Severity.critical => AppColors.error,
        _Severity.high => AppColors.warning,
        _Severity.medium => AppColors.info,
      };

  String _severityLabel(_Severity severity) => switch (severity) {
        _Severity.critical => 'Critical',
        _Severity.high => 'High',
        _Severity.medium => 'Medium',
      };

  String get _sortLabel => switch (_sort) {
        _DuesSort.highestDue => 'Highest due',
        _DuesSort.lowestDue => 'Lowest due',
        _DuesSort.highestPercent => 'Highest percent',
        _DuesSort.nameAZ => 'Name A-Z',
        _DuesSort.byClass => 'By class',
      };

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
          'Outstanding Dues',
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState()
              : _content(),
    );
  }

  Widget _content() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _summaryGrid(),
        const SizedBox(height: 14),
        _filterPanel(),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1020;
          if (!wide) {
            return Column(children: [
              _priorityPanel(),
              const SizedBox(height: 14),
              _duesList(),
            ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _duesList()),
            const SizedBox(width: 14),
            SizedBox(width: 340, child: _priorityPanel()),
          ]);
        }),
      ]),
    );
  }

  Widget _summaryGrid() {
    final cards = [
      _SummaryCard(
        label: 'Students With Dues',
        value: '${_filtered.length}',
        caption: _filtered.length == _all.length
            ? 'Avg ${_currency.format(_avgDue)}'
            : 'Filtered from ${_all.length}',
        icon: Icons.people_alt_outlined,
        color: AppColors.error,
      ),
      _SummaryCard(
        label: 'Total Outstanding',
        value: _currency.format(_totalDue),
        caption: 'Pending collection',
        icon: Icons.pending_actions_rounded,
        color: AppColors.warning,
      ),
      _SummaryCard(
        label: 'High Risk',
        value: '$_highCount',
        caption: '50% or more unpaid',
        icon: Icons.priority_high_rounded,
        color: AppColors.error,
      ),
      _SummaryCard(
        label: 'Collection Coverage',
        value: '${(_collectionCoverage * 100).toStringAsFixed(0)}%',
        caption: 'Paid against selected dues',
        icon: Icons.trending_up_rounded,
        color: AppColors.success,
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final columns = Responsive.isDesktop(context)
          ? 4
          : constraints.maxWidth > 680
              ? 2
              : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards
            .map((card) => SizedBox(width: width, child: _summaryCard(card)))
            .toList(),
      );
    });
  }

  Widget _summaryCard(_SummaryCard card) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: card.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            ),
            child: Icon(card.icon, color: card.color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                card.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                card.label,
                style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                card.caption,
                style: GoogleFonts.nunitoSans(
                  fontSize: 11,
                  color: card.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _filterPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search student, roll number, class or parent...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: _searchCtrl.clear,
                        ),
                  fillColor: context.palette.canvas,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _sortMenu(),
          ]),
          if (_availableClasses.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _classChip('All', _classFilter == null, () {
                  setState(() => _classFilter = null);
                  _applyFilter();
                }),
                ..._availableClasses.map((className) => _classChip(
                      className,
                      _classFilter == className,
                      () {
                        setState(() => _classFilter = className);
                        _applyFilter();
                      },
                    )),
              ]),
            ),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.filter_alt_outlined,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _resultLabel,
                style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_hasActiveFilters)
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
                label: const Text('Clear'),
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _sortMenu() {
    return PopupMenuButton<_DuesSort>(
      onSelected: (value) {
        setState(() => _sort = value);
        _applyFilter();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _DuesSort.highestDue,
          child: Text('Highest due first'),
        ),
        PopupMenuItem(
          value: _DuesSort.highestPercent,
          child: Text('Highest unpaid percent'),
        ),
        PopupMenuItem(
          value: _DuesSort.lowestDue,
          child: Text('Lowest due first'),
        ),
        PopupMenuItem(value: _DuesSort.nameAZ, child: Text('Name A-Z')),
        PopupMenuItem(value: _DuesSort.byClass, child: Text('By class')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: context.palette.canvas,
          border: Border.all(color: context.palette.border),
          borderRadius: BorderRadius.circular(AppSizes.radiusSM),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sort_rounded, size: 17, color: context.palette.brand),
          const SizedBox(width: 6),
          Text(
            _sortLabel,
            style: GoogleFonts.nunitoSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 17),
        ]),
      ),
    );
  }

  Widget _classChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? context.palette.brand.withValues(alpha: 0.1)
                : context.palette.canvas,
            border: Border.all(
              color: selected ? context.palette.brand : context.palette.border,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          ),
          child: Text(
            label,
            style: GoogleFonts.nunitoSans(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              color: selected ? context.palette.brand : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  String get _resultLabel {
    if (_all.isEmpty) return 'No outstanding dues found';
    if (!_hasActiveFilters && _filtered.length == _all.length) {
      return '${_all.length} students with dues sorted by $_sortLabel';
    }
    return 'Showing ${_filtered.length} of ${_all.length} students';
  }

  bool get _hasActiveFilters =>
      _searchCtrl.text.trim().isNotEmpty || _classFilter != null;

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() => _classFilter = null);
    _applyFilter();
  }

  Widget _priorityPanel() {
    final priority = List<StudentFeeProfile>.from(_filtered)
      ..sort((a, b) => b.dueFees.compareTo(a.dueFees));
    final top = priority.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
              child: const Icon(Icons.notification_important_outlined,
                  color: AppColors.warning, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collection Queue',
                      style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Highest value follow-ups first',
                      style: GoogleFonts.nunitoSans(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          if (top.isEmpty)
            _miniEmpty()
          else
            ...top.map((student) => _priorityRow(student)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.palette.brand.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              border: Border.all(
                color: context.palette.brand.withValues(alpha: 0.12),
              ),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Today focus',
                style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: context.palette.brand,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _criticalCount > 0
                    ? 'Start with $_criticalCount critical accounts before routine reminders.'
                    : 'No critical accounts in this view. Continue regular reminders.',
                style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _priorityRow(StudentFeeProfile student) {
    final severity = _severity(student);
    final color = _severityColor(severity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 8,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              student.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunitoSans(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
            Text(
              '${student.className} - ${_severityLabel(severity)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Text(
          _currency.format(student.dueFees),
          style: GoogleFonts.nunitoSans(
            color: AppColors.error,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ]),
    );
  }

  Widget _miniEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.canvas,
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: Text(
        'No students in the current filter.',
        style: GoogleFonts.nunitoSans(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _duesList() {
    if (_filtered.isEmpty) return _emptyState();
    return Column(
      children: _filtered
          .map((student) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _dueCard(student),
              ))
          .toList(),
    );
  }

  Widget _dueCard(StudentFeeProfile student) {
    final severity = _severity(student);
    final severityColor = _severityColor(severity);
    final dueRatio = _dueRatio(student);
    final paidRatio = 1 - dueRatio;
    final pendingInstallments = student.feeInstallments
        .where((installment) => installment.status.toUpperCase() != 'PAID')
        .toList();
    final key = _studentKey(student);
    final expanded = _expanded.contains(key);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        onTap: pendingInstallments.isEmpty ? null : () => _toggleExpanded(key),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: severityColor.withValues(alpha: 0.11),
                  child: Text(
                    student.name.isNotEmpty
                        ? student.name.substring(0, 1).toUpperCase()
                        : '?',
                    style: GoogleFonts.nunitoSans(
                      color: severityColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              student.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunitoSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          _severityPill(severity, severityColor),
                        ]),
                        const SizedBox(height: 3),
                        Text(
                          _studentMeta(student),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunitoSans(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    _currency.format(student.dueFees),
                    style: GoogleFonts.nunitoSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.error,
                    ),
                  ),
                  Text(
                    '${(dueRatio * 100).toStringAsFixed(0)}% unpaid',
                    style: GoogleFonts.nunitoSans(
                      color: severityColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ]),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: paidRatio.clamp(0, 1),
                  minHeight: 7,
                  backgroundColor: AppColors.error.withValues(alpha: 0.12),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.success),
                ),
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _amountChip(
                      'Total', student.totalFees, AppColors.textPrimary),
                  _amountChip('Paid', student.paidFees, AppColors.success),
                  _amountChip('Due', student.dueFees, AppColors.error),
                  _plainChip(
                    '${pendingInstallments.length} pending',
                    Icons.fact_check_outlined,
                    AppColors.warning,
                  ),
                  if (student.lastPayment != null)
                    _plainChip(
                      'Last paid ${_dateFmt.format(student.lastPayment!.paymentDate)}',
                      Icons.history_rounded,
                      AppColors.success,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                if (pendingInstallments.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _toggleExpanded(key),
                    icon: Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 17,
                    ),
                    label: Text(expanded ? 'Hide dues' : 'View dues'),
                  ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _openCollection(student),
                  icon: const Icon(Icons.point_of_sale_outlined, size: 17),
                  label: const Text('Collect'),
                ),
              ]),
            ]),
          ),
          if (expanded && pendingInstallments.isNotEmpty)
            _installmentsPanel(pendingInstallments),
        ]),
      ),
    );
  }

  Widget _severityPill(_Severity severity, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _severityLabel(severity).toUpperCase(),
        style: GoogleFonts.nunitoSans(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }

  String _studentMeta(StudentFeeProfile student) {
    return [
      student.className,
      if (student.rollNumber.isNotEmpty) 'Roll ${student.rollNumber}',
      if (student.parentName.isNotEmpty) 'Parent: ${student.parentName}',
    ].where((item) => item.isNotEmpty).join(' - ');
  }

  Widget _amountChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          _currency.format(value),
          style: GoogleFonts.nunitoSans(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunitoSans(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ]),
    );
  }

  Widget _plainChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.nunitoSans(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ]),
    );
  }

  Widget _installmentsPanel(List<FeeInstallment> installments) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: context.palette.canvas,
        border: Border(top: BorderSide(color: context.palette.border)),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppSizes.radiusLG),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Pending Installments',
          style: GoogleFonts.nunitoSans(
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        ...installments.map((installment) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSM),
                  ),
                  child: const Icon(Icons.schedule_rounded,
                      size: 14, color: AppColors.error),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    installment.installmentName,
                    style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  _currency.format(installment.amountDue),
                  style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w900,
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ]),
            )),
      ]),
    );
  }

  void _toggleExpanded(String key) {
    setState(() {
      if (_expanded.contains(key)) {
        _expanded.remove(key);
      } else {
        _expanded.add(key);
      }
    });
  }

  Future<void> _openCollection(StudentFeeProfile student) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeeCollectionScreen(preSelectedStudentId: student.id),
      ),
    );
    _fetch();
  }

  Widget _emptyState() {
    final filtered = _hasActiveFilters;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              filtered ? Icons.search_off_rounded : Icons.verified_rounded,
              size: 54,
              color: filtered
                  ? AppColors.textLight.withValues(alpha: 0.6)
                  : AppColors.success,
            ),
            const SizedBox(height: 12),
            Text(
              filtered ? 'No matching dues' : 'All fees are cleared',
              style: GoogleFonts.nunitoSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              filtered
                  ? 'Try a wider search or clear the selected class.'
                  : 'No pending dues found for any student.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            if (filtered) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                label: const Text('Clear filters'),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded,
              size: 52, color: AppColors.warning),
          const SizedBox(height: 12),
          Text(
            'Could not load outstanding dues',
            style: GoogleFonts.nunitoSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetch,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Retry'),
          ),
        ]),
      ),
    );
  }
}

class _SummaryCard {
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });
}

enum _Severity { critical, high, medium }
