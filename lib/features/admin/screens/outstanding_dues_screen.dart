import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';
import 'fee_collection_screen.dart';

enum _DuesSort { highestDue, nameAZ, byClass }

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
    setState(() { _loading = true; _error = null; });
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
    final q = _searchCtrl.text.toLowerCase();
    var list = _all.where((s) {
      if (q.isNotEmpty &&
          !s.name.toLowerCase().contains(q) &&
          !(s.rollNumber ?? '').toLowerCase().contains(q) &&
          !s.className.toLowerCase().contains(q)) return false;
      if (_classFilter != null && s.className != _classFilter) return false;
      return true;
    }).toList();

    switch (_sort) {
      case _DuesSort.highestDue:
        list.sort((a, b) => b.dueFees.compareTo(a.dueFees));
      case _DuesSort.nameAZ:
        list.sort((a, b) => a.name.compareTo(b.name));
      case _DuesSort.byClass:
        list.sort((a, b) => a.className.compareTo(b.className));
    }
    setState(() => _filtered = list);
  }

  List<String> get _availableClasses {
    final seen = <String>{};
    return _all.map((s) => s.className).where(seen.add).toList()..sort();
  }

  double get _totalDue => _filtered.fold(0.0, (sum, s) => sum + s.dueFees);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text('Outstanding Dues',
            style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch, tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cloud_off, size: 64, color: AppColors.textLight),
        const SizedBox(height: 16),
        Text(_error!, style: GoogleFonts.nunitoSans(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _fetch, icon: const Icon(Icons.refresh), label: const Text('Retry')),
      ]),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Summary banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: AppColors.error.withOpacity(0.08),
          child: Row(children: [
            const Icon(Icons.pending_actions_outlined, color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_filtered.length} student${_filtered.length == 1 ? '' : 's'} with dues',
                style: GoogleFonts.nunitoSans(color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              'Total: ${_currency.format(_totalDue)}',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.error),
            ),
          ]),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Search
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by name, class or roll no…',
                  hintStyle: GoogleFonts.nunitoSans(color: AppColors.textLight),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () { _searchCtrl.clear(); _applyFilter(); })
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                      borderSide: const BorderSide(color: AppColors.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),

              // Class filter + sort row
              Row(children: [
                Expanded(child: _buildClassChips()),
                const SizedBox(width: 8),
                _buildSortButton(),
              ]),
              const SizedBox(height: 16),

              // Student cards
              if (_filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(children: [
                      const Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
                      const SizedBox(height: 12),
                      Text(
                        _all.isEmpty
                            ? 'No outstanding dues.\nAll fees are cleared!'
                            : 'No results match your filters.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunitoSans(color: AppColors.textSecondary),
                      ),
                    ]),
                  ),
                )
              else
                ...(_filtered.map((s) => _buildDuesCard(s))),
            ]),
          ),
        ),
      ],
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
          _chip('All', _classFilter == null, () => setState(() { _classFilter = null; _applyFilter(); })),
          const SizedBox(width: 6),
          ...classes.map((cls) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _chip(cls, _classFilter == cls,
                    () => setState(() { _classFilter = cls; _applyFilter(); })),
              )),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.white,
          border: Border.all(color: selected ? AppColors.navy : AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.nunitoSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildSortButton() {
    final label = switch (_sort) {
      _DuesSort.highestDue => 'Highest Due',
      _DuesSort.nameAZ => 'Name A→Z',
      _DuesSort.byClass => 'By Class',
    };
    return PopupMenuButton<_DuesSort>(
      onSelected: (v) => setState(() { _sort = v; _applyFilter(); }),
      itemBuilder: (_) => const [
        PopupMenuItem(value: _DuesSort.highestDue, child: Text('Highest Due')),
        PopupMenuItem(value: _DuesSort.nameAZ, child: Text('Name A→Z')),
        PopupMenuItem(value: _DuesSort.byClass, child: Text('By Class')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.sort_rounded, size: 16, color: AppColors.navy),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy)),
          const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.navy),
        ]),
      ),
    );
  }

  Widget _buildDuesCard(StudentFeeProfile s) {
    final dueRatio = s.totalFees > 0 ? s.dueFees / s.totalFees : 0.0;
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.error.withOpacity(0.1),
              child: Text(
                s.name.isNotEmpty ? s.name.substring(0, 1).toUpperCase() : '?',
                style: GoogleFonts.cormorantGaramond(
                    color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            // Name + class
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name,
                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(
                  '${s.className}${s.rollNumber != null ? ' · Roll: ${s.rollNumber}' : ''}'
                  '${s.parentName.isNotEmpty ? ' · ${s.parentName}' : ''}',
                  style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12),
                ),
              ]),
            ),
            // Due amount badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Text(
                _currency.format(s.dueFees),
                style: GoogleFonts.cormorantGaramond(
                    color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 1.0 - dueRatio,
              minHeight: 6,
              backgroundColor: AppColors.error.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
          const SizedBox(height: 8),

          // Total / Paid / Due row
          Row(children: [
            _amtChip('Total', s.totalFees, AppColors.textSecondary),
            const SizedBox(width: 8),
            _amtChip('Paid', s.paidFees, AppColors.success),
            const SizedBox(width: 8),
            _amtChip('Due', s.dueFees, AppColors.error),
            const Spacer(),
            // Collect Fee button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.point_of_sale_outlined, size: 16),
              label: const Text('Collect'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FeeCollectionScreen(preSelectedStudentId: s.id),
                ),
              ).then((_) => _fetch()),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _amtChip(String label, double value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_currency.format(value),
          style: GoogleFonts.nunitoSans(
              fontWeight: FontWeight.w700, fontSize: 13, color: color)),
      Text(label,
          style: GoogleFonts.nunitoSans(fontSize: 10, color: AppColors.textLight)),
    ]);
  }
}
