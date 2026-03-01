import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/result_models.dart';
import '../../../models/student_model.dart';
import '../../../services/result_api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kExamTypes = [
  'UNIT_TEST_1',
  'UNIT_TEST_2',
  'MID_TERM',
  'HALF_YEARLY',
  'ANNUAL',
  'PRE_BOARD',
];

const _kExamLabels = {
  'UNIT_TEST_1': 'Unit Test 1',
  'UNIT_TEST_2': 'Unit Test 2',
  'MID_TERM': 'Mid Term',
  'HALF_YEARLY': 'Half Yearly',
  'ANNUAL': 'Annual',
  'PRE_BOARD': 'Pre-Board',
};

const _kYears = ['2024-25', '2025-26', '2026-27'];

// ─────────────────────────────────────────────────────────────────────────────
// Root screen
// ─────────────────────────────────────────────────────────────────────────────

class ResultsAdminScreen extends StatefulWidget {
  const ResultsAdminScreen({super.key});

  @override
  State<ResultsAdminScreen> createState() => _ResultsAdminScreenState();
}

class _ResultsAdminScreenState extends State<ResultsAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text('Results Management',
            style: GoogleFonts.cormorantGaramond(
                fontWeight: FontWeight.w700, fontSize: 20)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              GoogleFonts.nunitoSans(fontWeight: FontWeight.w600, fontSize: 12),
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note, size: 18), text: 'Enter Marks'),
            Tab(icon: Icon(Icons.table_chart, size: 18), text: 'Result Sheet'),
            Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Analytics'),
            Tab(icon: Icon(Icons.badge_outlined, size: 18), text: 'Report Card'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _EnterMarksTab(),
          _ResultSheetTab(),
          _AnalyticsTab(),
          _ReportCardTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _fieldDec(String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );

Widget _sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text,
          style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.navy)),
    );

/// Grade chip coloured by CBSE grade
Widget _gradeChip(String grade) {
  final color = switch (grade) {
    'A1' => const Color(0xFF059669),
    'A2' => const Color(0xFF10B981),
    'B1' => AppColors.info,
    'B2' => const Color(0xFF6366F1),
    'C1' => AppColors.warning,
    'C2' => const Color(0xFFF97316),
    'D' => const Color(0xFFEF4444),
    _ => AppColors.error,
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(grade,
        style: GoogleFonts.nunitoSans(
            color: color, fontWeight: FontWeight.w700, fontSize: 12)),
  );
}

