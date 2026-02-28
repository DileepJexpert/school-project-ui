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
  // Enquiry-only data (status == ENQUIRY)
  List<Student> _all = [];
  List<Student> _filtered = [];
  bool _isLoading = true;
  String _error = '';
  final _searchCtrl = TextEditingController();
  final _fmt = DateFormat('dd MMM yyyy');

  String? _filterClass;
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
      // Set _all first, then call _filter separately to avoid nested setState
      setState(() {
        _all = students.where((s) => s.status.toUpperCase() == 'ENQUIRY').toList();
      });
      _filter();
    } catch (e) {
      setState(() => _error = 'Failed to load enquiries: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    var list = _all.where((s) {
      if (q.isNotEmpty &&
          !s.fullName.toLowerCase().contains(q) &&
          !s.admissionNumber.toLowerCase().contains(q) &&
          !s.classForAdmission.toLowerCase().contains(q) &&
          !s.parentDetails.fatherName.toLowerCase().contains(q) &&
          !s.contactDetails.primaryContactNumber.contains(q)) return false;
      if (_filterClass != null) {
        final base = SchoolConstants.parseClassName(s.classForAdmission).$1;
        if (base != _filterClass) return false;
      }
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
                .compareTo(SchoolConstants.allClasses.indexOf(b.classForAdmission)));
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
    result.sort((a, b) => SchoolConstants.baseClasses.indexOf(a)
        .compareTo(SchoolConstants.baseClasses.indexOf(b)));
    return result;
  }

  bool get _hasActiveFilters => _filterClass != null;

  void _clearFilters() {
    _filterClass = null;
    _filter();
  }

  /// Opens full NewAdmissionScreen to edit + admit an enquiry.
  Future<void> _admitEnquiry(String studentId) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => NewAdmissionScreen(studentId: studentId, admitMode: true)),
    );
    if (saved == true) _fetch();
  }

  Future<void> _deleteEnquiry(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Enquiry',
            style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700)),
        content: Text('Remove enquiry for $name? This cannot be undone.'),
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
    if (confirmed == true) {
      try {
        await AdmissionApiService.deleteStudent(id);
        _fetch();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Enquiry for $name removed'),
              backgroundColor: AppColors.success));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: AppColors.error));
        }
      }
    }
  }

  void _showEnquiryDialog() {
    final nameCtrl = TextEditingController();
    final parentCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String? selectedClass;
    DateTime enquiryDate = DateTime.now();
    bool saving = false;
    final formKey = GlobalKey<FormState>();
    final fmt = DateFormat('dd MMM yyyy');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('New Enquiry',
              style: GoogleFonts.cormorantGaramond(
                  fontWeight: FontWeight.w700, fontSize: 22, color: AppColors.navy)),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Capture basic details for a walk-in enquiry. Full admission details can be filled when converting to an admission.',
                    style: GoogleFonts.nunitoSans(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: _inputDec('Student Name *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: _inputDec('Class Interested In *'),
                    value: selectedClass,
                    items: SchoolConstants.baseClasses
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setSt(() => selectedClass = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: parentCtrl,
                    decoration: _inputDec('Parent / Guardian Name *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: _inputDec('Contact Number *'),
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (v.trim().length < 10) return 'Enter valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Enquiry date picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: enquiryDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) setSt(() => enquiryDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 18, color: AppColors.navy),
                        const SizedBox(width: 8),
                        Text('Enquiry Date: ${fmt.format(enquiryDate)}',
                            style: GoogleFonts.nunitoSans(
                                color: AppColors.textPrimary, fontSize: 14)),
                        const Spacer(),
                        Text('Change',
                            style: GoogleFonts.nunitoSans(
                                color: AppColors.navy, fontSize: 12)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy, foregroundColor: Colors.white),
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_alt_outlined, size: 18),
              label: Text(saving ? 'Saving…' : 'Save Enquiry'),
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setSt(() => saving = true);
                      try {
                        final student = Student(
                          fullName: nameCtrl.text.trim(),
                          dateOfBirth: DateTime(2000, 1, 1), // placeholder, admin updates on admission
                          gender: '',
                          bloodGroup: '',
                          nationality: 'Indian',
                          religion: '',
                          motherTongue: '',
                          aadharNumber: '',
                          classForAdmission: selectedClass!,
                          academicYear: '2025-2026',
                          dateOfAdmission: enquiryDate,
                          admissionNumber: '',
                          status: 'ENQUIRY',
                          parentDetails: ParentDetails(
                            fatherName: parentCtrl.text.trim(),
                            fatherOccupation: '',
                            fatherMobile: phoneCtrl.text.trim(),
                            fatherEmail: '',
                            motherName: '',
                            motherOccupation: '',
                            motherMobile: '',
                            motherEmail: '',
                          ),
                          contactDetails: ContactDetails(
                            permanentAddress: '',
                            correspondenceAddress: '',
                            primaryContactNumber: phoneCtrl.text.trim(),
                          ),
                          previousSchoolDetails: PreviousSchoolDetails(
                            schoolName: '',
                            lastClass: '',
                            board: '',
                          ),
                        );
                        await AdmissionApiService.submitEnquiry(student);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _fetch();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Enquiry saved for ${nameCtrl.text.trim()}'),
                              backgroundColor: AppColors.success));
                        }
                      } catch (e) {
                        setSt(() => saving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Failed to save enquiry: $e'),
                              backgroundColor: AppColors.error));
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            borderSide: const BorderSide(color: AppColors.navy, width: 2)),
        labelStyle: GoogleFonts.nunitoSans(color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

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
        onPressed: _showEnquiryDialog,
        icon: const Icon(Icons.person_search_outlined),
        label: Text('New Enquiry',
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
              label: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final total = _all.length;
    final shown = _filtered.length;
    final subtitle = _hasActiveFilters
        ? '$shown of $total enquiries'
        : '$total enquiries pending';

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
                    Text('Enquiry Management',
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
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
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
          const SizedBox(height: 8),

          // Info banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.navy.withOpacity(0.06),
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              border: Border.all(color: AppColors.navy.withOpacity(0.15)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Walk-in enquiries are listed here. Click "Admit" to convert an enquiry into a full student admission.',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 12, color: AppColors.navy),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // Search bar
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by name, enquiry no., class or contact…',
              hintStyle: GoogleFonts.nunitoSans(color: AppColors.textLight),
              prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _filter();
                      })
                  : null,
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                  borderSide: const BorderSide(color: AppColors.navy)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          // Class filter chips + sort
          Row(
            children: [
              Expanded(child: _buildClassFilterRow()),
              const SizedBox(width: 8),
              _buildSortButton(),
            ],
          ),
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
                          : Icons.person_search_outlined,
                      size: 64,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _hasActiveFilters
                          ? 'No enquiries match filters'
                          : 'No enquiries yet.\nTap "+ New Enquiry" to add one.',
                      style: GoogleFonts.nunitoSans(
                          color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    if (_hasActiveFilters) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _clearFilters,
                        child: Text('Clear filters',
                            style:
                                GoogleFonts.nunitoSans(color: AppColors.navy)),
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
                  header: Text('Enquiries (${_filtered.length})',
                      style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w600, color: AppColors.navy)),
                  rowsPerPage: 10,
                  columns: [
                    DataColumn(
                        label: Text('Enquiry No.',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('Name',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('Class Interested',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('Parent',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('Contact',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('Enquiry Date',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('Actions',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                  ],
                  source: _EnquiryDataSource(
                    students: _filtered,
                    context: context,
                    fmt: _fmt,
                    onView: (id) => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => StudentDetailScreen(studentId: id))),
                    onAdmit: (id) => _admitEnquiry(id),
                    onDelete: (id, name) => _deleteEnquiry(id, name),
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
    if (classes.isEmpty) {
      return GestureDetector(
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.navy,
            border: Border.all(color: AppColors.navy),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('All',
              style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ),
      );
    }
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip('All', _filterClass == null,
              () => setState(() { _filterClass = null; _filter(); })),
          const SizedBox(width: 6),
          ...classes.map((cls) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _chip(cls, _filterClass == cls, () {
                  setState(() { _filterClass = cls; _filter(); });
                }),
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
    final label = switch (_sortBy) {
      _SortBy.dateDesc => 'Newest first',
      _SortBy.dateAsc => 'Oldest first',
      _SortBy.nameAZ => 'Name A→Z',
      _SortBy.nameZA => 'Name Z→A',
      _SortBy.classAsc => 'By Class',
    };
    return PopupMenuButton<_SortBy>(
      onSelected: (v) { setState(() { _sortBy = v; _filter(); }); },
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
                    fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy)),
            const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.navy),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data source for the enquiry table
// ---------------------------------------------------------------------------
class _EnquiryDataSource extends DataTableSource {
  final List<Student> students;
  final BuildContext context;
  final DateFormat fmt;
  final void Function(String) onView;
  final void Function(String) onAdmit;
  final void Function(String, String) onDelete;

  _EnquiryDataSource({
    required this.students,
    required this.context,
    required this.fmt,
    required this.onView,
    required this.onAdmit,
    required this.onDelete,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= students.length) return null;
    final s = students[index];
    return DataRow(cells: [
      DataCell(Text(s.admissionNumber,
          style: GoogleFonts.nunitoSans(
              fontWeight: FontWeight.w600, color: AppColors.navy))),
      DataCell(Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.warning.withOpacity(0.15),
          child: Text(s.fullName.substring(0, 1).toUpperCase(),
              style: GoogleFonts.cormorantGaramond(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ),
        const SizedBox(width: 8),
        Text(s.fullName, style: GoogleFonts.nunitoSans()),
      ])),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.navy.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(s.classForAdmission,
            style: GoogleFonts.nunitoSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.navy)),
      )),
      DataCell(Text(s.parentDetails.fatherName.isNotEmpty
          ? s.parentDetails.fatherName
          : '—', style: GoogleFonts.nunitoSans())),
      DataCell(Text(s.contactDetails.primaryContactNumber.isNotEmpty
          ? s.contactDetails.primaryContactNumber
          : s.parentDetails.fatherMobile.isNotEmpty
              ? s.parentDetails.fatherMobile
              : '—',
          style: GoogleFonts.nunitoSans())),
      DataCell(Text(fmt.format(s.dateOfAdmission), style: GoogleFonts.nunitoSans())),
      DataCell(Row(children: [
        IconButton(
          icon: const Icon(Icons.visibility_outlined, size: 18),
          color: AppColors.info,
          tooltip: 'View Details',
          onPressed: () => onView(s.id!),
        ),
        // Admit button — convert enquiry to full admission
        Tooltip(
          message: 'Admit Student',
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: GoogleFonts.nunitoSans(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
            icon: const Icon(Icons.how_to_reg_outlined, size: 16),
            label: const Text('Admit'),
            onPressed: () => onAdmit(s.id!),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          color: AppColors.error,
          tooltip: 'Delete Enquiry',
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
