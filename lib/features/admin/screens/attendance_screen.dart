import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../models/student_model.dart';
import '../../../services/attendance_api_service.dart';
import '../../../services/student_api_service.dart';

class _StudentSummary {
  final String studentId;
  final String studentName;
  int present = 0;
  int absent = 0;
  int late = 0;
  int halfDay = 0;

  _StudentSummary({required this.studentId, required this.studentName});

  int get total => present + absent + late + halfDay;

  double get percentage => total == 0 ? 0 : (present + late) / total * 100;
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _reportYearCtrl;

  final _markedByCtrl = TextEditingController(text: 'Admin');
  final _monthFmt = DateFormat('MMM yyyy');

  String? _markClass;
  DateTime _selectedDate = DateTime.now();
  List<StudentModel> _students = [];
  final Map<String, String> _statuses = {};
  bool _loading = false;
  bool _submitting = false;
  String? _error;
  bool _loaded = false;

  String? _reportClass;
  DateTime _reportMonth = DateTime.now();
  List<_StudentSummary> _summaries = [];
  bool _reportLoading = false;
  bool _reportLoaded = false;
  String? _reportError;

  static const _statusColors = {
    'PRESENT': AppColors.success,
    'ABSENT': AppColors.error,
    'LATE': AppColors.warning,
    'HALF_DAY': AppColors.info,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _dateCtrl = TextEditingController(text: _fmtDate(_selectedDate));
    _yearCtrl = TextEditingController(text: _currentAcademicYear());
    _reportYearCtrl = TextEditingController(text: _currentAcademicYear());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dateCtrl.dispose();
    _yearCtrl.dispose();
    _reportYearCtrl.dispose();
    _markedByCtrl.dispose();
    super.dispose();
  }

  String _currentAcademicYear() {
    final now = DateTime.now();
    final start = now.month >= 4 ? now.year : now.year - 1;
    final end = (start + 1).toString().substring(2);
    return '$start-$end';
  }

