import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';
import 'fee_collection_screen.dart';

enum _DuesSort { highestDue, lowestDue, nameAZ, byClass, highestPct }

class OutstandingDuesScreen extends StatefulWidget {
  const OutstandingDuesScreen({super.key});

  @override
  State<OutstandingDuesScreen> createState() => _OutstandingDuesScreenState();
}

class _OutstandingDuesScreenState extends State<OutstandingDuesScreen> {
  List<StudentFeeProfile> _all = [];
  List<StudentFeeProfile> _filtered = [];
  bool _loading = true;
  String? _error;
  String? _classFilter;
  _DuesSort _sort = _DuesSort.highestDue;
  final _searchCtrl = TextEditingController();
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  // expanded card tracking
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _fetch();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _expanded.clear();
    });
    try {
      final data = await FeeApiService.getOutstandingDues();
      setState(() => _all = data);
      _applyFilter();
    } catch (e) {
      setState(() => _error = 'Failed to load dues: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase().trim();
    var list = _all.where((s) {
      if (q.isNotEmpty &&
          !s.name.toLowerCase().contains(q) &&
          !s.rollNumber.toLowerCase().contains(q) &&
          !s.className.toLowerCase().contains(q) &&
          !s.parentName.toLowerCase().contains(q)) return false;
      if (_classFilter != null && s.className != _classFilter) return false;
      return true;
    }).toList();

    switch (_sort) {
      case _DuesSort.highestDue:
        list.sort((a, b) => b.dueFees.compareTo(a.dueFees));
      case _DuesSort.lowestDue:
        list.sort((a, b) => a.dueFees.compareTo(b.dueFees));
      case _DuesSort.nameAZ:
        list.sort((a, b) => a.name.compareTo(b.name));
      case _DuesSort.byClass:
        list.sort((a, b) => a.className.compareTo(b.className));
      case _DuesSort.highestPct:
        list.sort((a, b) {
          final ra = a.totalFees > 0 ? a.dueFees / a.totalFees : 0.0;
          final rb = b.totalFees > 0 ? b.dueFees / b.totalFees : 0.0;
          return rb.compareTo(ra);
        });
    }
    setState(() => _filtered = list);
  }

  List<String> get _availableClasses {
    final seen = <String>{};
    return _all.map((s) => s.className).where(seen.add).toList()..sort();
  }

  double get _totalDue => _filtered.fold(0.0, (sum, s) => sum + s.dueFees);
  double get _avgDue => _filtered.isEmpty ? 0 : _totalDue / _filtered.length;

  int get _criticalCount => _filtered
      .where((s) => s.totalFees > 0 && s.dueFees / s.totalFees >= 0.75)
      .length;

  // ── Severity helpers ──────────────────────────────────────────────────

  _Severity _severity(StudentFeeProfile s) {
    if (s.totalFees <= 0) return _Severity.medium;
    final ratio = s.dueFees / s.totalFees;
    if (ratio >= 0.75) return _Severity.critical;
    if (ratio >= 0.5) return _Severity.high;
    return _Severity.medium;
  }

  Color _severityColor(_Severity sev) => switch (sev) {
        _Severity.critical => AppColors.error,
        _Severity.high => AppColors.warning,
        _Severity.medium => AppColors.info,
      };

  String _severityLabel(_Severity sev) => switch (sev) {
        _Severity.critical => 'CRITICAL',
        _Severity.high => 'HIGH',
        _Severity.medium => 'MEDIUM',
      };

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text('Outstanding Dues',
            style: GoogleFonts.cormorantGaramond(
                fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetch,
              tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off, size: 64, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text(_error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetch,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white),
          ),
        ]),
      );

  Widget _buildContent() => Column(children: [
        _buildStatCards(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  _buildFilterRow(),
                  const SizedBox(height: 8),
                  _buildResultCount(),
                  const SizedBox(height: 12),
                  if (_filtered.isEmpty)
                    _buildEmptyState()
                  else
                    ...(_filtered.map((s) => _buildDuesCard(s))),
                ]),
          ),
        ),
      ]);

  // ── Stat cards ────────────────────────────────────────────────────────

  Widget _buildStatCards() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: AppColors.navy.withOpacity(0.04),
        child: Row(children: [
          _statCard(
            icon: Icons.people_alt_outlined,
            label: 'Students',
            value: '${_filtered.length}',
            sub: 'with dues',
            color: AppColors.error,
          ),
          const SizedBox(width: 10),
          _statCard(
            icon: Icons.currency_rupee_rounded,
            label: 'Total Due',
            value: _currency.format(_totalDue),
            sub: 'outstanding',
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          _statCard(
            icon: Icons.warning_amber_rounded,
            label: 'Critical',
            value: '$_criticalCount',
            sub: '≥75% unpaid',
            color: AppColors.error,
          ),
          const SizedBox(width: 10),
          _statCard(
            icon: Icons.calculate_outlined,
            label: 'Avg Due',
            value: _currency.format(_avgDue),
            sub: 'per student',
            color: AppColors.info,
          ),
        ]),
      );

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: GoogleFonts.nunitoSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(sub,
                style: GoogleFonts.nunitoSans(
                    fontSize: 10, color: AppColors.textLight)),
          ]),
        ),
      );

  // ── Search bar ────────────────────────────────────────────────────────

  Widget _buildSearchBar() => TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Search by name, class, roll no or parent…',
          hintStyle:
              GoogleFonts.nunitoSans(color: AppColors.textLight, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    _applyFilter();
                  })
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              borderSide: const BorderSide(color: AppColors.navy, width: 2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );

  // ── Filter row ────────────────────────────────────────────────────────

  Widget _buildFilterRow() => Row(children: [
        Expanded(child: _buildClassChips()),
        const SizedBox(width: 8),
        _buildSortButton(),
      ]);

  Widget _buildResultCount() {
    final q = _searchCtrl.text.trim();
    final hasFilter = q.isNotEmpty || _classFilter != null;
    if (_all.isEmpty) return const SizedBox.shrink();
    return Text(
      hasFilter
          ? 'Showing ${_filtered.length} of ${_all.length} students'
          : '${_all.length} students with pending dues',
      style: GoogleFonts.nunitoSans(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600),
    );
  }

  Widget _buildClassChips() {
    final classes = _availableClasses;
    if (classes.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip('All', _classFilter == null,
              () => setState(() {
                    _classFilter = null;
                    _applyFilter();
                  })),
          const SizedBox(width: 6),
          ...classes.map((cls) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _chip(cls, _classFilter == cls,
                    () => setState(() {
                          _classFilter = cls;
                          _applyFilter();
                        })),
              )),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : Colors.white,
            border: Border.all(
                color: selected ? AppColors.navy : AppColors.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : AppColors.textSecondary)),
        ),
      );

  Widget _buildSortButton() {
    final label = switch (_sort) {
      _DuesSort.highestDue => 'Highest Due',
      _DuesSort.lowestDue => 'Lowest Due',
      _DuesSort.nameAZ => 'Name A→Z',
      _DuesSort.byClass => 'By Class',
      _DuesSort.highestPct => 'Most Overdue %',
    };
    return PopupMenuButton<_DuesSort>(
      onSelected: (v) => setState(() {
        _sort = v;
        _applyFilter();
      }),
      itemBuilder: (_) => const [
        PopupMenuItem(
            value: _DuesSort.highestDue, child: Text('Highest Due')),
        PopupMenuItem(
            value: _DuesSort.lowestDue, child: Text('Lowest Due')),
        PopupMenuItem(
            value: _DuesSort.highestPct, child: Text('Most Overdue %')),
        PopupMenuItem(
            value: _DuesSort.nameAZ, child: Text('Name A→Z')),
        PopupMenuItem(
            value: _DuesSort.byClass, child: Text('By Class')),
      ],
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.sort_rounded,
              size: 16, color: AppColors.navy),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const Icon(Icons.arrow_drop_down_rounded,
              size: 18, color: AppColors.navy),
        ]),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final isSearch =
        _searchCtrl.text.isNotEmpty || _classFilter != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(children: [
          Icon(
            isSearch
                ? Icons.search_off_rounded
                : Icons.check_circle_outline,
            size: 64,
            color: isSearch
                ? AppColors.textLight.withOpacity(0.4)
                : AppColors.success.withOpacity(0.6),
          ),
          const SizedBox(height: 14),
          Text(
            isSearch
                ? 'No students match your search'
                : 'All fees are cleared!',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.navy),
          ),
          const SizedBox(height: 6),
          Text(
            isSearch
                ? 'Try a different name, class or roll number.'
                : 'No outstanding dues found for any student.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary, fontSize: 13),
          ),
          if (isSearch) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _classFilter = null);
                _applyFilter();
              },
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear all filters'),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.navy),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Student due card ──────────────────────────────────────────────────

  Widget _buildDuesCard(StudentFeeProfile s) {
    final sev = _severity(s);
    final sevColor = _severityColor(sev);
    final dueRatio = s.totalFees > 0 ? s.dueFees / s.totalFees : 0.0;
    final duePct = (dueRatio * 100).toStringAsFixed(0);
    final isExpanded = _expanded.contains(s.id);
    final pendingInstallments =
        s.feeInstallments.where((i) => i.status != 'PAID').toList();

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        side: BorderSide(color: sevColor.withOpacity(0.3), width: 1.2),
      ),
      child: Column(
        children: [
          // ── Main row ──
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    // Avatar with severity color
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: sevColor.withOpacity(0.12),
                      child: Text(
                        s.name.isNotEmpty
                            ? s.name.substring(0, 1).toUpperCase()
                            : '?',
                        style: GoogleFonts.cormorantGaramond(
                            color: sevColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name, class, roll
                    Expanded(
                      child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                style: GoogleFonts.nunitoSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(
                              [
                                s.className,
                                if (s.rollNumber.isNotEmpty)
                                  'Roll: ${s.rollNumber}',
                                if (s.parentName.isNotEmpty)
                                  s.parentName,
                              ].join(' · '),
                              style: GoogleFonts.nunitoSans(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                            ),
                          ]),
                    ),
                    const SizedBox(width: 8),
                    // Severity + due amount
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: sevColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(_severityLabel(sev),
                                style: GoogleFonts.nunitoSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: sevColor,
                                    letterSpacing: 0.5)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currency.format(s.dueFees),
                            style: GoogleFonts.cormorantGaramond(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                                fontSize: 17),
                          ),
                          Text('$duePct% unpaid',
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 10,
                                  color: sevColor)),
                        ]),
                  ]),
                  const SizedBox(height: 10),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 1.0 - dueRatio,
                      minHeight: 6,
                      backgroundColor: AppColors.error.withOpacity(0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.success),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Amount chips + last payment + actions row
                  Row(children: [
                    _amtChip('Total', s.totalFees,
                        AppColors.textSecondary),
                    const SizedBox(width: 10),
                    _amtChip('Paid', s.paidFees, AppColors.success),
                    const SizedBox(width: 10),
                    _amtChip('Due', s.dueFees, AppColors.error),
                    const Spacer(),
                    // Expand/collapse button
                    if (pendingInstallments.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => isExpanded
                            ? _expanded.remove(s.id)
                            : _expanded.add(s.id)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppColors.border),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${pendingInstallments.length} pending',
                                  style: GoogleFonts.nunitoSans(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ]),
                        ),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        textStyle: GoogleFonts.nunitoSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                      icon: const Icon(Icons.point_of_sale_outlined,
                          size: 16),
                      label: const Text('Collect'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FeeCollectionScreen(
                              preSelectedStudentId: s.id),
                        ),
                      ).then((_) => _fetch()),
                    ),
                  ]),

                  // Last payment info
                  if (s.lastPayment != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                AppColors.success.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline,
                            size: 14, color: AppColors.success),
                        const SizedBox(width: 6),
                        Text(
                          'Last paid: ${_currency.format(s.lastPayment!.amountPaid)}'
                          ' on ${DateFormat('dd MMM yyyy').format(s.lastPayment!.paymentDate)}'
                          ' · Receipt: ${s.lastPayment!.receiptNumber}',
                          style: GoogleFonts.nunitoSans(
                              fontSize: 11,
                              color: AppColors.success),
                        ),
                      ]),
                    ),
                  ],
                ]),
          ),

          // ── Expanded installments ──
          if (isExpanded && pendingInstallments.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: AppColors.creamDark,
                borderRadius: const BorderRadius.only(
                  bottomLeft:
                      Radius.circular(AppSizes.radiusLG),
                  bottomRight:
                      Radius.circular(AppSizes.radiusLG),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.list_alt_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text('Pending Installments',
                          style: GoogleFonts.nunitoSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary)),
                    ]),
                    const SizedBox(height: 8),
                    ...pendingInstallments.map((inst) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            const Icon(
                                Icons.radio_button_unchecked,
                                size: 14,
                                color: AppColors.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(inst.installmentName,
                                  style: GoogleFonts.nunitoSans(
                                      fontSize: 13,
                                      color:
                                          AppColors.textPrimary)),
                            ),
                            Text(
                              _currency.format(inst.amountDue),
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error),
                            ),
                          ]),
                        )),
                  ]),
            ),
        ],
      ),
    );
  }

  Widget _amtChip(String label, double value, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_currency.format(value),
            style: GoogleFonts.nunitoSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: color)),
        Text(label,
            style: GoogleFonts.nunitoSans(
                fontSize: 10, color: AppColors.textLight)),
      ]);
}

enum _Severity { critical, high, medium }