Widget _statCard(String title, String value, IconData icon, Color color) =>
    Card(
      elevation: 0,
      color: color.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.nunitoSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(title,
              style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — Enter Marks (bulk entry for entire class)
// ─────────────────────────────────────────────────────────────────────────────

class _EnterMarksTab extends StatefulWidget {
  const _EnterMarksTab();

  @override
  State<_EnterMarksTab> createState() => _EnterMarksTabState();
}

class _EnterMarksTabState extends State<_EnterMarksTab> {
  String? _year;
  String? _className;
  String? _examType;
  final _subjectCtrl = TextEditingController();
  final _maxMarksCtrl = TextEditingController(text: '100');

  List<StudentModel> _students = [];
  final Map<String, TextEditingController> _marksCtrls = {};
  final Map<String, TextEditingController> _remarksCtrls = {};

  bool _loading = false;
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _maxMarksCtrl.dispose();
    for (final c in _marksCtrls.values) {
      c.dispose();
    }
    for (final c in _remarksCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStudents() async {
    if (_year == null || _className == null) {
      _snack('Select academic year and class first.', AppColors.warning);
      return;
    }
    setState(() => _loading = true);
    try {
      final students =
          await ResultApiService.getStudentsByClass(_className!, _year!);
      for (final s in students) {
        _marksCtrls[s.id!] ??= TextEditingController();
        _remarksCtrls[s.id!] ??= TextEditingController();
      }
      setState(() => _students = students);
    } catch (e) {
      _snack('Failed to load students: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitAll() async {
    if (_year == null || _className == null || _examType == null ||
        _subjectCtrl.text.isEmpty) {
      _snack('Fill all required fields above.', AppColors.warning);
      return;
    }
    if (_students.isEmpty) {
      _snack('Load students first.', AppColors.warning);
      return;
    }

    final double maxM =
        double.tryParse(_maxMarksCtrl.text) ?? 100;

    final entries = _students
        .where((s) => (_marksCtrls[s.id!]?.text ?? '').isNotEmpty)
        .map((s) => {
              'studentId': s.id,
              'studentName': s.fullName,
              'rollNumber': s.rollNumber ?? '',
              'marksObtained':
                  double.tryParse(_marksCtrls[s.id!]!.text) ?? 0.0,
              'teacherRemarks': _remarksCtrls[s.id!]?.text ?? '',
            })
        .toList();

    if (entries.isEmpty) {
      _snack('Enter at least one mark.', AppColors.warning);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ResultApiService.bulkSubmitResults(
        className: _className!,
        examType: _examType!,
        academicYear: _year!,
        subject: _subjectCtrl.text.trim(),
        maxMarks: maxM,
        enteredBy: 'Admin',
        entries: entries,
      );
      _snack('Marks submitted for ${entries.length} students!',
          AppColors.success);
      // Clear mark fields
      for (final c in _marksCtrls.values) {
        c.clear();
      }
      for (final c in _remarksCtrls.values) {
        c.clear();
      }
    } catch (e) {
      _snack('Submit failed: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionTitle('Enter Class Marks'),
            Text(
                'Select class + exam + subject → load students → enter marks → submit.',
                style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),

            // ── Filters ───────────────────────────────────────────────────
            Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: _year,
                  decoration: _fieldDec('Academic Year *'),
                  items: _kYears
                      .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                      .toList(),
                  onChanged: (v) => setState(() => _year = v),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: _className,
                  decoration: _fieldDec('Class *'),
                  items: SchoolConstants.allClasses
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _className = v),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: _examType,
                  decoration: _fieldDec('Exam Type *'),
                  items: _kExamTypes
                      .map((e) => DropdownMenuItem(
                          value: e, child: Text(_kExamLabels[e]!)))
                      .toList(),
                  onChanged: (v) => setState(() => _examType = v),
                ),
              ),
              SizedBox(
                width: 200,
                child: TextFormField(
                  controller: _subjectCtrl,
                  decoration: _fieldDec('Subject *'),
                ),
              ),
              SizedBox(
                width: 140,
                child: TextFormField(
                  controller: _maxMarksCtrl,
                  decoration: _fieldDec('Max Marks'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ]),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyLight,
                  foregroundColor: Colors.white),
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.group_outlined),
              label: Text(_loading ? 'Loading…' : 'Load Students',
                  style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700)),
              onPressed: _loading ? null : _loadStudents,
            ),

            // ── Marks Grid ────────────────────────────────────────────────
            if (_students.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(children: [
                Text('${_students.length} Students — ',
                    style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w700, color: AppColors.navy)),
                Text('${_className ?? ''} · ${_kExamLabels[_examType] ?? ''} · ${_subjectCtrl.text}',
                    style: GoogleFonts.nunitoSans(
                        color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                    side: const BorderSide(color: AppColors.border)),
                child: Column(
                  children: _students.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final s = entry.value;
                    return Container(
                      decoration: BoxDecoration(
                        color: idx.isEven
                            ? AppColors.white
                            : AppColors.creamDark,
                        borderRadius: idx == 0
                            ? const BorderRadius.vertical(
                                top: Radius.circular(AppSizes.radiusLG))
                            : idx == _students.length - 1
                                ? const BorderRadius.vertical(
                                    bottom: Radius.circular(AppSizes.radiusLG))
                                : BorderRadius.zero,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(children: [
                        // Roll No
                        SizedBox(
                          width: 36,
                          child: Text(s.rollNumber ?? '${idx + 1}',
                              style: GoogleFonts.nunitoSans(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        // Name
                        Expanded(
                          flex: 3,
                          child: Text(s.fullName,
                              style: GoogleFonts.nunitoSans(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                        ),
                        const SizedBox(width: 8),
                        // Marks
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: _marksCtrls[s.id!],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Marks',
                              hintStyle: GoogleFonts.nunitoSans(
                                  fontSize: 12,
                                  color: AppColors.textLight),
                              filled: true,
                              fillColor: AppColors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                            ),
                            style:
                                GoogleFonts.nunitoSans(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Remarks
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _remarksCtrls[s.id!],
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Remarks (optional)',
                              hintStyle: GoogleFonts.nunitoSans(
                                  fontSize: 12,
                                  color: AppColors.textLight),
                              filled: true,
                              fillColor: AppColors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                            ),
                            style:
                                GoogleFonts.nunitoSans(fontSize: 12),
                          ),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                      _submitting
                          ? 'Submitting…'
                          : 'Submit Marks for All Students',
                      style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  onPressed: _submitting ? null : _submitAll,
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — Result Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ResultSheetTab extends StatefulWidget {
  const _ResultSheetTab();

  @override
  State<_ResultSheetTab> createState() => _ResultSheetTabState();
}

class _ResultSheetTabState extends State<_ResultSheetTab> {
  String? _year;
  String? _className;
  String? _examType;

  List<StudentResult> _results = [];
  bool _loading = false;
  bool _publishing = false;

  Future<void> _load() async {
    if (_year == null || _className == null || _examType == null) {
      _snack('Select year, class and exam type.', AppColors.warning);
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await ResultApiService.getClassResultSheet(
          _className!, _examType!, _year!);
      setState(() => _results = r);
    } catch (e) {
      _snack('Load failed: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      await ResultApiService.publishResults(_className!, _examType!, _year!);
      _snack('Results published & parents notified!', AppColors.success);
      await _load();
    } catch (e) {
      _snack('Publish failed: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Color _rowColor(StudentResult r) {
    if (!r.isPassed) return AppColors.error.withValues(alpha: 0.06);
    if (r.percentage < 50) return AppColors.warning.withValues(alpha: 0.06);
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final unpublished = _results.where((r) => !r.isPublished).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Class Result Sheet'),
        // Filters
        Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              value: _year,
              decoration: _fieldDec('Year'),
              items: _kYears
                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                  .toList(),
              onChanged: (v) => setState(() => _year = v),
            ),
          ),
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<String>(
              value: _className,
              decoration: _fieldDec('Class'),
              items: SchoolConstants.allClasses
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _className = v),
            ),
          ),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              value: _examType,
              decoration: _fieldDec('Exam Type'),
              items: _kExamTypes
                  .map((e) => DropdownMenuItem(
                      value: e, child: Text(_kExamLabels[e]!)))
                  .toList(),
              onChanged: (v) => setState(() => _examType = v),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14)),
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: Text(_loading ? 'Loading…' : 'Load',
                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700)),
            onPressed: _loading ? null : _load,
          ),
          if (_results.isNotEmpty && unpublished > 0)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14)),
              icon: _publishing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.publish_outlined),
              label: Text(
                  _publishing
                      ? 'Publishing…'
                      : 'Publish ($unpublished draft)',
                  style:
                      GoogleFonts.nunitoSans(fontWeight: FontWeight.w700)),
              onPressed: _publishing ? null : _publish,
            ),
        ]),
        const SizedBox(height: 20),
        if (_results.isNotEmpty) ...[
          // Summary strip
          Wrap(spacing: 12, runSpacing: 12, children: [
            _statCard(
                'Total',
                '${_results.map((r) => r.studentId).toSet().length}',
                Icons.people_alt_outlined,
                AppColors.navy),
            _statCard(
                'Class Avg',
                '${(_results.map((r) => r.percentage).reduce((a, b) => a + b) / _results.length).toStringAsFixed(1)} %',
                Icons.trending_up,
                AppColors.info),
            _statCard(
                'Pass',
                '${_results.where((r) => r.isPassed).length}',
                Icons.check_circle_outline,
                AppColors.success),
            _statCard(
                'Fail',
                '${_results.where((r) => !r.isPassed).length}',
                Icons.cancel_outlined,
                AppColors.error),
          ]),
          const SizedBox(height: 16),
          // Table
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(AppColors.navy.withValues(alpha: 0.07)),
                columnSpacing: 18,
                columns: ['Rank', 'Name', 'Roll', 'Subject', 'Marks', '%',
                    'Grade', 'Status', 'Published']
                    .map((h) => DataColumn(
                        label: Text(h,
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700, fontSize: 12))))
                    .toList(),
                rows: _results.map((r) {
                  return DataRow(
                    color: WidgetStateProperty.all(_rowColor(r)),
                    cells: [
                      DataCell(Text('#${r.classRank}',
                          style: GoogleFonts.nunitoSans(
                              fontWeight: FontWeight.w700))),
                      DataCell(Text(r.studentName,
                          style: GoogleFonts.nunitoSans(
                              fontWeight: FontWeight.w600))),
                      DataCell(Text(r.rollNumber ?? '-',
                          style: GoogleFonts.nunitoSans())),
                      DataCell(Text(r.subject,
                          style: GoogleFonts.nunitoSans())),
                      DataCell(Text(
                          '${r.marksObtained.toStringAsFixed(0)}/${r.maxMarks.toStringAsFixed(0)}',
                          style: GoogleFonts.nunitoSans())),
                      DataCell(Text('${r.percentage.toStringAsFixed(1)} %',
                          style: GoogleFonts.nunitoSans(
                              fontWeight: FontWeight.w600,
                              color: r.isPassed
                                  ? AppColors.success
                                  : AppColors.error))),
                      DataCell(_gradeChip(r.grade)),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (r.isPassed
                                  ? AppColors.success
                                  : AppColors.error)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(r.isPassed ? 'PASS' : 'FAIL',
                            style: GoogleFonts.nunitoSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: r.isPassed
                                    ? AppColors.success
                                    : AppColors.error)),
                      )),
                      DataCell(Icon(
                          r.isPublished
                              ? Icons.check_circle
                              : Icons.pending_outlined,
                          size: 16,
                          color: r.isPublished
                              ? AppColors.success
                              : AppColors.textLight)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ] else if (!_loading)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(children: [
                const Icon(Icons.table_chart_outlined,
                    size: 56, color: AppColors.textLight),
                const SizedBox(height: 12),
                Text('Select filters and tap Load to see results.',
                    style: GoogleFonts.nunitoSans(
                        color: AppColors.textSecondary)),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3 — Analytics
// ─────────────────────────────────────────────────────────────────────────────

class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab();

  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  String? _year;
  String? _className;
  String? _examType;
  ClassAnalytics? _analytics;
  bool _loading = false;

  Future<void> _load() async {
    if (_year == null || _className == null) {
      _snack('Select year and class.', AppColors.warning);
      return;
    }
    setState(() => _loading = true);
    try {
      final a = await ResultApiService.getClassAnalytics(_className!, _year!,
          examType: _examType);
      setState(() => _analytics = a);
    } catch (e) {
      _snack('Load failed: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final a = _analytics;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Class Analytics'),
        Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              value: _year,
              decoration: _fieldDec('Year'),
              items: _kYears
                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                  .toList(),
              onChanged: (v) => setState(() => _year = v),
            ),
          ),
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<String>(
              value: _className,
              decoration: _fieldDec('Class'),
              items: SchoolConstants.allClasses
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _className = v),
            ),
          ),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              value: _examType,
              decoration: _fieldDec('Exam (optional)'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('All Exams')),
                ..._kExamTypes.map((e) =>
                    DropdownMenuItem(value: e, child: Text(_kExamLabels[e]!))),
              ],
              onChanged: (v) => setState(() => _examType = v),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14)),
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.analytics_outlined),
            label: Text(_loading ? 'Loading…' : 'Analyse',
                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700)),
            onPressed: _loading ? null : _load,
          ),
        ]),
        const SizedBox(height: 24),
        if (a != null) ...[
          // ── Summary stats ──────────────────────────────────────────────
          Wrap(spacing: 12, runSpacing: 12, children: [
            _statCard('Students', '${a.totalStudents}',
                Icons.people_alt_outlined, AppColors.navy),
            _statCard('Class Avg',
                '${a.classAverage.toStringAsFixed(1)} %',
                Icons.trending_up, AppColors.info),
            _statCard('Highest',
                '${a.highestPercentage.toStringAsFixed(1)} %',
                Icons.emoji_events_outlined, AppColors.gold),
            _statCard('Pass %',
                '${a.passPercentage.toStringAsFixed(1)} %',
                Icons.check_circle_outline, AppColors.success),
          ]),
          const SizedBox(height: 24),

          // ── Subject Heatmap ────────────────────────────────────────────
          if (a.subjectHeatmap.isNotEmpty) ...[
            Text('Subject Performance Heatmap',
                style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.navy)),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                  side: const BorderSide(color: AppColors.border)),
              child: Column(
                children: a.subjectHeatmap.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  final perfColor = switch (s.performance) {
                    'EXCELLENT' => AppColors.success,
                    'GOOD' => AppColors.info,
                    'AVERAGE' => AppColors.warning,
                    _ => AppColors.error,
                  };
                  return Container(
                    decoration: BoxDecoration(
                      color: i.isEven ? AppColors.white : AppColors.creamDark,
                      borderRadius: i == 0
                          ? const BorderRadius.vertical(
                              top: Radius.circular(AppSizes.radiusLG))
                          : i == a.subjectHeatmap.length - 1
                              ? const BorderRadius.vertical(
                                  bottom:
                                      Radius.circular(AppSizes.radiusLG))
                              : BorderRadius.zero,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: perfColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(s.subject,
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w600)),
                      ),
                      // Progress bar
                      SizedBox(
                        width: 120,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: s.classAverage / 100,
                                  backgroundColor:
                                      perfColor.withValues(alpha: 0.15),
                                  valueColor:
                                      AlwaysStoppedAnimation(perfColor),
                                  minHeight: 8,
                                ),
                              ),
                            ]),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 52,
                        child: Text(
                            '${s.classAverage.toStringAsFixed(1)} %',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700,
                                color: perfColor,
                                fontSize: 13)),
                      ),
                      SizedBox(
                        width: 80,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: perfColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(s.performance,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: perfColor)),
                        ),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Recognition Board ──────────────────────────────────────────
          if (a.recognition.isNotEmpty) ...[
            Text('Recognition Board',
                style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.navy)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: a.recognition.map((r) {
                final (icon, color) = switch (r.category) {
                  'CLASS_TOPPER' => (Icons.emoji_events, AppColors.gold),
                  'MOST_IMPROVED' => (Icons.trending_up, AppColors.success),
                  _ => (Icons.verified, AppColors.info),
                };
                final label = switch (r.category) {
                  'CLASS_TOPPER' => 'Class Topper',
                  'MOST_IMPROVED' => 'Most Improved',
                  _ => 'Most Consistent',
                };
                return Container(
                  width: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(icon, color: color, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: GoogleFonts.nunitoSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: color)),
                            Text(r.studentName,
                                style: GoogleFonts.nunitoSans(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            Text(r.detail,
                                style: GoogleFonts.nunitoSans(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ]),
                    ),
                  ]),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // ── At-Risk Students ───────────────────────────────────────────
          if (a.atRiskStudents.isNotEmpty) ...[
            Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text('At-Risk Students (${a.atRiskStudents.length})',
                  style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.error)),
            ]),
            const SizedBox(height: 12),
            ...a.atRiskStudents.map((ar) {
              final isCritical = ar.riskLevel == 'CRITICAL';
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                color: (isCritical ? AppColors.error : AppColors.warning)
                    .withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  side: BorderSide(
                      color: (isCritical
                              ? AppColors.error
                              : AppColors.warning)
                          .withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (isCritical
                            ? AppColors.error
                            : AppColors.warning)
                        .withValues(alpha: 0.15),
                    child: Icon(
                        isCritical
                            ? Icons.dangerous_outlined
                            : Icons.warning_outlined,
                        color: isCritical
                            ? AppColors.error
                            : AppColors.warning,
                        size: 20),
                  ),
                  title: Text(ar.studentName,
                      style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w700)),
                  subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (ar.failedSubjects.isNotEmpty)
                          Text('Failed: ${ar.failedSubjects.join(', ')}',
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 12, color: AppColors.error)),
                        if (ar.droppingSubjects.isNotEmpty)
                          Text(
                              'Declining: ${ar.droppingSubjects.join(', ')}',
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 12, color: AppColors.warning)),
                        Text(
                            'Overall: ${ar.overallPercentage.toStringAsFixed(1)} %',
                            style: GoogleFonts.nunitoSans(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ]),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isCritical ? AppColors.error : AppColors.warning)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(ar.riskLevel,
                        style: GoogleFonts.nunitoSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isCritical
                                ? AppColors.error
                                : AppColors.warning)),
                  ),
                ),
              );
            }),
          ],
        ] else if (!_loading)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(children: [
                const Icon(Icons.bar_chart_outlined,
                    size: 56, color: AppColors.textLight),
                const SizedBox(height: 12),
                Text('Select class and tap Analyse.',
                    style: GoogleFonts.nunitoSans(
                        color: AppColors.textSecondary)),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4 — Report Card
// ─────────────────────────────────────────────────────────────────────────────

class _ReportCardTab extends StatefulWidget {
  const _ReportCardTab();

  @override
  State<_ReportCardTab> createState() => _ReportCardTabState();
}

class _ReportCardTabState extends State<_ReportCardTab> {
  String? _year;
  final _studentIdCtrl = TextEditingController();
  StudentReportCard? _card;
  bool _loading = false;

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_year == null || _studentIdCtrl.text.isEmpty) {
      _snack('Enter academic year and student ID.', AppColors.warning);
      return;
    }
    setState(() => _loading = true);
    try {
      final c = await ResultApiService.getStudentReportCard(
          _studentIdCtrl.text.trim(), _year!);
      setState(() => _card = c);
    } catch (e) {
      _snack('Load failed: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Widget _trendIcon(String trend) {
    return switch (trend) {
      'IMPROVING' =>
        const Icon(Icons.trending_up, color: AppColors.success, size: 16),
      'DECLINING' =>
        const Icon(Icons.trending_down, color: AppColors.error, size: 16),
      _ => const Icon(Icons.trending_flat,
          color: AppColors.textLight, size: 16),
    };
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    // Collect all exam types across all subjects for column headers
    final examTypes = card != null
        ? card.subjects
            .expand((s) => s.examResults.keys)
            .toSet()
            .toList()
          ..sort((a, b) =>
              _kExamTypes.indexOf(a).compareTo(_kExamTypes.indexOf(b)))
        : <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Student Report Card'),
        Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              value: _year,
              decoration: _fieldDec('Academic Year'),
              items: _kYears
                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                  .toList(),
              onChanged: (v) => setState(() => _year = v),
            ),
          ),
          SizedBox(
            width: 260,
            child: TextFormField(
              controller: _studentIdCtrl,
              decoration: _fieldDec('Student ID (MongoDB _id)'),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14)),
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.badge_outlined),
            label: Text(_loading ? 'Loading…' : 'Load Report Card',
                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700)),
            onPressed: _loading ? null : _load,
          ),
        ]),
        const SizedBox(height: 24),
        if (card != null) ...[
          // ── Student Header ─────────────────────────────────────────────
          Card(
            elevation: 0,
            color: AppColors.navy.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                side:
                    BorderSide(color: AppColors.navy.withValues(alpha: 0.15))),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                  child: Text(
                      card.studentName.isNotEmpty
                          ? card.studentName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.cormorantGaramond(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card.studentName,
                            style: GoogleFonts.cormorantGaramond(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy)),
                        Text(
                            '${card.className} · Roll ${card.rollNumber ?? '-'} · ${card.academicYear}',
                            style: GoogleFonts.nunitoSans(
                                color: AppColors.textSecondary)),
                      ]),
                ),
                Column(children: [
                  _gradeChip(card.overallGrade),
                  const SizedBox(height: 4),
                  Text(
                      '${card.cumulativePercentage.toStringAsFixed(1)} %',
                      style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: AppColors.navy)),
                  Text('Class Rank #${card.classRank}',
                      style: GoogleFonts.nunitoSans(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // ── Subject marks table ────────────────────────────────────────
          if (examTypes.isNotEmpty) ...[
            Text('Academic Performance',
                style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.navy)),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                      AppColors.navy.withValues(alpha: 0.07)),
                  columnSpacing: 16,
                  columns: [
                    DataColumn(
                        label: Text('Subject',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700, fontSize: 12))),
                    ...examTypes.map((et) => DataColumn(
                        label: Text(_kExamLabels[et] ?? et,
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700, fontSize: 12)))),
                    DataColumn(
                        label: Text('Cumulative',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700, fontSize: 12))),
                    DataColumn(
                        label: Text('Trend',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700, fontSize: 12))),
                  ],
                  rows: card.subjects.map((sub) {
                    return DataRow(cells: [
                      DataCell(Text(sub.subject,
                          style: GoogleFonts.nunitoSans(
                              fontWeight: FontWeight.w600))),
                      ...examTypes.map((et) {
                        final er = sub.examResults[et];
                        if (er == null) {
                          return const DataCell(Text('-'));
                        }
                        return DataCell(Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${er.marksObtained.toStringAsFixed(0)}/${er.maxMarks.toStringAsFixed(0)}',
                                  style: GoogleFonts.nunitoSans(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              _gradeChip(er.grade),
                            ]));
                      }),
                      DataCell(Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${sub.weightedPercentage.toStringAsFixed(1)} %',
                                style: GoogleFonts.nunitoSans(
                                    fontWeight: FontWeight.w700,
                                    color: sub.weightedPercentage >= 33
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontSize: 13)),
                            _gradeChip(sub.predictedGrade),
                          ])),
                      DataCell(_trendIcon(sub.trend)),
                    ]);
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Co-scholastic ──────────────────────────────────────────────
          if (card.coscholasticTerm1 != null ||
              card.coscholasticTerm2 != null) ...[
            Text('Co-Scholastic Assessment',
                style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.navy)),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final (term, coscho) in [
                ('Term 1', card.coscholasticTerm1),
                ('Term 2', card.coscholasticTerm2),
              ])
                if (coscho != null)
                  SizedBox(
                    width: 300,
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusLG),
                          side: const BorderSide(color: AppColors.border)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(term,
                                  style: GoogleFonts.nunitoSans(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy)),
                              const SizedBox(height: 8),
                              ...coscho.areas.map((area) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 6),
                                    child: Row(children: [
                                      Expanded(
                                          child: Text(area.name,
                                              style: GoogleFonts.nunitoSans(
                                                  fontSize: 13))),
                                      _gradeChip(area.grade),
                                    ]),
                                  )),
                            ]),
                      ),
                    ),
                  ),
            ]),
          ],
        ] else if (!_loading)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(children: [
                const Icon(Icons.badge_outlined,
                    size: 56, color: AppColors.textLight),
                const SizedBox(height: 12),
                Text('Enter student ID and tap Load Report Card.',
                    style: GoogleFonts.nunitoSans(
                        color: AppColors.textSecondary)),
              ]),
            ),
          ),
      ]),
    );
  }
}
