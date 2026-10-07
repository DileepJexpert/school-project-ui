import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/academic_year.dart';
import '../../../models/admission_data.dart';
import '../../../models/student_model.dart';
import '../../../services/admission_api_service.dart';
import '../../../services/fee_api_service.dart';
import '../../../services/csv_export_service.dart';
import '../../../services/student_api_service.dart';
import '../../../core/widgets/searchable_dropdown.dart';
import 'fee_collection_screen.dart';
import 'new_admission_screen.dart';
import 'student_detail_screen.dart';

enum _SortBy { nameAZ, nameZA, classAsc, rollNoAsc }

enum _CardAction { edit, activate, deactivate, issueTC, markLeft }

/// Returns the next stored class string for [currentClass], or null for Class 12 (graduation).
String? _computeNextClass(String currentClass) {
  if (SchoolConstants.noSectionClasses.contains(currentClass)) {
    final idx = SchoolConstants.baseClasses.indexOf(currentClass);
    if (idx < 0 || idx >= SchoolConstants.baseClasses.length - 1) return null;
    final next = SchoolConstants.baseClasses[idx + 1];
    if (SchoolConstants.noSectionClasses.contains(next)) return next;
    return SchoolConstants.buildClassName(next, SchoolConstants.sections.first);
  }
  final (base, section) = SchoolConstants.parseClassName(currentClass);
  final idx = SchoolConstants.baseClasses.indexOf(base);
  if (idx < 0 || idx >= SchoolConstants.baseClasses.length - 1) return null;
  final nextBase = SchoolConstants.baseClasses[idx + 1];
  if (SchoolConstants.noSectionClasses.contains(nextBase)) return nextBase;
  return SchoolConstants.buildClassName(nextBase, section);
}

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  List<StudentModel> _students = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  // Filter + sort state
  String? _filterClass;          // null = all classes
  String _filterStatus = 'ALL'; // 'ALL' | 'ACTIVE' | 'INACTIVE'
  _SortBy _sortBy = _SortBy.nameAZ;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await StudentApiService.getAllStudents();
      // Exclude enquiries — those belong to the Enquiry Management screen
      setState(() => _students = list.where((s) => s.status.toUpperCase() != 'ENQUIRY').toList());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _loadStudents();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await StudentApiService.searchStudents(query.trim());
      setState(() => _students = list.where((s) => s.status.toUpperCase() != 'ENQUIRY').toList());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Unique base classes present in the loaded list, sorted by curriculum order.
  List<String> get _availableClasses {
    final seen = <String>{};
    final result = <String>[];
    for (final s in _students) {
      if (s.classForAdmission == null) continue;
      final base = SchoolConstants.parseClassName(s.classForAdmission!).$1;
      if (seen.add(base)) result.add(base);
    }
    result.sort((a, b) => SchoolConstants.baseClasses
        .indexOf(a)
        .compareTo(SchoolConstants.baseClasses.indexOf(b)));
    return result;
  }

  /// Student count breakdown per base class.
  Map<String, int> get _classCounts {
    final counts = <String, int>{};
    for (final s in _students) {
      if (s.classForAdmission == null) continue;
      final base = SchoolConstants.parseClassName(s.classForAdmission!).$1;
      counts[base] = (counts[base] ?? 0) + 1;
    }
    return counts;
  }

  /// Client-side filtered + sorted view of [_students].
  List<StudentModel> get _filtered {
    var list = _students.where((s) {
      if (_filterClass != null) {
        final base =
            SchoolConstants.parseClassName(s.classForAdmission ?? '').$1;
        if (base != _filterClass) return false;
      }
      if (_filterStatus != 'ALL' && s.status != _filterStatus) return false;
      if (_searchCtrl.text.trim().isNotEmpty) {
        final q = _searchCtrl.text.trim().toLowerCase();
        final nameMatch = s.fullName.toLowerCase().contains(q);
        final admMatch = (s.admissionNumber ?? '').toLowerCase().contains(q);
        final rollMatch = (s.rollNumber ?? '').toLowerCase().contains(q);
        final classMatch =
            (s.classForAdmission ?? '').toLowerCase().contains(q);
        if (!nameMatch && !admMatch && !rollMatch && !classMatch) return false;
      }
      return true;
    }).toList();

    switch (_sortBy) {
      case _SortBy.nameAZ:
        list.sort((a, b) =>
            a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      case _SortBy.nameZA:
        list.sort((a, b) =>
            b.fullName.toLowerCase().compareTo(a.fullName.toLowerCase()));
      case _SortBy.classAsc:
        list.sort((a, b) {
          final ai =
              SchoolConstants.allClasses.indexOf(a.classForAdmission ?? '');
          final bi =
              SchoolConstants.allClasses.indexOf(b.classForAdmission ?? '');
          return ai.compareTo(bi);
        });
      case _SortBy.rollNoAsc:
        list.sort((a, b) {
          final ar = int.tryParse(a.rollNumber ?? '') ?? 999999;
          final br = int.tryParse(b.rollNumber ?? '') ?? 999999;
          final cmp = ar.compareTo(br);
          return cmp != 0 ? cmp : a.fullName.compareTo(b.fullName);
        });
    }
    return list;
  }

  bool get _hasActiveFilters =>
      _filterClass != null ||
      _filterStatus != 'ALL' ||
      _searchCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 10),
          _buildStatsRow(),
          const SizedBox(height: 10),
          _buildSearchBar(),
          const SizedBox(height: 8),
          _buildClassFilterRow(),
          const SizedBox(height: 6),
          _buildStatusAndSort(),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final total = _students.length;
    final filtered = _loading ? 0 : _filtered.length;
    final subtitle = _loading
        ? 'Loading student directory…'
        : (_hasActiveFilters
            ? '$filtered of $total students match criteria'
            : '$total student(s) actively registered');

    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 780;

      final titleSection = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.navy.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.people_alt_rounded,
                color: AppColors.navy, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Student Directory',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$total Total',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                subtitle,
                style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      );

      final actionButtons = Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_hasActiveFilters)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_list_off_rounded, size: 16),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                textStyle: GoogleFonts.nunitoSans(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ElevatedButton.icon(
            onPressed: () => _openNewAdmission(context),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
            label: const Text('Add Student'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              elevation: 1,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _loading ? null : () => _showPromoteDialog(context),
            icon: const Icon(Icons.school_rounded, size: 16),
            label: const Text('Promote'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gold,
              side: const BorderSide(color: AppColors.gold),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          OutlinedButton.icon(
            onPressed:
                _students.isEmpty ? null : () => _showRollNumberDialog(context),
            icon: const Icon(Icons.format_list_numbered_rounded, size: 16),
            label: const Text('Roll No.'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.info,
              side: const BorderSide(color: AppColors.info),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _filtered.isEmpty
                ? null
                : () => CsvExportService.exportStudents(_filtered),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Export'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              side: const BorderSide(color: AppColors.navy),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          IconButton(
            onPressed: _loadStudents,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            tooltip: 'Refresh list',
            color: AppColors.textSecondary,
          ),
        ],
      );

      if (isNarrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleSection,
            const SizedBox(height: 12),
            actionButtons,
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: titleSection),
          actionButtons,
        ],
      );
    });
  }

  void _clearFilters() => setState(() {
        _searchCtrl.clear();
        _filterClass = null;
        _filterStatus = 'ALL';
      });

  Future<void> _openNewAdmission(BuildContext ctx) async {
    final created = await Navigator.push<bool>(
      ctx,
      MaterialPageRoute(builder: (_) => const NewAdmissionScreen()),
    );
    if (created == true) _loadStudents();
  }

  void _collectFee(BuildContext ctx, StudentModel s) {
    if (s.id == null) return;
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => FeeCollectionScreen(preSelectedStudentId: s.id),
      ),
    );
  }

  /// 4 Interactive KPI cards: Total / Active / Inactive / Classes
  Widget _buildStatsRow() {
    if (_loading || _students.isEmpty) return const SizedBox.shrink();
    final total = _students.length;
    final active = _students.where((s) => s.status == 'ACTIVE').length;
    final inactive = total - active;
    final classesCount = _availableClasses.length;

    return LayoutBuilder(builder: (ctx, constraints) {
      final isWide = constraints.maxWidth > 720;
      final cards = [
        _statCard(
          'Total Enrolled',
          total,
          AppColors.navy,
          Icons.people_rounded,
          _filterStatus == 'ALL' && _filterClass == null,
          () => setState(() {
            _filterStatus = 'ALL';
            _filterClass = null;
          }),
        ),
        _statCard(
          'Active Students',
          active,
          AppColors.success,
          Icons.check_circle_outline_rounded,
          _filterStatus == 'ACTIVE',
          () => setState(() =>
              _filterStatus = _filterStatus == 'ACTIVE' ? 'ALL' : 'ACTIVE'),
        ),
        _statCard(
          'Inactive / Left',
          inactive,
          AppColors.error,
          Icons.highlight_off_rounded,
          _filterStatus == 'INACTIVE',
          () => setState(() =>
              _filterStatus = _filterStatus == 'INACTIVE' ? 'ALL' : 'INACTIVE'),
        ),
        _statCard(
          'Classes Covered',
          classesCount,
          AppColors.info,
          Icons.domain_rounded,
          _filterClass != null,
          () => setState(() => _filterClass = null),
        ),
      ];

      if (isWide) {
        return Row(
          children: cards
              .map((c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: c,
                    ),
                  ))
              .toList(),
        );
      }
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: cards,
      );
    });
  }

  Widget _statCard(
    String label,
    int count,
    Color color,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : Colors.white,
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: isSelected ? 6 : 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$count',
                      style: GoogleFonts.cormorantGaramond(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: color,
                          height: 1.1)),
                  Text(label,
                      style: GoogleFonts.nunitoSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? color
                              : AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        style: GoogleFonts.nunitoSans(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search by student name, roll number, admission number, or class…',
          hintStyle: GoogleFonts.nunitoSans(color: AppColors.textLight, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: AppColors.navy, size: 19),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                    _loadStudents();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
        ),
        onChanged: (v) {
          setState(() {});
          if (v.length > 2 || v.isEmpty) _search(v);
        },
      ),
    );
  }

  /// Horizontally scrollable class filter carousel with student counts.
  Widget _buildClassFilterRow() {
    final classes = _availableClasses;
    if (classes.isEmpty) return const SizedBox.shrink();
    final counts = _classCounts;

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _classChip(
            'All Classes',
            _students.length,
            _filterClass == null,
            () => setState(() => _filterClass = null),
          ),
          const SizedBox(width: 8),
          ...classes.map((cls) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _classChip(
                  cls,
                  counts[cls] ?? 0,
                  _filterClass == cls,
                  () => setState(() =>
                      _filterClass = _filterClass == cls ? null : cls),
                ),
              )),
        ],
      ),
    );
  }

  Widget _classChip(String label, int count, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.white,
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              size: 14,
              color: selected ? Colors.white : AppColors.navy,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.nunitoSans(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.creamDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.nunitoSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Scrollable status filter chips + sort dropdown.
  Widget _buildStatusAndSort() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _statusChip('ALL', 'All Statuses', AppColors.navy),
                const SizedBox(width: 6),
                _statusChip('ACTIVE', 'Active', AppColors.success),
                const SizedBox(width: 6),
                _statusChip('INACTIVE', 'Inactive', AppColors.error),
                const SizedBox(width: 6),
                _statusChip('TC_ISSUED', 'TC Issued', AppColors.warning),
                const SizedBox(width: 6),
                _statusChip('LEFT', 'Left', AppColors.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildSortButton(),
      ],
    );
  }

  Widget _statusChip(String value, String label, Color color) {
    final selected = _filterStatus == value;
    return InkWell(
      onTap: () => setState(() => _filterStatus = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          border: Border.all(color: selected ? color : AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.nunitoSans(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? color : AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildSortButton() {
    final label = switch (_sortBy) {
      _SortBy.nameAZ => 'Name: A→Z',
      _SortBy.nameZA => 'Name: Z→A',
      _SortBy.classAsc => 'By Class',
      _SortBy.rollNoAsc => 'By Roll No.',
    };
    return PopupMenuButton<_SortBy>(
      onSelected: (v) => setState(() => _sortBy = v),
      itemBuilder: (_) => const [
        PopupMenuItem(value: _SortBy.nameAZ, child: Text('Name: A→Z')),
        PopupMenuItem(value: _SortBy.nameZA, child: Text('Name: Z→A')),
        PopupMenuItem(value: _SortBy.classAsc, child: Text('By Class')),
        PopupMenuItem(value: _SortBy.rollNoAsc, child: Text('By Roll No.')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 16, color: AppColors.navy),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy)),
            const Icon(Icons.arrow_drop_down_rounded,
                size: 18, color: AppColors.navy),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildShimmer();
    if (_error != null) return _buildError();
    if (_students.isEmpty) return _buildEmpty();
    final students = _filtered;
    if (students.isEmpty) return _buildNoMatch();
    return _buildList(students);
  }

  Widget _buildList(List<StudentModel> students) {
    return ListView.separated(
      itemCount: students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _StudentCard(
        student: students[i],
        onTap: () => _showDetail(ctx, students[i]),
        onCollectFee: () => _collectFee(ctx, students[i]),
        onEdit: () => _editStudent(ctx, students[i]),
        onSetStatus: (status) => _setStatus(students[i], status),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radiusLG),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 52),
          const SizedBox(height: 12),
          Text('Could not load students',
              style: GoogleFonts.nunitoSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error)),
          const SizedBox(height: 6),
          Text(_error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _loadStudents, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline,
              size: 60, color: AppColors.textLight.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Text('No students found',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 6),
          Text('Add students via the admissions flow.',
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildNoMatch() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off_rounded,
              size: 52, color: AppColors.textLight.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Text('No students match filters',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _clearFilters,
            child: Text('Clear filters',
                style: GoogleFonts.nunitoSans(color: AppColors.navy)),
          ),
        ],
      ),
    );
  }

  Future<void> _editStudent(BuildContext ctx, StudentModel s) async {
    if (s.id == null) return;
    final saved = await Navigator.push<bool>(
      ctx,
      MaterialPageRoute(
          builder: (_) => NewAdmissionScreen(studentId: s.id!)),
    );
    if (saved == true) _loadStudents();
  }

  Future<void> _setStatus(StudentModel s, String newStatus) async {
    if (s.id == null) return;
    const labels = {
      'ACTIVE': 'reactivated',
      'INACTIVE': 'deactivated',
      'TC_ISSUED': 'marked TC Issued',
      'LEFT': 'marked as Left',
    };
    const colors = {
      'ACTIVE': AppColors.success,
      'TC_ISSUED': AppColors.warning,
    };
    try {
      await AdmissionApiService.toggleStatus(s.id!, newStatus);
      _loadStudents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${s.fullName} ${labels[newStatus] ?? newStatus}'),
          backgroundColor: colors[newStatus] ?? AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _showPromoteDialog(BuildContext ctx) async {
    // Search and class filters change _students. Preview the full server cohort.
    late final List<Student> allStudents;
    try {
      allStudents = await AdmissionApiService.getStudents();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not load the full student cohort: $error'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }
    if (!ctx.mounted) return;
    final classes = allStudents
        .where((s) =>
            s.status.toUpperCase() == 'ACTIVE' &&
            SchoolConstants.baseClasses.contains(
                SchoolConstants.parseClassName(s.classForAdmission).$1))
        .map((s) => s.classForAdmission)
        .toSet()
        .toList()
      ..sort();
    String? selectedClass;
    String? sourceYear;
    bool promoting = false;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (_, dialogSetState) {
          final nextCls =
              selectedClass != null ? _computeNextClass(selectedClass!) : null;
          final isGraduation = selectedClass != null && nextCls == null;
          final years = allStudents
              .where((s) =>
                  s.classForAdmission == selectedClass &&
                  s.status.toUpperCase() == 'ACTIVE' &&
                  AcademicYear.next(s.academicYear) != null)
              .map((s) => s.academicYear)
              .toSet()
              .toList()
            ..sort();
          final targetYear = sourceYear == null ? null : AcademicYear.next(sourceYear!);
          final affectedCount = selectedClass == null || sourceYear == null
              ? 0
              : AdmissionApiService.promotionCandidates(
                      allStudents, selectedClass!, sourceYear!)
                  .length;

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
            title: Row(children: [
              const Icon(Icons.school_rounded, color: AppColors.gold, size: 22),
              const SizedBox(width: 10),
              Text('Promote Students',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
            ]),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text('Move an entire class to the next grade.',
                      style: GoogleFonts.nunitoSans(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 20),

                  // From class dropdown
                  Text('Source Class',
                      style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedClass,
                    hint: Text('Select class…',
                        style: GoogleFonts.nunitoSans(
                            color: AppColors.textLight)),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    items: classes
                        .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c,
                                style: GoogleFonts.nunitoSans())))
                        .toList(),
                    onChanged: promoting
                        ? null
                        : (v) => dialogSetState(() {
                            selectedClass = v;
                            sourceYear = null;
                          }),
                  ),

                  if (selectedClass != null) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: sourceYear,
                      decoration: const InputDecoration(labelText: 'Source Academic Year'),
                      items: years
                          .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                          .toList(),
                      onChanged: promoting
                          ? null
                          : (v) => dialogSetState(() => sourceYear = v),
                    ),
                  ],

                  // Arrow → next class
                  if (selectedClass != null) ...[
                    const SizedBox(height: 16),
                    Row(children: [
                      const Icon(Icons.arrow_downward_rounded,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        isGraduation
                            ? 'Graduate — status set to Inactive'
                            : 'Promotes to: $nextCls',
                        style: GoogleFonts.nunitoSans(
                            fontWeight: FontWeight.w600,
                            color: isGraduation
                                ? AppColors.error
                                : AppColors.success,
                            fontSize: 13),
                      ),
                    ]),
                  ],

                  if (sourceYear != null && !isGraduation) ...[
                    const SizedBox(height: 16),
                    Text('New Academic Year: $targetYear',
                        style: GoogleFonts.nunitoSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],

                  // Info banner
                  if (sourceYear != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: affectedCount == 0
                            ? AppColors.error.withValues(alpha: 0.07)
                            : AppColors.gold.withValues(alpha: 0.08),
                        border: Border.all(
                            color: affectedCount == 0
                                ? AppColors.error.withValues(alpha: 0.3)
                                : AppColors.gold.withValues(alpha: 0.4)),
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMD),
                      ),
                      child: Row(children: [
                        Icon(
                          affectedCount == 0
                              ? Icons.info_outline_rounded
                              : Icons.people_rounded,
                          size: 18,
                          color: affectedCount == 0
                              ? AppColors.error
                              : AppColors.gold,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            affectedCount == 0
                                ? 'No active students in $selectedClass ($sourceYear).'
                                : '$affectedCount active student(s) in $selectedClass ($sourceYear) will be '
                                    '${isGraduation ? "graduated" : "promoted to $nextCls"}.',
                            style: GoogleFonts.nunitoSans(
                                fontSize: 13,
                                color: affectedCount == 0
                                    ? AppColors.error
                                    : AppColors.navy),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),
            actions: [
              TextButton(
                onPressed:
                    promoting ? null : () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: GoogleFonts.nunitoSans(
                        color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: selectedClass == null || sourceYear == null ||
                        affectedCount == 0 ||
                        promoting
                    ? null
                    : () async {
                        dialogSetState(() => promoting = true);
                        try {
                          if (!isGraduation) {
                            final structures = await FeeApiService.getFeeStructures(
                                year: targetYear!);
                            if (!structures.any((s) =>
                                s.className == nextCls &&
                                s.academicYear == targetYear &&
                                s.components.isNotEmpty)) {
                              throw StateError('Create a fee structure for $nextCls '
                                  'in $targetYear before promoting this class.');
                            }
                          }
                          final count =
                              await AdmissionApiService.promoteClass(
                                  selectedClass!, sourceYear!, nextCls, targetYear!);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadStudents();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isGraduation
                                    ? '$count student(s) graduated successfully.'
                                    : '$count student(s) promoted to $nextCls.'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadStudents();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Promotion failed: $e'),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white),
                child: promoting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        affectedCount > 0
                            ? 'Promote $affectedCount'
                            : 'Promote',
                        style: GoogleFonts.nunitoSans(
                            fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRollNumberDialog(BuildContext ctx) {
    // All closure-scoped state — survives StatefulBuilder rebuilds
    String? selectedClass;
    bool saving = false;
    final Map<String, TextEditingController> controllers = {};

    // Classes that have at least one ACTIVE student, sorted by curriculum order
    final classesWithActive = _students
        .where((s) => s.status == 'ACTIVE' && s.classForAdmission != null)
        .map((s) => s.classForAdmission!)
        .toSet()
        .toList()
      ..sort((a, b) {
        final (baseA, secA) = SchoolConstants.parseClassName(a);
        final (baseB, secB) = SchoolConstants.parseClassName(b);
        final iA = SchoolConstants.baseClasses.indexOf(baseA);
        final iB = SchoolConstants.baseClasses.indexOf(baseB);
        return iA != iB ? iA.compareTo(iB) : secA.compareTo(secB);
      });

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (dialogCtx, setSt) {
          final classStudents = selectedClass == null
              ? <StudentModel>[]
              : (_students
                    .where((s) =>
                        s.status == 'ACTIVE' &&
                        s.classForAdmission == selectedClass)
                    .toList()
                  ..sort((a, b) => a.fullName.compareTo(b.fullName)));

          // Initialise controllers for newly visible students
          for (final s in classStudents) {
            if (s.id != null && !controllers.containsKey(s.id)) {
              controllers[s.id!] =
                  TextEditingController(text: s.rollNumber ?? '');
            }
          }
          // Dispose + remove controllers for students no longer visible
          final currentIds = classStudents.map((s) => s.id).toSet();
          for (final key in controllers.keys
              .where((k) => !currentIds.contains(k))
              .toList()) {
            controllers.remove(key)?.dispose();
          }

          return AlertDialog(
            title: Text(
              'Assign Roll Numbers',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy),
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchableDropdownFormField<String>(
                    labelText: 'Select Class',
                    initialValue: selectedClass,
                    items: classesWithActive,
                    onChanged: (v) => setSt(() => selectedClass = v),
                  ),
                  if (selectedClass != null) ...[
                    const SizedBox(height: 12),
                    if (classStudents.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No active students in this class.',
                          style: GoogleFonts.nunitoSans(
                              color: AppColors.textSecondary),
                        ),
                      )
                    else ...[
                      Text(
                        '${classStudents.length} active student(s)',
                        style: GoogleFonts.nunitoSans(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: classStudents.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final s = classStudents[i];
                            return Row(children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  s.fullName,
                                  style: GoogleFonts.nunitoSans(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: controllers[s.id!],
                                  decoration: InputDecoration(
                                    labelText: 'Roll No.',
                                    isDense: true,
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ),
                            ]);
                          },
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () {
                        for (final c in controllers.values) {
                          c.dispose();
                        }
                        controllers.clear();
                        Navigator.pop(dialogCtx);
                      },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white),
                onPressed:
                    saving || selectedClass == null || classStudents.isEmpty
                        ? null
                        : () async {
                            setSt(() => saving = true);
                            try {
                              final assignments = <String, String>{};
                              for (final s in classStudents) {
                                if (s.id != null) {
                                  assignments[s.id!] =
                                      controllers[s.id!]?.text ?? '';
                                }
                              }
                              final count = await AdmissionApiService
                                  .assignRollNumbers(assignments);
                              for (final c in controllers.values) {
                                c.dispose();
                              }
                              controllers.clear();
                              if (dialogCtx.mounted) {
                                Navigator.pop(dialogCtx);
                              }
                              _showSnack('$count roll number(s) saved.');
                              _loadStudents();
                            } catch (e) {
                              setSt(() => saving = false);
                              _showSnack('Error: $e', isError: true);
                            }
                          },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Roll Numbers'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDetail(BuildContext ctx, StudentModel s) async {
    if (s.id == null) return;
    final updated = await Navigator.push<bool>(
      ctx,
      MaterialPageRoute(
        builder: (_) => StudentDetailScreen(studentId: s.id!),
      ),
    );
    if (updated == true) _loadStudents();
  }
}

class _StudentCard extends StatelessWidget {
  final StudentModel student;
  final VoidCallback onTap;
  final VoidCallback onCollectFee;
  final VoidCallback onEdit;
  final void Function(String status) onSetStatus;

  const _StudentCard({
    required this.student,
    required this.onTap,
    required this.onCollectFee,
    required this.onEdit,
    required this.onSetStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        side: const BorderSide(color: AppColors.border, width: 0.8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                    child: Text(
                      student.fullName.isNotEmpty
                          ? student.fullName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.cormorantGaramond(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.fullName,
                          style: GoogleFonts.nunitoSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (student.classForAdmission != null &&
                                student.classForAdmission!.isNotEmpty)
                              _chip(student.classForAdmission!, AppColors.navy),
                            if (student.rollNumber != null &&
                                student.rollNumber!.trim().isNotEmpty)
                              _chip('Roll #${student.rollNumber}',
                                  const Color(0xFF6366F1)),
                            if (student.admissionNumber != null &&
                                student.admissionNumber!.trim().isNotEmpty)
                              _chip('Adm: ${student.admissionNumber}',
                                  AppColors.gold),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusBadge(student.status),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 0.6, color: AppColors.border),
              const SizedBox(height: 8),
              Row(
                children: [
                  InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility_outlined,
                              size: 14, color: AppColors.navy),
                          const SizedBox(width: 5),
                          Text('Profile',
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onCollectFee,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long_rounded,
                              size: 14, color: AppColors.success),
                          const SizedBox(width: 5),
                          Text('Collect Fee',
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 17, color: AppColors.textSecondary),
                    tooltip: 'Edit Student',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: 2),
                  _buildMenu(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenu() {
    final isActive = student.status == 'ACTIVE';
    return PopupMenuButton<_CardAction>(
      onSelected: (action) {
        switch (action) {
          case _CardAction.edit:
            onEdit();
          case _CardAction.activate:
            onSetStatus('ACTIVE');
          case _CardAction.deactivate:
            onSetStatus('INACTIVE');
          case _CardAction.issueTC:
            onSetStatus('TC_ISSUED');
          case _CardAction.markLeft:
            onSetStatus('LEFT');
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _CardAction.edit,
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 18),
            SizedBox(width: 10),
            Text('Edit'),
          ]),
        ),
        if (isActive) ...[
          PopupMenuItem(
            value: _CardAction.issueTC,
            child: Row(children: [
              Icon(Icons.description_outlined,
                  size: 18, color: AppColors.warning),
              SizedBox(width: 10),
              Text('Issue TC',
                  style: const TextStyle(color: AppColors.warning)),
            ]),
          ),
          PopupMenuItem(
            value: _CardAction.markLeft,
            child: Row(children: [
              Icon(Icons.exit_to_app_rounded,
                  size: 18, color: AppColors.textSecondary),
              SizedBox(width: 10),
              const Text('Mark as Left'),
            ]),
          ),
          PopupMenuItem(
            value: _CardAction.deactivate,
            child: Row(children: [
              Icon(Icons.block_rounded, size: 18, color: AppColors.error),
              SizedBox(width: 10),
              Text('Deactivate',
                  style: const TextStyle(color: AppColors.error)),
            ]),
          ),
        ] else
          PopupMenuItem(
            value: _CardAction.activate,
            child: Row(children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 18, color: AppColors.success),
              SizedBox(width: 10),
              Text('Re-enroll',
                  style: const TextStyle(color: AppColors.success)),
            ]),
          ),
      ],
      icon: const Icon(Icons.more_vert_rounded,
          size: 18, color: AppColors.textSecondary),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      splashRadius: 18,
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: GoogleFonts.nunitoSans(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  static Color _badgeColor(String status) => switch (status) {
        'ACTIVE' => AppColors.success,
        'TC_ISSUED' => AppColors.warning,
        'LEFT' => AppColors.textSecondary,
        _ => AppColors.error,
      };

  static String _badgeLabel(String status) => switch (status) {
        'TC_ISSUED' => 'TC Issued',
        'LEFT' => 'Left',
        'ACTIVE' => 'Active',
        _ => 'Inactive',
      };

  Widget _statusBadge(String status) {
    final color = _badgeColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(_badgeLabel(status),
          style: GoogleFonts.nunitoSans(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
