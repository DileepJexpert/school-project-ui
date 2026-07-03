import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../models/result_models.dart';
import '../../../models/student_model.dart';
import '../../../services/result_api_service.dart';

const _examTypes = [
  'UNIT_TEST_1',
  'UNIT_TEST_2',
  'MID_TERM',
  'HALF_YEARLY',
  'ANNUAL',
  'PRE_BOARD',
];

const _examLabels = {
  'UNIT_TEST_1': 'Unit Test 1',
  'UNIT_TEST_2': 'Unit Test 2',
  'MID_TERM': 'Mid Term',
  'HALF_YEARLY': 'Half Yearly',
  'ANNUAL': 'Annual',
  'PRE_BOARD': 'Pre-Board',
};

const _years = ['2024-25', '2025-26', '2026-27'];

class ResultsAdminScreen extends StatefulWidget {
  const ResultsAdminScreen({super.key});

  @override
  State<ResultsAdminScreen> createState() => _ResultsAdminScreenState();
}

class _ResultsAdminScreenState extends State<ResultsAdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

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
    final padding = Responsive.contentPadding(context);

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: context.palette.surface,
              border: Border.all(color: context.palette.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              labelColor: context.palette.brand,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: context.palette.brand,
              labelStyle: GoogleFonts.nunitoSans(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
              tabs: const [
                Tab(icon: Icon(Icons.edit_note_outlined), text: 'Enter Marks'),
                Tab(
                    icon: Icon(Icons.table_chart_outlined),
                    text: 'Result Sheet'),
                Tab(icon: Icon(Icons.analytics_outlined), text: 'Analytics'),
                Tab(icon: Icon(Icons.badge_outlined), text: 'Report Card'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _EnterMarksTab(),
                _ResultSheetTab(),
                _AnalyticsTab(),
                _ReportCardTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: context.palette.heroGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Results',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter marks, publish results, analyze class performance and view report cards.',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          _HeaderPill(label: 'Workflows', value: '4'),
          const SizedBox(width: 8),
          _HeaderPill(label: 'Mode', value: 'Academic'),
        ],
      ),
    );
  }
}

class _EnterMarksTab extends StatefulWidget {
  const _EnterMarksTab();

  @override
  State<_EnterMarksTab> createState() => _EnterMarksTabState();
}

class _EnterMarksTabState extends State<_EnterMarksTab> {
  final _subjectCtrl = TextEditingController();
  final _maxMarksCtrl = TextEditingController(text: '100');
  final Map<String, TextEditingController> _marksCtrls = {};
  final Map<String, TextEditingController> _remarksCtrls = {};

