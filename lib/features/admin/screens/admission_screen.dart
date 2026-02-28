import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/admission_data.dart';
import '../../../services/admission_api_service.dart';
import '../../../services/csv_export_service.dart';
import 'new_admission_screen.dart';
import 'student_detail_screen.dart';

enum _SortBy { dateDesc, dateAsc, nameAZ, nameZA, classAsc }

class AdmissionScreen extends StatefulWidget {
  const AdmissionScreen({super.key});

  @override
  State<AdmissionScreen> createState() => _AdmissionScreenState();
}

class _AdmissionScreenState extends State<AdmissionScreen> {
  List<Student> _all = [];
  List<Student> _filtered = [];
  bool _isLoading = true;
  String _error = '';
  final _searchCtrl = TextEditingController();
  final _fmt = DateFormat('dd MMM yyyy');

  // Filter + sort state
  String? _filterClass;
  String _filterStatus = 'ALL';
  _SortBy _sortBy = _SortBy.dateDesc;

  @override
  void initState() {
    super.initState();
    _fetch();
    _searchCtrl.addListener(_filter);
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final students = await AdmissionApiService.getStudents();
      setState(() {
        _all = students;
        _filter();
      });
    } catch (e) {
      setState(() => _error = 'Failed to load students: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    var list = _all.where((s) {
      // search
      if (q.isNotEmpty &&
          !s.fullName.toLowerCase().contains(q) &&
          !s.admissionNumber.toLowerCase().contains(q) &&
          !s.classForAdmission.toLowerCase().contains(q)) return false;
      // class filter
      if (_filterClass != null) {
        final base = SchoolConstants.parseClassName(s.classForAdmission).$1;
        if (base != _filterClass) return false;
      }
      // status filter
      if (_filterStatus != 'ALL' &&
          s.status.toUpperCase() != _filterStatus) return false;
      return true;
    }).toList();

