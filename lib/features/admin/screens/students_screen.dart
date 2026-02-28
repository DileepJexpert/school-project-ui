import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/student_model.dart';
import '../../../services/admission_api_service.dart';
import '../../../services/student_api_service.dart';
import 'new_admission_screen.dart';
import 'student_detail_screen.dart';

enum _SortBy { nameAZ, nameZA, classAsc }

enum _CardAction { edit, toggleStatus }

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
      setState(() => _students = list);
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
      setState(() => _students = list);
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

  /// Client-side filtered + sorted view of [_students].
  List<StudentModel> get _filtered {
    var list = _students.where((s) {
      if (_filterClass != null) {
        final base = SchoolConstants.parseClassName(s.classForAdmission ?? '').$1;
        if (base != _filterClass) return false;
      }
      if (_filterStatus != 'ALL' && s.status != _filterStatus) return false;
      return true;
    }).toList();

    switch (_sortBy) {
      case _SortBy.nameAZ:
        list.sort((a, b) => a.fullName.compareTo(b.fullName));
      case _SortBy.nameZA:
        list.sort((a, b) => b.fullName.compareTo(a.fullName));
      case _SortBy.classAsc:
        list.sort((a, b) {
          final ai =
              SchoolConstants.allClasses.indexOf(a.classForAdmission ?? '');
          final bi =
              SchoolConstants.allClasses.indexOf(b.classForAdmission ?? '');
          return ai.compareTo(bi);
        });
    }
    return list;
  }

  bool get _hasActiveFilters =>
      _filterClass != null || _filterStatus != 'ALL';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildClassFilterRow(),
          const SizedBox(height: 8),
          _buildStatusAndSort(),
          const SizedBox(height: 12),
          _buildStatsRow(),
          const SizedBox(height: 12),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final total = _students.length;
    final filtered = _loading ? 0 : _filtered.length;
    final subtitle = _loading
        ? 'Loading…'
        : (_hasActiveFilters
            ? '$filtered of $total students'
            : '$total student(s) found');
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Students',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              Text(subtitle,
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
        if (_hasActiveFilters)
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.filter_list_off_rounded, size: 16),
            label: const Text('Clear'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
          ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _loadStudents,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy, foregroundColor: Colors.white),
        ),
      ],
    );
  }

  void _clearFilters() => setState(() {
        _filterClass = null;
        _filterStatus = 'ALL';
      });

  /// Three stat cards: Total / Active / Inactive — always reflects the full loaded list.
  Widget _buildStatsRow() {
    if (_loading || _students.isEmpty) return const SizedBox.shrink();
    final total = _students.length;
    final active = _students.where((s) => s.status == 'ACTIVE').length;
    final inactive = total - active;
    return Row(
      children: [
        _statCard('Total', total, AppColors.navy, Icons.people_rounded),
        const SizedBox(width: 10),
        _statCard('Active', active, AppColors.success, Icons.check_circle_outline_rounded),
        const SizedBox(width: 10),
        _statCard('Inactive', inactive, AppColors.error, Icons.highlight_off_rounded),
      ],
    );
  }

  Widget _statCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          border: Border.all(color: color.withOpacity(0.22)),
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: color,
                        height: 1.1)),
                Text(label,
                    style: GoogleFonts.nunitoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color.withOpacity(0.75))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Search student by name…',
        hintStyle: GoogleFonts.nunitoSans(color: AppColors.textLight),
        prefixIcon: const Icon(Icons.search, color: AppColors.navy),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          borderSide: const BorderSide(color: AppColors.navy, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      onChanged: (v) {
        setState(() {});
        if (v.length > 2 || v.isEmpty) _search(v);
      },
    );
  }

  /// Horizontally scrollable class filter chips — only classes with students.
  Widget _buildClassFilterRow() {
    final classes = _availableClasses;
    if (classes.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _classChip('All', _filterClass == null,
              () => setState(() => _filterClass = null)),
          const SizedBox(width: 6),
          ...classes.map((cls) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _classChip(
                    cls, _filterClass == cls, () => setState(() => _filterClass = cls)),
              )),
        ],
      ),
    );
  }

  Widget _classChip(String label, bool selected, VoidCallback onTap) {
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

  /// Status filter chips (All / Active / Inactive) + sort dropdown.
  Widget _buildStatusAndSort() {
    return Row(
      children: [
        _statusChip('ALL', 'All', AppColors.navy),
        const SizedBox(width: 6),
        _statusChip('ACTIVE', 'Active', AppColors.success),
        const SizedBox(width: 6),
        _statusChip('INACTIVE', 'Inactive', AppColors.error),
        const Spacer(),
        _buildSortButton(),
      ],
    );
  }

  Widget _statusChip(String value, String label, Color color) {
    final selected = _filterStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.transparent,
          border: Border.all(color: selected ? color : AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.nunitoSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? color : AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildSortButton() {
    final label = switch (_sortBy) {
      _SortBy.nameAZ => 'Name A→Z',
      _SortBy.nameZA => 'Name Z→A',
      _SortBy.classAsc => 'By Class',
    };
    return PopupMenuButton<_SortBy>(
      onSelected: (v) => setState(() => _sortBy = v),
      itemBuilder: (_) => const [
        PopupMenuItem(value: _SortBy.nameAZ, child: Text('Name A→Z')),
        PopupMenuItem(value: _SortBy.nameZA, child: Text('Name Z→A')),
        PopupMenuItem(value: _SortBy.classAsc, child: Text('By Class')),
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
            const SizedBox(width: 4),
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
        onEdit: () => _editStudent(ctx, students[i]),
        onToggleStatus: () => _toggleStatus(students[i]),
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
              size: 60, color: AppColors.textLight.withOpacity(0.5)),
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
              size: 52, color: AppColors.textLight.withOpacity(0.5)),
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

  Future<void> _toggleStatus(StudentModel s) async {
    if (s.id == null) return;
    final newStatus = s.status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    final label = newStatus == 'ACTIVE' ? 'activated' : 'deactivated';
    try {
      await AdmissionApiService.toggleStatus(s.id!, newStatus);
      _loadStudents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${s.fullName} $label'),
          backgroundColor:
              newStatus == 'ACTIVE' ? AppColors.success : AppColors.error,
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
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const _StudentCard({
    required this.student,
    required this.onTap,
    required this.onEdit,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.navy.withOpacity(0.1),
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.fullName,
                      style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, children: [
                    if (student.classForAdmission != null)
                      _chip(student.classForAdmission!, AppColors.navy),
                    if (student.admissionNumber != null)
                      _chip(student.admissionNumber!, AppColors.gold),
                  ]),
                ],
              ),
            ),
            _statusBadge(student.status),
            const SizedBox(width: 4),
            _buildMenu(),
          ]),
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
          case _CardAction.toggleStatus:
            onToggleStatus();
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
        PopupMenuItem(
          value: _CardAction.toggleStatus,
          child: Row(children: [
            Icon(
              isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
              size: 18,
              color: isActive ? AppColors.error : AppColors.success,
            ),
            const SizedBox(width: 10),
            Text(
              isActive ? 'Deactivate' : 'Activate',
              style: TextStyle(
                  color: isActive ? AppColors.error : AppColors.success),
            ),
          ]),
        ),
      ],
      icon: const Icon(Icons.more_vert_rounded,
          size: 20, color: AppColors.textSecondary),
      padding: EdgeInsets.zero,
      splashRadius: 18,
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: GoogleFonts.nunitoSans(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _statusBadge(String status) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: status == 'ACTIVE'
              ? AppColors.success.withOpacity(0.1)
              : AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(status,
            style: GoogleFonts.nunitoSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: status == 'ACTIVE' ? AppColors.success : AppColors.error)),
      );
}