  String? _year = _years[1];
  String? _className;
  String? _examType;
  List<StudentModel> _students = [];
  bool _loading = false;
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _maxMarksCtrl.dispose();
    for (final ctrl in _marksCtrls.values) {
      ctrl.dispose();
    }
    for (final ctrl in _remarksCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  int get _filledCount {
    return _students
        .where((student) =>
            (_marksCtrls[student.id]?.text ?? '').trim().isNotEmpty)
        .length;
  }

  Future<void> _loadStudents() async {
    if (_year == null || _className == null) {
      _snack('Select academic year and class first.', isError: true);
      return;
    }

    setState(() {
      _loading = true;
      _students = [];
    });

    try {
      final students =
          await ResultApiService.getStudentsByClass(_className!, _year!);
      for (final student in students.where((s) => s.id != null)) {
        _marksCtrls.putIfAbsent(student.id!, TextEditingController.new);
        _remarksCtrls.putIfAbsent(student.id!, TextEditingController.new);
      }
      if (!mounted) return;
      setState(() => _students = students.where((s) => s.id != null).toList());
    } catch (e) {
      _snack('Failed to load students: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitAll() async {
    if (_year == null ||
        _className == null ||
        _examType == null ||
        _subjectCtrl.text.trim().isEmpty) {
      _snack('Fill class, exam, subject and year.', isError: true);
      return;
    }
    if (_students.isEmpty) {
      _snack('Load students first.', isError: true);
      return;
    }

    final maxMarks = double.tryParse(_maxMarksCtrl.text.trim()) ?? 100;
    final entries = _students
        .where((student) =>
            student.id != null &&
            (_marksCtrls[student.id]?.text ?? '').trim().isNotEmpty)
        .map((student) {
      final studentId = student.id!;
      return {
        'studentId': studentId,
        'studentName': student.fullName,
        'rollNumber': student.rollNumber ?? '',
        'marksObtained':
            double.tryParse(_marksCtrls[studentId]!.text.trim()) ?? 0.0,
        'teacherRemarks': _remarksCtrls[studentId]?.text.trim() ?? '',
      };
    }).toList();

    if (entries.isEmpty) {
      _snack('Enter at least one mark.', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ResultApiService.bulkSubmitResults(
        className: _className!,
        examType: _examType!,
        academicYear: _year!,
        subject: _subjectCtrl.text.trim(),
        maxMarks: maxMarks,
        enteredBy: 'Admin',
        entries: entries,
      );
      for (final ctrl in _marksCtrls.values) {
        ctrl.clear();
      }
      for (final ctrl in _remarksCtrls.values) {
        ctrl.clear();
      }
      _snack('Marks submitted for ${entries.length} students.');
      setState(() {});
    } catch (e) {
      _snack('Submit failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WorkflowIntro(
            icon: Icons.edit_note_outlined,
            title: 'Enter Class Marks',
            subtitle:
                'Choose class, exam and subject, then enter marks in a compact class grid.',
          ),
          const SizedBox(height: 12),
          _FilterCard(
            children: [
              _YearDropdown(
                  value: _year, onChanged: (v) => setState(() => _year = v)),
              _ClassDropdown(
                value: _className,
                onChanged: (v) => setState(() => _className = v),
              ),
              _ExamDropdown(
                value: _examType,
                onChanged: (v) => setState(() => _examType = v),
              ),
              SizedBox(
                width: 190,
                child: TextField(
                  controller: _subjectCtrl,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
              ),
              SizedBox(
                width: 130,
                child: TextField(
                  controller: _maxMarksCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max marks'),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _loading ? null : _loadStudents,
                icon: _loading
                    ? const _ButtonSpinner()
                    : const Icon(Icons.group_outlined, size: 18),
                label: Text(_loading ? 'Loading...' : 'Load'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MetricsWrap(
            metrics: [
              _MetricData(
                label: 'Students',
                value: _students.length.toString(),
                icon: Icons.people_alt_outlined,
                color: context.palette.brand,
              ),
              _MetricData(
                label: 'Marks entered',
                value: _filledCount.toString(),
                icon: Icons.fact_check_outlined,
                color: AppColors.success,
              ),
              _MetricData(
                label: 'Pending',
                value:
                    (_students.length - _filledCount).clamp(0, 9999).toString(),
                icon: Icons.pending_actions_outlined,
                color: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_students.isEmpty)
            const _StateCard(
              icon: Icons.group_outlined,
              title: 'No class loaded',
              subtitle: 'Select class and academic year, then load students.',
            )
          else
            _MarksEntryList(
              students: _students,
              marksCtrls: _marksCtrls,
              remarksCtrls: _remarksCtrls,
              onChanged: () => setState(() {}),
            ),
          if (_students.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submitAll,
                icon: _submitting
                    ? const _ButtonSpinner()
                    : const Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text(
                    _submitting ? 'Submitting...' : 'Submit entered marks'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultSheetTab extends StatefulWidget {
  const _ResultSheetTab();

  @override
  State<_ResultSheetTab> createState() => _ResultSheetTabState();
}

class _ResultSheetTabState extends State<_ResultSheetTab> {
  String? _year = _years[1];
  String? _className;
  String? _examType;
  List<StudentResult> _results = [];
  bool _loading = false;
  bool _publishing = false;

  int get _studentCount => _results.map((r) => r.studentId).toSet().length;
  int get _unpublishedCount => _results.where((r) => !r.isPublished).length;
  double get _average => _results.isEmpty
      ? 0
      : _results.fold<double>(0, (sum, r) => sum + r.percentage) /
          _results.length;

  Future<void> _load() async {
    if (_year == null || _className == null || _examType == null) {
      _snack('Select year, class and exam type.', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final results = await ResultApiService.getClassResultSheet(
        _className!,
        _examType!,
        _year!,
      );
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      _snack('Load failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _publish() async {
    if (_year == null || _className == null || _examType == null) return;

    setState(() => _publishing = true);
    try {
      await ResultApiService.publishResults(_className!, _examType!, _year!);
      _snack('Results published and parents notified.');
      await _load();
    } catch (e) {
      _snack('Publish failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WorkflowIntro(
            icon: Icons.table_chart_outlined,
            title: 'Result Sheet',
            subtitle:
                'Review class results, identify failures and publish final results.',
          ),
          const SizedBox(height: 12),
          _FilterCard(
            children: [
              _YearDropdown(
                  value: _year, onChanged: (v) => setState(() => _year = v)),
              _ClassDropdown(
                value: _className,
                onChanged: (v) => setState(() => _className = v),
              ),
              _ExamDropdown(
                value: _examType,
                onChanged: (v) => setState(() => _examType = v),
              ),
              ElevatedButton.icon(
                onPressed: _loading ? null : _load,
                icon: _loading
                    ? const _ButtonSpinner()
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(_loading ? 'Loading...' : 'Load'),
              ),
              if (_results.isNotEmpty && _unpublishedCount > 0)
                ElevatedButton.icon(
                  onPressed: _publishing ? null : _publish,
                  icon: _publishing
                      ? const _ButtonSpinner()
                      : const Icon(Icons.publish_outlined, size: 18),
                  label: Text(_publishing
                      ? 'Publishing...'
                      : 'Publish ($_unpublishedCount)'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _MetricsWrap(
            metrics: [
              _MetricData(
                label: 'Students',
                value: _studentCount.toString(),
                icon: Icons.people_alt_outlined,
                color: context.palette.brand,
              ),
              _MetricData(
                label: 'Class average',
                value: '${_average.toStringAsFixed(1)}%',
                icon: Icons.trending_up_rounded,
                color: AppColors.info,
              ),
              _MetricData(
                label: 'Passed rows',
                value: _results.where((r) => r.isPassed).length.toString(),
                icon: Icons.check_circle_outline,
                color: AppColors.success,
              ),
              _MetricData(
                label: 'Failed rows',
                value: _results.where((r) => !r.isPassed).length.toString(),
                icon: Icons.cancel_outlined,
                color: AppColors.error,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_results.isEmpty)
            const _StateCard(
              icon: Icons.table_chart_outlined,
              title: 'No result sheet loaded',
              subtitle: 'Select filters and load the result sheet.',
            )
          else
            _ResultTable(results: _results),
        ],
      ),
    );
  }
}

class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab();

  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  String? _year = _years[1];
  String? _className;
  String? _examType;
  ClassAnalytics? _analytics;
  bool _loading = false;

  Future<void> _load() async {
    if (_year == null || _className == null) {
      _snack('Select year and class.', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final analytics = await ResultApiService.getClassAnalytics(
        _className!,
        _year!,
        examType: _examType,
      );
      if (!mounted) return;
      setState(() => _analytics = analytics);
    } catch (e) {
      _snack('Load failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final analytics = _analytics;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WorkflowIntro(
            icon: Icons.analytics_outlined,
            title: 'Class Analytics',
            subtitle:
                'Understand subject heatmap, recognitions and students needing academic support.',
          ),
          const SizedBox(height: 12),
          _FilterCard(
            children: [
              _YearDropdown(
                  value: _year, onChanged: (v) => setState(() => _year = v)),
              _ClassDropdown(
                value: _className,
                onChanged: (v) => setState(() => _className = v),
              ),
              _ExamDropdown(
                value: _examType,
                includeAll: true,
                onChanged: (v) => setState(() => _examType = v),
              ),
              ElevatedButton.icon(
                onPressed: _loading ? null : _load,
                icon: _loading
                    ? const _ButtonSpinner()
                    : const Icon(Icons.analytics_outlined, size: 18),
                label: Text(_loading ? 'Loading...' : 'Analyze'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (analytics == null)
            const _StateCard(
              icon: Icons.analytics_outlined,
              title: 'No analytics loaded',
              subtitle: 'Select class and load analytics.',
            )
          else
            _AnalyticsContent(analytics: analytics),
        ],
      ),
    );
  }
}

class _ReportCardTab extends StatefulWidget {
  const _ReportCardTab();

  @override
  State<_ReportCardTab> createState() => _ReportCardTabState();
}

class _ReportCardTabState extends State<_ReportCardTab> {
  final _studentIdCtrl = TextEditingController();
  String? _year = _years[1];
  StudentReportCard? _card;
  bool _loading = false;

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_year == null || _studentIdCtrl.text.trim().isEmpty) {
      _snack('Enter academic year and student ID.', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final card = await ResultApiService.getStudentReportCard(
        _studentIdCtrl.text.trim(),
        _year!,
      );
      if (!mounted) return;
      setState(() => _card = card);
    } catch (e) {
      _snack('Load failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WorkflowIntro(
            icon: Icons.badge_outlined,
            title: 'Student Report Card',
            subtitle:
                'Load a student report card by ID and review subject-wise performance.',
          ),
          const SizedBox(height: 12),
          _FilterCard(
            children: [
              _YearDropdown(
                  value: _year, onChanged: (v) => setState(() => _year = v)),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _studentIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Student ID',
                    hintText: 'MongoDB student id',
                    prefixIcon: Icon(Icons.person_search_outlined, size: 19),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _loading ? null : _load,
                icon: _loading
                    ? const _ButtonSpinner()
                    : const Icon(Icons.badge_outlined, size: 18),
                label: Text(_loading ? 'Loading...' : 'Load card'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (card == null)
            const _StateCard(
              icon: Icons.badge_outlined,
              title: 'No report card loaded',
              subtitle: 'Enter a student ID and load the report card.',
            )
          else
            _ReportCardContent(card: card),
        ],
      ),
    );
  }
}

class _MarksEntryList extends StatelessWidget {
  final List<StudentModel> students;
  final Map<String, TextEditingController> marksCtrls;
  final Map<String, TextEditingController> remarksCtrls;
  final VoidCallback onChanged;

  const _MarksEntryList({
    required this.students,
    required this.marksCtrls,
    required this.remarksCtrls,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          for (final indexed in students.indexed)
            _MarksRow(
              index: indexed.$1,
              student: indexed.$2,
              marksCtrl: marksCtrls[indexed.$2.id!]!,
              remarksCtrl: remarksCtrls[indexed.$2.id!]!,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _MarksRow extends StatelessWidget {
  final int index;
  final StudentModel student;
  final TextEditingController marksCtrl;
  final TextEditingController remarksCtrl;
  final VoidCallback onChanged;

  const _MarksRow({
    required this.index,
    required this.student,
    required this.marksCtrl,
    required this.remarksCtrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: index.isEven ? context.palette.surface : context.palette.canvas,
        border: index == 0
            ? null
            : Border(top: BorderSide(color: context.palette.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              student.rollNumber?.isNotEmpty == true
                  ? student.rollNumber!
                  : '${index + 1}',
              style: GoogleFonts.nunitoSans(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              student.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunitoSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: TextField(
              controller: marksCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                hintText: 'Marks',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: remarksCtrl,
              decoration: const InputDecoration(
                hintText: 'Remarks',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTable extends StatelessWidget {
  final List<StudentResult> results;

  const _ResultTable({required this.results});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 18,
          headingRowColor: WidgetStateProperty.all(context.palette.canvas),
          columns: const [
            DataColumn(label: Text('Rank')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Roll')),
            DataColumn(label: Text('Subject')),
            DataColumn(label: Text('Marks')),
            DataColumn(label: Text('%')),
            DataColumn(label: Text('Grade')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Published')),
          ],
          rows: results.map((result) {
            final danger = !result.isPassed;
            return DataRow(
              color: WidgetStateProperty.all(
                danger ? AppColors.error.withValues(alpha: 0.045) : null,
              ),
              cells: [
                DataCell(Text('#${result.classRank}')),
                DataCell(Text(result.studentName)),
                DataCell(Text(result.rollNumber ?? '-')),
                DataCell(Text(result.subject)),
                DataCell(Text(
                  '${result.marksObtained.toStringAsFixed(0)}/${result.maxMarks.toStringAsFixed(0)}',
                )),
                DataCell(Text('${result.percentage.toStringAsFixed(1)}%')),
                DataCell(_GradeChip(grade: result.grade)),
                DataCell(_MiniChip(
                  label: result.isPassed ? 'Pass' : 'Fail',
                  color: result.isPassed ? AppColors.success : AppColors.error,
                )),
                DataCell(Icon(
                  result.isPublished
                      ? Icons.check_circle_rounded
                      : Icons.pending_outlined,
                  size: 18,
                  color: result.isPublished
                      ? AppColors.success
                      : AppColors.textLight,
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _AnalyticsContent extends StatelessWidget {
  final ClassAnalytics analytics;

  const _AnalyticsContent({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricsWrap(
          metrics: [
            _MetricData(
              label: 'Students',
              value: analytics.totalStudents.toString(),
              icon: Icons.people_alt_outlined,
              color: context.palette.brand,
            ),
            _MetricData(
              label: 'Class average',
              value: '${analytics.classAverage.toStringAsFixed(1)}%',
              icon: Icons.trending_up_rounded,
              color: AppColors.info,
            ),
            _MetricData(
              label: 'Highest',
              value: '${analytics.highestPercentage.toStringAsFixed(1)}%',
              icon: Icons.emoji_events_outlined,
              color: AppColors.warning,
            ),
            _MetricData(
              label: 'Pass',
              value: '${analytics.passPercentage.toStringAsFixed(1)}%',
              icon: Icons.check_circle_outline,
              color: AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (analytics.subjectHeatmap.isNotEmpty)
          _SectionBlock(
            title: 'Subject Performance',
            child: Column(
              children: analytics.subjectHeatmap
                  .map((subject) => _SubjectHeatRow(subject: subject))
                  .toList(),
            ),
          ),
        if (analytics.recognition.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionBlock(
            title: 'Recognition Board',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: analytics.recognition
                  .map((entry) => _RecognitionCard(entry: entry))
                  .toList(),
            ),
          ),
        ],
        if (analytics.atRiskStudents.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionBlock(
            title: 'Students Needing Attention',
            child: Column(
              children: analytics.atRiskStudents
                  .map((student) => _RiskRow(student: student))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReportCardContent extends StatelessWidget {
  final StudentReportCard card;

  const _ReportCardContent({required this.card});

  @override
  Widget build(BuildContext context) {
    final examTypes = card.subjects
        .expand((s) => s.examResults.keys)
        .toSet()
        .toList()
      ..sort((a, b) => _examTypes.indexOf(a).compareTo(_examTypes.indexOf(b)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: context.palette.brand.withValues(alpha: 0.1),
                child: Text(
                  card.studentName.isNotEmpty
                      ? card.studentName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: context.palette.brand,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.studentName,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${card.className} | Roll ${card.rollNumber ?? '-'} | ${card.academicYear}',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _GradeChip(grade: card.overallGrade),
                  const SizedBox(height: 4),
                  Text(
                    '${card.cumulativePercentage.toStringAsFixed(1)}%',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: context.palette.brand,
                    ),
                  ),
                  Text(
                    'Rank #${card.classRank}',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (examTypes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionBlock(
            title: 'Academic Performance',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                columns: [
                  const DataColumn(label: Text('Subject')),
                  ...examTypes.map(
                    (exam) => DataColumn(label: Text(_examLabel(exam))),
                  ),
                  const DataColumn(label: Text('Cumulative')),
                  const DataColumn(label: Text('Trend')),
                ],
                rows: card.subjects.map((subject) {
                  return DataRow(
                    cells: [
                      DataCell(Text(subject.subject)),
                      ...examTypes.map((exam) {
                        final result = subject.examResults[exam];
                        if (result == null) return const DataCell(Text('-'));
                        return DataCell(Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${result.marksObtained.toStringAsFixed(0)}/${result.maxMarks.toStringAsFixed(0)}',
                            ),
                            _GradeChip(grade: result.grade),
                          ],
                        ));
                      }),
                      DataCell(Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${subject.weightedPercentage.toStringAsFixed(1)}%'),
                          _GradeChip(grade: subject.predictedGrade),
                        ],
                      )),
                      DataCell(_TrendIcon(trend: subject.trend)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
        if (card.coscholasticTerm1 != null ||
            card.coscholasticTerm2 != null) ...[
          const SizedBox(height: 12),
          _SectionBlock(
            title: 'Co-Scholastic Assessment',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (card.coscholasticTerm1 != null)
                  _CoscholasticCard(
                      title: 'Term 1', assessment: card.coscholasticTerm1!),
                if (card.coscholasticTerm2 != null)
                  _CoscholasticCard(
                      title: 'Term 2', assessment: card.coscholasticTerm2!),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _YearDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _YearDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Year'),
        items: _years
            .map((year) => DropdownMenuItem(value: year, child: Text(year)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _ClassDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _ClassDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Class'),
        items: SchoolConstants.allClasses
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _ExamDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool includeAll;

  const _ExamDropdown({
    required this.value,
    required this.onChanged,
    this.includeAll = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration:
            InputDecoration(labelText: includeAll ? 'Exam' : 'Exam type'),
        items: [
          if (includeAll)
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All exams'),
            ),
          ..._examTypes.map(
            (exam) => DropdownMenuItem(
              value: exam,
              child: Text(_examLabel(exam)),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _WorkflowIntro extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _WorkflowIntro({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.palette.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: context.palette.brand, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  final List<Widget> children;

  const _FilterCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

class _MetricsWrap extends StatelessWidget {
  final List<_MetricData> metrics;

  const _MetricsWrap({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? metrics.length.clamp(1, 4)
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metrics
              .map((metric) => _MetricCard(width: width, data: metric))
              .toList(),
        );
      },
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _MetricCard extends StatelessWidget {
  final double width;
  final _MetricData data;

  const _MetricCard({required this.width, required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _Panel(
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(data.icon, color: data.color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionBlock({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.nunitoSans(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const _Panel({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SubjectHeatRow extends StatelessWidget {
  final SubjectAnalysis subject;

  const _SubjectHeatRow({required this.subject});

  @override
  Widget build(BuildContext context) {
    final color = _performanceColor(subject.performance);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              subject.subject,
              style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            width: 150,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (subject.classAverage / 100).clamp(0, 1),
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: Text(
              '${subject.classAverage.toStringAsFixed(1)}%',
              style: GoogleFonts.nunitoSans(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          _MiniChip(label: subject.performance, color: color),
        ],
      ),
    );
  }
}

class _RecognitionCard extends StatelessWidget {
  final RecognitionEntry entry;

  const _RecognitionCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.category) {
      'CLASS_TOPPER' => AppColors.warning,
      'MOST_IMPROVED' => AppColors.success,
      _ => AppColors.info,
    };

    return SizedBox(
      width: 230,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.22)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.emoji_events_outlined, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    entry.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  final AtRiskStudentInfo student;

  const _RiskRow({required this.student});

  @override
  Widget build(BuildContext context) {
    final critical = student.riskLevel == 'CRITICAL';
    final color = critical ? AppColors.error : AppColors.warning;
    final signals = [
      if (student.failedSubjects.isNotEmpty)
        'Failed: ${student.failedSubjects.join(', ')}',
      if (student.droppingSubjects.isNotEmpty)
        'Declining: ${student.droppingSubjects.join(', ')}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            critical ? Icons.dangerous_outlined : Icons.warning_amber_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.studentName,
                  style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  signals.isEmpty
                      ? 'Overall ${student.overallPercentage.toStringAsFixed(1)}%'
                      : signals.join(' | '),
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _MiniChip(label: student.riskLevel, color: color),
        ],
      ),
    );
  }
}

class _CoscholasticCard extends StatelessWidget {
  final String title;
  final CoscholasticAssessment assessment;

  const _CoscholasticCard({
    required this.title,
    required this.assessment,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.palette.canvas,
          border: Border.all(color: context.palette.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.nunitoSans(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final area in assessment.areas)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(area.name)),
                    _GradeChip(grade: area.grade),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunitoSans(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _GradeChip extends StatelessWidget {
  final String grade;

  const _GradeChip({required this.grade});

  @override
  Widget build(BuildContext context) {
    final label = grade.isEmpty ? '-' : grade;
    final color = _gradeColor(label);
    return _MiniChip(label: label, color: color);
  }
}

class _TrendIcon extends StatelessWidget {
  final String trend;

  const _TrendIcon({required this.trend});

  @override
  Widget build(BuildContext context) {
    return switch (trend) {
      'IMPROVING' => const Icon(Icons.trending_up, color: AppColors.success),
      'DECLINING' => const Icon(Icons.trending_down, color: AppColors.error),
      _ => const Icon(Icons.trending_flat, color: AppColors.textLight),
    };
  }
}

class _HeaderPill extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: GoogleFonts.nunitoSans(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunitoSans(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 34),
        child: Column(
          children: [
            Icon(icon, size: 42, color: AppColors.textLight),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

String _examLabel(String exam) => _examLabels[exam] ?? exam;

Color _performanceColor(String performance) {
  return switch (performance) {
    'EXCELLENT' => AppColors.success,
    'GOOD' => AppColors.info,
    'AVERAGE' => AppColors.warning,
    _ => AppColors.error,
  };
}

Color _gradeColor(String grade) {
  return switch (grade) {
    'A1' => AppColors.success,
    'A2' => const Color(0xFF10B981),
    'B1' => AppColors.info,
    'B2' => const Color(0xFF6366F1),
    'C1' => AppColors.warning,
    'C2' => const Color(0xFFF97316),
    'D' => AppColors.error,
    _ => AppColors.textSecondary,
  };
}
