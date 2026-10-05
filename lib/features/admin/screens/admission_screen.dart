import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/academic_year.dart';
import '../../../models/admission_data.dart';
import '../../../services/admission_api_service.dart';
import '../../../services/csv_export_service.dart';
import '../../../core/widgets/searchable_dropdown.dart';
import 'new_admission_screen.dart';
import 'student_detail_screen.dart';

import '../../../services/admission_print_service.dart';
import 'fee_collection_screen.dart';

enum _SortBy { dateDesc, dateAsc, nameAZ, nameZA, classAsc }
enum _PipelineStage { all, enquiry, active, other }

class AdmissionScreen extends StatefulWidget {
  const AdmissionScreen({super.key});

  @override
  State<AdmissionScreen> createState() => _AdmissionScreenState();
}

class _AdmissionScreenState extends State<AdmissionScreen> {
  List<Student> _allStudents = [];
  List<Student> _filtered = [];
  bool _isLoading = true;
  String _error = '';
  final _searchCtrl = TextEditingController();
  final _fmt = DateFormat('dd MMM yyyy');

  String? _filterClass;
  _PipelineStage _selectedStage = _PipelineStage.all;
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
        _allStudents = students;
      });
      _filter();
    } catch (e) {
      setState(() => _error = 'Failed to load admissions & enquiries: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase().trim();
    var list = _allStudents.where((s) {
      // Pipeline stage filter
      final statusUpper = s.status.toUpperCase();
      if (_selectedStage == _PipelineStage.enquiry && statusUpper != 'ENQUIRY') {
        return false;
      }
      if (_selectedStage == _PipelineStage.active && statusUpper != 'ACTIVE') {
        return false;
      }
      if (_selectedStage == _PipelineStage.other &&
          (statusUpper == 'ENQUIRY' || statusUpper == 'ACTIVE')) {
        return false;
      }

      // Search query
      if (q.isNotEmpty &&
          !s.fullName.toLowerCase().contains(q) &&
          !s.admissionNumber.toLowerCase().contains(q) &&
          !s.classForAdmission.toLowerCase().contains(q) &&
          !s.parentDetails.fatherName.toLowerCase().contains(q) &&
          !s.contactDetails.primaryContactNumber.contains(q)) {
        return false;
      }

      // Class filter
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
        list.sort((a, b) => SchoolConstants.allClasses
            .indexOf(a.classForAdmission)
            .compareTo(
                SchoolConstants.allClasses.indexOf(b.classForAdmission)));
    }
    setState(() => _filtered = list);
  }

  List<String> get _availableClasses {
    final seen = <String>{};
    final result = <String>[];
    for (final s in _allStudents) {
      final base = SchoolConstants.parseClassName(s.classForAdmission).$1;
      if (seen.add(base)) result.add(base);
    }
    result.sort((a, b) => SchoolConstants.baseClasses
        .indexOf(a)
        .compareTo(SchoolConstants.baseClasses.indexOf(b)));
    return result;
  }

  bool get _hasActiveFilters =>
      _filterClass != null || _selectedStage != _PipelineStage.all;

  void _clearFilters() {
    _filterClass = null;
    _selectedStage = _PipelineStage.all;
    _filter();
  }

  // Statistics
  int get _totalApplicants => _allStudents.length;
  int get _enquiryCount =>
      _allStudents.where((s) => s.status.toUpperCase() == 'ENQUIRY').length;
  int get _enrolledCount =>
      _allStudents.where((s) => s.status.toUpperCase() == 'ACTIVE').length;
  double get _conversionRate => _totalApplicants > 0
      ? (_enrolledCount / _totalApplicants) * 100
      : 0.0;

  /// Opens full NewAdmissionScreen to edit + admit an enquiry.
  Future<void> _admitEnquiry(String studentId) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              NewAdmissionScreen(studentId: studentId, admitMode: true)),
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
    String selectedYear = AcademicYear.currentLong();
    DateTime enquiryDate = DateTime.now();
    bool saving = false;
    final formKey = GlobalKey<FormState>();
    final fmt = DateFormat('dd MMM yyyy');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          scrollable: true,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('New Enquiry',
              style: GoogleFonts.cormorantGaramond(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: AppColors.navy)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
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
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownFormField<String>(
                      labelText: 'Class / Section Interested In *',
                      initialValue: selectedClass,
                      items: SchoolConstants.allClasses,
                      onChanged: (v) => setSt(() => selectedClass = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownFormField<String>(
                      labelText: 'Academic Year *',
                      initialValue: selectedYear,
                      items: AcademicYear.choices(),
                      onChanged: (v) => setSt(() => selectedYear = v!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: parentCtrl,
                      decoration: _inputDec('Parent / Guardian Name *'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          border: Border.all(color: AppColors.border),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD),
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
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white),
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
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
                          dateOfBirth: DateTime(2000, 1,
                              1), // placeholder, admin updates on admission
                          gender: '',
                          bloodGroup: '',
                          nationality: 'Indian',
                          religion: '',
                          motherTongue: '',
                          aadharNumber: '',
                          classForAdmission: selectedClass!,
                          academicYear: selectedYear,
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
                              content: Text(
                                  'Enquiry saved for ${nameCtrl.text.trim()}'),
                              backgroundColor: AppColors.success));
                        }
                      } catch (e) {
                        setSt(() => saving = false);
                        if (mounted) {
                          final detail =
                              e is DioException ? e.response?.data : null;
                          final message = detail is Map &&
                                  detail['detail'] != null
                              ? detail['detail'].toString()
                              : 'Please check the enquiry details and try again.';
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Failed to save enquiry: $message'),
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
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            borderSide: const BorderSide(color: AppColors.navy, width: 2)),
        labelStyle: GoogleFonts.nunitoSans(color: AppColors.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    final total = _allStudents.length;
    final shown = _filtered.length;
    final subtitle = _hasActiveFilters
        ? '$shown of $total records matching filter'
        : '$total total applicants & admitted students';

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
                    Text('Admissions & Enrollment Hub',
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
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _fetch,
                icon: const Icon(Icons.refresh, color: AppColors.navy),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // KPI Metric Strip
          _buildKpiStrip(),
          const SizedBox(height: 16),

          // Pipeline Stage Tabs
          _buildPipelineStageTabs(),
          const SizedBox(height: 14),

          // Class Intake Capacity Bar (if class filter selected or summary)
          _buildIntakeCapacityCard(),
          const SizedBox(height: 14),

          // Search bar
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by student name, admission/enquiry no, class or contact phone…',
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
                          ? 'No candidates match selected criteria'
                          : 'No admission records found.\nTap "+ New Enquiry" or admit candidates.',
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
                  header: Text('Candidates & Enrolments (${_filtered.length})',
                      style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w600, color: AppColors.navy)),
                  rowsPerPage: 10,
                  columns: [
                    DataColumn(
                        label: Text('Number',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('Student Name',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('Stage / Status',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('Class Applied',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('Parent / Guardian',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('Contact',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700))),
                    DataColumn(
                        label: Text('Date',
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
                            builder: (_) =>
                                StudentDetailScreen(studentId: id))),
                    onAdmit: (id) => _admitEnquiry(id),
                    onDelete: (id, name) => _deleteEnquiry(id, name),
                    onPrintOffer: (student) =>
                        AdmissionPrintService.printOfferLetter(student: student),
                    onPrintIdCard: (student) =>
                        AdmissionPrintService.printIdCard(student: student),
                    onCollectFee: (student) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FeeCollectionScreen(
                            preSelectedStudentId: student.id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKpiStrip() {
    return LayoutBuilder(builder: (context, constraints) {
      final isCompact = constraints.maxWidth < 700;
      final kpis = [
        _buildKpiCard('Total Applications', '$_totalApplicants', Icons.folder_shared_outlined, AppColors.navy),
        _buildKpiCard('Active Enquiries', '$_enquiryCount', Icons.contact_support_outlined, AppColors.warning),
        _buildKpiCard('Admitted / Active', '$_enrolledCount', Icons.verified_user_outlined, AppColors.success),
        _buildKpiCard('Conversion Rate', '${_conversionRate.toStringAsFixed(1)}%', Icons.pie_chart_outline, AppColors.info),
      ];

      if (isCompact) {
        return Wrap(spacing: 8, runSpacing: 8, children: kpis.map((k) => SizedBox(width: (constraints.maxWidth - 8) / 2, child: k)).toList());
      }
      return Row(children: kpis.map((k) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: k))).toList());
    });
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.navy)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                      fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildPipelineStageTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _pipelineTab('All (${_allStudents.length})', _PipelineStage.all),
          _pipelineTab('Enquiries ($_enquiryCount)', _PipelineStage.enquiry),
          _pipelineTab('Enrolled ($_enrolledCount)', _PipelineStage.active),
        ],
      ),
    );
  }

  Widget _pipelineTab(String label, _PipelineStage stage) {
    final active = _selectedStage == stage;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStage = stage;
            _filter();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.nunitoSans(
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? Colors.white : AppColors.navy,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntakeCapacityCard() {
    final targetClass = _filterClass ?? 'Class 1';
    final admittedInClass = _allStudents.where((s) {
      final base = SchoolConstants.parseClassName(s.classForAdmission).$1;
      return base == targetClass && s.status.toUpperCase() == 'ACTIVE';
    }).length;
    const maxCapacity = 40; // Standard batch capacity
    final ratio = (admittedInClass / maxCapacity).clamp(0.0, 1.0);
    final isFull = admittedInClass >= maxCapacity;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.airline_seat_recline_normal_rounded,
                size: 16, color: isFull ? AppColors.error : AppColors.navy),
            const SizedBox(width: 8),
            Text('Intake Capacity for $targetClass:',
                style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
            const Spacer(),
            Text('$admittedInClass / $maxCapacity seats filled',
                style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: isFull ? AppColors.error : AppColors.textSecondary)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.navy.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                isFull ? AppColors.error : (ratio > 0.8 ? AppColors.warning : AppColors.success),
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
      return AnimatedContainer(
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
      );
    }
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip(
              'All',
              _filterClass == null,
              () => setState(() {
                    _filterClass = null;
                    _filter();
                  })),
          const SizedBox(width: 6),
          ...classes.map((cls) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _chip(cls, _filterClass == cls, () {
                  setState(() {
                    _filterClass = cls;
                    _filter();
                  });
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
          border:
              Border.all(color: selected ? AppColors.navy : AppColors.border),
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
      onSelected: (v) {
        setState(() {
          _sortBy = v;
          _filter();
        });
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
  final void Function(Student) onPrintOffer;
  final void Function(Student) onPrintIdCard;
  final void Function(Student) onCollectFee;

  _EnquiryDataSource({
    required this.students,
    required this.context,
    required this.fmt,
    required this.onView,
    required this.onAdmit,
    required this.onDelete,
    required this.onPrintOffer,
    required this.onPrintIdCard,
    required this.onCollectFee,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= students.length) return null;
    final s = students[index];
    final isEnquiry = s.status.toUpperCase() == 'ENQUIRY';
    final isActive = s.status.toUpperCase() == 'ACTIVE';

    final stageColor = isActive
        ? AppColors.success
        : isEnquiry
            ? AppColors.warning
            : AppColors.info;

    return DataRow(cells: [
      DataCell(Text(
          s.admissionNumber.isNotEmpty ? s.admissionNumber : (s.id?.substring(0, 8) ?? '—'),
          style: GoogleFonts.nunitoSans(
              fontWeight: FontWeight.w600, color: AppColors.navy))),
      DataCell(Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: stageColor.withValues(alpha: 0.15),
          child: Text(
              s.fullName.isNotEmpty ? s.fullName.substring(0, 1).toUpperCase() : '?',
              style: GoogleFonts.cormorantGaramond(
                  color: stageColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ),
        const SizedBox(width: 8),
        Text(s.fullName, style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
      ])),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: stageColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(s.status,
            style: GoogleFonts.nunitoSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: stageColor)),
      )),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(s.classForAdmission,
            style: GoogleFonts.nunitoSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.navy)),
      )),
      DataCell(Text(
          s.parentDetails.fatherName.isNotEmpty
              ? s.parentDetails.fatherName
              : '—',
          style: GoogleFonts.nunitoSans())),
      DataCell(Text(
          s.contactDetails.primaryContactNumber.isNotEmpty
              ? s.contactDetails.primaryContactNumber
              : s.parentDetails.fatherMobile.isNotEmpty
                  ? s.parentDetails.fatherMobile
                  : '—',
          style: GoogleFonts.nunitoSans())),
      DataCell(
          Text(fmt.format(s.dateOfAdmission), style: GoogleFonts.nunitoSans())),
      DataCell(Row(children: [
        IconButton(
          icon: const Icon(Icons.visibility_outlined, size: 18),
          color: AppColors.info,
          tooltip: 'View Details',
          onPressed: () => onView(s.id!),
        ),
        // If enquiry, show "Admit" button
        if (isEnquiry) ...[
          Tooltip(
            message: 'Admit Student',
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: GoogleFonts.nunitoSans(
                    fontSize: 11, fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.how_to_reg_outlined, size: 14),
              label: const Text('Admit'),
              onPressed: () => onAdmit(s.id!),
            ),
          ),
          const SizedBox(width: 4),
        ],
        // If admitted / active, show "Offer Letter", "ID Card", & "Collect Fee"
        if (isActive) ...[
          IconButton(
            icon: const Icon(Icons.description_outlined, size: 18),
            color: AppColors.navy,
            tooltip: 'Print Offer Letter',
            onPressed: () => onPrintOffer(s),
          ),
          IconButton(
            icon: const Icon(Icons.badge_outlined, size: 18),
            color: AppColors.gold,
            tooltip: 'Print Student ID Card',
            onPressed: () => onPrintIdCard(s),
          ),
          IconButton(
            icon: const Icon(Icons.payments_outlined, size: 18),
            color: AppColors.success,
            tooltip: 'Collect Fee',
            onPressed: () => onCollectFee(s),
          ),
        ],
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          color: AppColors.error,
          tooltip: 'Delete Record',
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