    switch (_sortBy) {
      case _SortBy.dateDesc:
        list.sort((a, b) => b.dateOfAdmission.compareTo(a.dateOfAdmission));
      case _SortBy.dateAsc:
        list.sort((a, b) => a.dateOfAdmission.compareTo(b.dateOfAdmission));
      case _SortBy.nameAZ:
        list.sort((a, b) => a.fullName.compareTo(b.fullName));
      case _SortBy.nameZA:
        list.sort((a, b) => b.fullName.compareTo(a.fullName));
      case _SortBy.classAsc:
        list.sort((a, b) =>
            SchoolConstants.allClasses
                .indexOf(a.classForAdmission)
                .compareTo(
                    SchoolConstants.allClasses.indexOf(b.classForAdmission)));
    }
    setState(() => _filtered = list);
  }

  List<String> get _availableClasses {
    final seen = <String>{};
    final result = <String>[];
    for (final s in _all) {
      final base = SchoolConstants.parseClassName(s.classForAdmission).$1;
      if (seen.add(base)) result.add(base);
    }
    result.sort((a, b) => SchoolConstants.baseClasses
        .indexOf(a)
        .compareTo(SchoolConstants.baseClasses.indexOf(b)));
    return result;
  }

  bool get _hasActiveFilters =>
      _filterClass != null || _filterStatus != 'ALL';

  void _clearFilters() {
    _filterClass = null;
    _filterStatus = 'ALL';
    _filter();
  }

  void _navigateToAdmission({String? studentId}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NewAdmissionScreen(studentId: studentId)),
    );
    if (saved == true) _fetch();
  }

  Future<void> _deleteStudent(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Student',
            style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700)),
        content: Text('Remove $name from the system? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await AdmissionApiService.deleteStudent(id);
        _fetch();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('$name removed'),
                backgroundColor: AppColors.success),
          );
        }
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _buildError()
              : _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        onPressed: () => _navigateToAdmission(),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text('New Admission',
            style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text(_error,
              style: GoogleFonts.nunitoSans(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetch,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final total = _all.length;
    final shown = _filtered.length;
    final subtitle = _hasActiveFilters
        ? '$shown of $total students'
        : '$total students enrolled';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Student Admissions',
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 26,
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
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: _filtered.isEmpty
                    ? null
                    : () => CsvExportService.exportAdmissions(_filtered),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Export CSV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  side: const BorderSide(color: AppColors.navy),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _fetch,
                icon: const Icon(Icons.refresh, color: AppColors.navy),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search bar
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by name, admission no., or class…',
              hintStyle: GoogleFonts.nunitoSans(color: AppColors.textLight),
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.textLight),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _filter();
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                borderSide: const BorderSide(color: AppColors.navy),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          // Class filter chips
          _buildClassFilterRow(),
          const SizedBox(height: 8),

          // Status chips + sort
          _buildStatusAndSort(),
          const SizedBox(height: 16),

          // Table or empty state
          if (_filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(
                      _hasActiveFilters
                          ? Icons.filter_list_off_rounded
                          : Icons.people_outline,
                      size: 64,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _hasActiveFilters
                          ? 'No students match filters'
                          : 'No students found',
                      style: GoogleFonts.nunitoSans(
                          color: AppColors.textSecondary),
                    ),
                    if (_hasActiveFilters) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _clearFilters,
                        child: Text('Clear filters',
                            style: GoogleFonts.nunitoSans(
                                color: AppColors.navy)),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                child: PaginatedDataTable(
                  header: Text('Students (${_filtered.length})',
                      style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy)),
                  rowsPerPage: 10,
                  columns: [
                    DataColumn(
                        label: Text('Adm No.',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('Name',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('Class',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('DOA',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('Father',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('Status',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('Actions',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                  ],
                  source: _StudentDataSource(
                    students: _filtered,
                    context: context,
                    fmt: _fmt,
                    onView: (id) => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => StudentDetailScreen(studentId: id))),
                    onEdit: (id) => _navigateToAdmission(studentId: id),
                    onDelete: (id, name) => _deleteStudent(id, name),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClassFilterRow() {
    final classes = _availableClasses;
    if (classes.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _classChip('All', _filterClass == null,
              () => setState(() { _filterClass = null; _filter(); })),
          const SizedBox(width: 6),
          ...classes.map((cls) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _classChip(cls, _filterClass == cls, () {
                  _filterClass = cls;
                  _filter();
                }),
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
          border:
              Border.all(color: selected ? AppColors.navy : AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.nunitoSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

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
      onTap: () {
        _filterStatus = value;
        _filter();
      },
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
      _SortBy.dateDesc => 'Newest first',
      _SortBy.dateAsc => 'Oldest first',
      _SortBy.nameAZ => 'Name A→Z',
      _SortBy.nameZA => 'Name Z→A',
      _SortBy.classAsc => 'By Class',
    };
    return PopupMenuButton<_SortBy>(
      onSelected: (v) {
        _sortBy = v;
        _filter();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: _SortBy.dateDesc, child: Text('Newest first')),
        PopupMenuItem(value: _SortBy.dateAsc, child: Text('Oldest first')),
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
}

class _StudentDataSource extends DataTableSource {
  final List<Student> students;
  final BuildContext context;
  final DateFormat fmt;
  final void Function(String) onView;
  final void Function(String) onEdit;
  final void Function(String, String) onDelete;

  _StudentDataSource({
    required this.students,
    required this.context,
    required this.fmt,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= students.length) return null;
    final s = students[index];
    final isActive = s.status.toUpperCase() == 'ACTIVE';
    return DataRow(cells: [
      DataCell(Text(s.admissionNumber,
          style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600))),
      DataCell(Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.navy.withOpacity(0.1),
          child: Text(s.fullName.substring(0, 1).toUpperCase(),
              style: GoogleFonts.cormorantGaramond(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ),
        const SizedBox(width: 8),
        Text(s.fullName, style: GoogleFonts.nunitoSans()),
      ])),
      DataCell(Text(s.classForAdmission, style: GoogleFonts.nunitoSans())),
      DataCell(
          Text(fmt.format(s.dateOfAdmission), style: GoogleFonts.nunitoSans())),
      DataCell(
          Text(s.parentDetails.fatherName, style: GoogleFonts.nunitoSans())),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (isActive ? AppColors.success : AppColors.error)
              .withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(s.status,
            style: GoogleFonts.nunitoSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.success : AppColors.error)),
      )),
      DataCell(Row(children: [
        IconButton(
          icon: const Icon(Icons.visibility_outlined, size: 18),
          color: AppColors.info,
          tooltip: 'View Details',
          onPressed: () => onView(s.id!),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          color: AppColors.warning,
          tooltip: 'Edit',
          onPressed: () => onEdit(s.id!),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          color: AppColors.error,
          tooltip: 'Delete',
          onPressed: () => onDelete(s.id!, s.fullName),
        ),
      ])),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => students.length;

  @override
  int get selectedRowCount => 0;
}