  String _fmtDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final picked =
        await _pickCalendarDate(_selectedDate, helpText: 'Select date');
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _dateCtrl.text = _fmtDate(picked);
      _loaded = false;
      _students = [];
      _statuses.clear();
    });
  }

  Future<void> _pickReportMonth() async {
    final picked =
        await _pickCalendarDate(_reportMonth, helpText: 'Select report month');
    if (picked == null) return;
    setState(() => _reportMonth = DateTime(picked.year, picked.month));
  }

  Future<DateTime?> _pickCalendarDate(DateTime initial,
      {required String helpText}) {
    return showDatePicker(
      context: context,
      initialDate: initial.isAfter(DateTime.now()) ? DateTime.now() : initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: helpText,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: context.palette.brand,
                surface: context.palette.surface,
              ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
            child: child!,
          ),
        ),
      ),
    );
  }

  Future<void> _loadAttendance() async {
    final className = _markClass;
    if (className == null || className.isEmpty) {
      _snack('Please select a class.', isError: true);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _loaded = false;
      _students = [];
      _statuses.clear();
    });

    try {
      final allStudents = await StudentApiService.getAllStudents();
      final students = allStudents
          .where((student) =>
              student.classForAdmission?.toLowerCase() ==
              className.toLowerCase())
          .toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));

      final statuses = <String, String>{};
      try {
        final existing = await AttendanceApiService.getClassAttendance(
          className,
          _fmtDate(_selectedDate),
        );
        for (final record in existing) {
          statuses[record.studentId] = record.status;
        }
      } catch (_) {
        // Existing attendance may not exist yet for the selected date.
      }

      for (final student in students) {
        final id = student.id;
        if (id != null && !statuses.containsKey(id)) {
          statuses[id] = 'PRESENT';
        }
      }

      if (!mounted) return;
      setState(() {
        _students = students;
        _statuses
          ..clear()
          ..addAll(statuses);
        _loaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitAttendance() async {
    if (_students.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final entries = _students
          .where((student) => student.id != null)
          .map((student) => {
                'studentId': student.id!,
                'studentName': student.fullName,
                'status': _statuses[student.id] ?? 'PRESENT',
                'remarks': '',
              })
          .toList();

      await AttendanceApiService.markBulkAttendance(
        className: _markClass ?? '',
        academicYear: _yearCtrl.text.trim(),
        date: _fmtDate(_selectedDate),
        markedBy: _markedByCtrl.text.trim(),
        entries: entries,
      );
      _snack('Attendance saved.');
    } catch (e) {
      _snack('Failed to save attendance: $e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _loadReport() async {
    final className = _reportClass;
    if (className == null || className.isEmpty) {
      _snack('Please select a class.', isError: true);
      return;
    }
    setState(() {
      _reportLoading = true;
      _reportError = null;
      _reportLoaded = false;
      _summaries.clear();
    });
    try {
      final from = DateTime(_reportMonth.year, _reportMonth.month, 1);
      final to = DateTime(_reportMonth.year, _reportMonth.month + 1, 0);
      final records = await AttendanceApiService.getClassAttendanceRange(
        className,
        _reportYearCtrl.text.trim(),
        _fmtDate(from),
        _fmtDate(to),
      );

      final byStudent = <String, _StudentSummary>{};
      for (final record in records) {
        final summary = byStudent.putIfAbsent(
          record.studentId,
          () => _StudentSummary(
            studentId: record.studentId,
            studentName: record.studentName,
          ),
        );
        switch (record.status) {
          case 'PRESENT':
            summary.present++;
          case 'ABSENT':
            summary.absent++;
          case 'LATE':
            summary.late++;
          case 'HALF_DAY':
            summary.halfDay++;
        }
      }
      final summaries = byStudent.values.toList()
        ..sort((a, b) => a.studentName.compareTo(b.studentName));

      if (!mounted) return;
      setState(() {
        _summaries = summaries;
        _reportLoaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _reportError = e.toString());
    } finally {
      if (mounted) setState(() => _reportLoading = false);
    }
  }

  void _setAll(String status) {
    setState(() {
      for (final student in _students) {
        final id = student.id;
        if (id != null) _statuses[id] = status;
      }
    });
  }

  int _countStatus(String status) =>
      _statuses.values.where((value) => value == status).length;

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
    return Padding(
      padding: EdgeInsets.all(
        Responsive.isMobile(context) ? AppSizes.paddingMD : AppSizes.paddingLG,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdminPageHeader(
          title: 'Attendance',
          subtitle:
              'Mark daily attendance quickly and review class attendance health.',
          icon: Icons.rule_folder_outlined,
          actions: [
            if (_loaded && _students.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _setAll('PRESENT'),
                icon: const Icon(Icons.done_all_rounded, size: 17),
                label: const Text('All Present'),
              ),
            if (_loaded && _students.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _submitting ? null : _submitAttendance,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 17),
                label: Text(_submitting ? 'Saving' : 'Save'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _tabBar(),
        const SizedBox(height: 14),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_markTab(), _reportTab()],
          ),
        ),
      ]),
    );
  }

  Widget _tabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        border: Border.all(color: context.palette.border),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: context.palette.brand,
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: GoogleFonts.nunitoSans(
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'Mark Attendance'),
          Tab(text: 'Monthly Report'),
        ],
      ),
    );
  }

  Widget _markTab() {
    return Column(children: [
      _markFilterBar(),
      const SizedBox(height: 12),
      if (_loaded) ...[
        _statusSummary(),
        const SizedBox(height: 12),
      ],
      Expanded(child: _markBody()),
    ]);
  }

  Widget _markFilterBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _markClass,
                decoration: _inputDecoration('Class', Icons.school_outlined),
                isExpanded: true,
                items: SchoolConstants.allClasses
                    .map((className) => DropdownMenuItem(
                          value: className,
                          child: Text(className),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _markClass = value;
                    _loaded = false;
                    _students = [];
                    _statuses.clear();
                  });
                },
              ),
            ),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _yearCtrl,
                decoration:
                    _inputDecoration('Academic year', Icons.event_outlined),
              ),
            ),
            SizedBox(
              width: 160,
              child: TextField(
                readOnly: true,
                controller: _dateCtrl,
                onTap: _pickDate,
                decoration: _inputDecoration('Date', Icons.date_range_outlined),
              ),
            ),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _markedByCtrl,
                decoration: _inputDecoration('Marked by', Icons.person_outline),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _loading ? null : _loadAttendance,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 17),
              label: Text(_loading ? 'Loading' : 'Load Students'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusSummary() {
    final total = _students.length;
    final present = _countStatus('PRESENT');
    final absent = _countStatus('ABSENT');
    final late = _countStatus('LATE');
    final halfDay = _countStatus('HALF_DAY');
    final presentRate = total == 0 ? 0.0 : (present + late) / total;
    final cards = [
      _MiniStat(
          'Students', '$total', Icons.groups_outlined, context.palette.brand),
      _MiniStat(
          'Present', '$present', Icons.check_circle_outline, AppColors.success),
      _MiniStat('Absent', '$absent', Icons.cancel_outlined, AppColors.error),
      _MiniStat('Late/Half', '${late + halfDay}', Icons.schedule_outlined,
          AppColors.warning),
      _MiniStat('Rate', '${(presentRate * 100).toStringAsFixed(0)}%',
          Icons.trending_up_rounded, AppColors.info),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 900 ? 5 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards
            .map((card) => SizedBox(width: width, child: _miniStatCard(card)))
            .toList(),
      );
    });
  }

  Widget _miniStatCard(_MiniStat stat) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            ),
            child: Icon(stat.icon, color: stat.color, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                stat.value,
                style: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                stat.label,
                style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _markBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _errorState(_error!, _loadAttendance);
    if (!_loaded) {
      return _emptyState(
        icon: Icons.rule_folder_outlined,
        title: 'Load attendance list',
        subtitle: 'Select class and date, then load students.',
      );
    }
    if (_students.isEmpty) {
      return _emptyState(
        icon: Icons.person_search_outlined,
        title: 'No students found',
        subtitle:
            'No active students were found for ${_markClass ?? 'this class'}.',
      );
    }
    return Column(children: [
      Row(children: [
        Expanded(
          child: Text(
            '${_students.length} students - ${_fmtDate(_selectedDate)}',
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => _setAll('PRESENT'),
          icon: const Icon(Icons.done_all_rounded, size: 16),
          label: const Text('All Present'),
        ),
      ]),
      const SizedBox(height: 8),
      Expanded(
        child: ListView.separated(
          itemCount: _students.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, index) => _studentAttendanceRow(_students[index]),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _submitting ? null : _submitAttendance,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(_submitting ? 'Saving Attendance' : 'Save Attendance'),
        ),
      ),
    ]);
  }

  Widget _studentAttendanceRow(StudentModel student) {
    final id = student.id;
    final current = id == null ? 'PRESENT' : _statuses[id] ?? 'PRESENT';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: context.palette.brand.withValues(alpha: 0.1),
            child: Text(
              student.fullName.isNotEmpty
                  ? student.fullName.substring(0, 1).toUpperCase()
                  : '?',
              style: GoogleFonts.nunitoSans(
                color: context.palette.brand,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                student.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                [
                  if ((student.rollNumber ?? '').isNotEmpty)
                    'Roll ${student.rollNumber}',
                  student.classForAdmission ?? '',
                ].where((item) => item.isNotEmpty).join(' - '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _statusColors.entries.map((entry) {
              final selected = current == entry.key;
              return InkWell(
                onTap: id == null
                    ? null
                    : () => setState(() => _statuses[id] = entry.key),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? entry.value
                        : entry.value.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? entry.value
                          : entry.value.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    _statusLabel(entry.key),
                    style: GoogleFonts.nunitoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white : entry.value,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }

  Widget _reportTab() {
    return Column(children: [
      _reportFilterBar(),
      const SizedBox(height: 12),
      Expanded(child: _reportBody()),
    ]);
  }

  Widget _reportFilterBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _reportClass,
                decoration: _inputDecoration('Class', Icons.school_outlined),
                isExpanded: true,
                items: SchoolConstants.allClasses
                    .map((className) => DropdownMenuItem(
                          value: className,
                          child: Text(className),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _reportClass = value),
              ),
            ),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _reportYearCtrl,
                decoration:
                    _inputDecoration('Academic year', Icons.event_outlined),
              ),
            ),
            InkWell(
              onTap: _pickReportMonth,
              borderRadius: BorderRadius.circular(AppSizes.radiusSM),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: context.palette.canvas,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSM),
                  border: Border.all(color: context.palette.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.calendar_month_outlined,
                      size: 17, color: context.palette.brand),
                  const SizedBox(width: 7),
                  Text(
                    _monthFmt.format(_reportMonth),
                    style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ]),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _reportLoading ? null : _loadReport,
              icon: _reportLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.bar_chart_rounded, size: 17),
              label: Text(_reportLoading ? 'Loading' : 'Load Report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportBody() {
    if (_reportLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reportError != null) {
      return _errorState(_reportError!, _loadReport);
    }
    if (!_reportLoaded) {
      return _emptyState(
        icon: Icons.analytics_outlined,
        title: 'Load monthly report',
        subtitle: 'Select class and month to review attendance patterns.',
      );
    }
    if (_summaries.isEmpty) {
      return _emptyState(
        icon: Icons.inbox_outlined,
        title: 'No records found',
        subtitle:
            'No attendance records for ${_reportClass ?? 'this class'} in ${_monthFmt.format(_reportMonth)}.',
      );
    }

    final avg = _summaries.fold<double>(
          0,
          (sum, item) => sum + item.percentage,
        ) /
        _summaries.length;
    final atRisk = _summaries.where((item) => item.percentage < 75).length;

    return Column(children: [
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth > 720 ? 3 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        final cards = [
          _MiniStat('Students', '${_summaries.length}', Icons.groups_outlined,
              context.palette.brand),
          _MiniStat(
              'Average',
              '${avg.toStringAsFixed(1)}%',
              Icons.trending_up_rounded,
              avg >= 75 ? AppColors.success : AppColors.warning),
          _MiniStat('Below 75%', '$atRisk', Icons.warning_amber_rounded,
              atRisk == 0 ? AppColors.success : AppColors.error),
        ];
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards
              .map((card) => SizedBox(width: width, child: _miniStatCard(card)))
              .toList(),
        );
      }),
      const SizedBox(height: 12),
      Expanded(
        child: ListView.separated(
          itemCount: _summaries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, index) => _summaryRow(_summaries[index]),
        ),
      ),
    ]);
  }

  Widget _summaryRow(_StudentSummary summary) {
    final percent = summary.percentage;
    final color = percent >= 75
        ? AppColors.success
        : percent >= 60
            ? AppColors.warning
            : AppColors.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                summary.studentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: GoogleFonts.nunitoSans(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0, 1),
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _countChip('P', summary.present, AppColors.success),
            _countChip('A', summary.absent, AppColors.error),
            _countChip('L', summary.late, AppColors.warning),
            _countChip('HD', summary.halfDay, AppColors.info),
            _countChip('Days', summary.total, AppColors.textSecondary),
          ]),
        ]),
      ),
    );
  }

  Widget _countChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
      ),
      child: Text(
        '$label $value',
        style: GoogleFonts.nunitoSans(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 52, color: AppColors.textLight.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text(
          title,
          style: GoogleFonts.nunitoSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _errorState(String error, VoidCallback retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 48),
          const SizedBox(height: 12),
          Text(
            'Could not load attendance',
            style: GoogleFonts.nunitoSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Retry'),
          ),
        ]),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      isDense: true,
      fillColor: context.palette.canvas,
    );
  }

  String _statusLabel(String status) => switch (status) {
        'PRESENT' => 'Present',
        'ABSENT' => 'Absent',
        'LATE' => 'Late',
        'HALF_DAY' => 'Half',
        _ => status,
      };
}

class _MiniStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat(this.label, this.value, this.icon, this.color);
}
