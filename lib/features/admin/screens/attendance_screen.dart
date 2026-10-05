import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/academic_year.dart';
import '../../../models/student_model.dart';
import '../../../services/attendance_api_service.dart';
import '../../../services/student_api_service.dart';
import '../../../services/csv_export_service.dart';

// ── Per-student monthly summary (local only) ───────────────────────────────
class _StudentSummary {
  final String studentId;
  final String studentName;
  int present = 0;
  int absent  = 0;
  int late    = 0;
  int halfDay = 0;

  _StudentSummary({required this.studentId, required this.studentName});

  int    get total      => present + absent + late + halfDay;
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

  // ── Mark tab state ────────────────────────────────────────────────────
  String? _markClass;
  final _yearCtrl     = TextEditingController(text: AcademicYear.currentShort());
  late final TextEditingController _dateCtrl;
  final _markedByCtrl = TextEditingController(text: 'Admin');
  final _markSearchCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<StudentModel> _students = [];
  final Map<String, String> _statuses = {};
  bool _loading   = false;
  bool _submitting = false;
  String? _error;
  bool _loaded = false;
  String? _loadedClass;
  String? _loadedYear;
  String? _loadedDate;
  int _markLoadGeneration = 0;
  String _statusFilter = 'ALL'; // ALL, PRESENT, ABSENT, LATE, HALF_DAY

  bool get _canSubmitMark =>
      _loaded &&
      !_loading &&
      !_submitting &&
      _students.isNotEmpty &&
      _loadedClass == _markClass &&
      _loadedYear == _yearCtrl.text.trim() &&
      _loadedDate == _fmtDate(_selectedDate);

  // ── Reports tab state ─────────────────────────────────────────────────
  String? _rClass;
  final _rYearCtrl = TextEditingController(text: AcademicYear.currentShort());
  final _reportSearchCtrl = TextEditingController();
  DateTime _rMonth = DateTime.now();
  List<_StudentSummary> _summaries = [];
  bool _rLoading = false;
  bool _rLoaded  = false;
  String? _rError;
  String _reportFilter = 'ALL'; // ALL, AT_RISK, CRITICAL, GOOD

  // ─────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _dateCtrl = TextEditingController(text: _fmtDate(_selectedDate));
    _yearCtrl.addListener(_onMarkYearChanged);
    _markSearchCtrl.addListener(() => setState(() {}));
    _reportSearchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _yearCtrl.removeListener(_onMarkYearChanged);
    _yearCtrl.dispose();
    _dateCtrl.dispose();
    _markedByCtrl.dispose();
    _markSearchCtrl.dispose();
    _rYearCtrl.dispose();
    _reportSearchCtrl.dispose();
    super.dispose();
  }

  // ── Mark tab helpers ──────────────────────────────────────────────────

  void _invalidateMarkData() {
    _markLoadGeneration++;
    _students = [];
    _statuses.clear();
    _loaded = false;
    _loadedClass = null;
    _loadedYear = null;
    _loadedDate = null;
    _loading = false;
    _error = null;
    _statusFilter = 'ALL';
    _markSearchCtrl.clear();
  }

  void _onMarkYearChanged() => setState(_invalidateMarkData);

  void _setToday() {
    final now = DateTime.now();
    if (!DateUtils.isSameDay(_selectedDate, now)) {
      setState(() {
        _selectedDate = now;
        _dateCtrl.text = _fmtDate(now);
        _invalidateMarkData();
      });
    }
  }

  void _setYesterday() {
    final yest = DateTime.now().subtract(const Duration(days: 1));
    if (!DateUtils.isSameDay(_selectedDate, yest)) {
      setState(() {
        _selectedDate = yest;
        _dateCtrl.text = _fmtDate(yest);
        _invalidateMarkData();
      });
    }
  }

  void _prevDay() {
    final prev = _selectedDate.subtract(const Duration(days: 1));
    setState(() {
      _selectedDate = prev;
      _dateCtrl.text = _fmtDate(prev);
      _invalidateMarkData();
    });
  }

  void _nextDay() {
    final next = _selectedDate.add(const Duration(days: 1));
    if (next.isAfter(DateTime.now())) return;
    setState(() {
      _selectedDate = next;
      _dateCtrl.text = _fmtDate(next);
      _invalidateMarkData();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.navy, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (!mounted) return;
    if (picked != null && !DateUtils.isSameDay(picked, _selectedDate)) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = _fmtDate(picked);
        _invalidateMarkData();
      });
    }
  }

  Future<void> _loadAttendance() async {
    final className = _markClass;
    if (className == null || className.isEmpty) {
      _showSnack('Please select a class.', isError: true);
      return;
    }
    final academicYear = _yearCtrl.text.trim();
    if (academicYear.isEmpty) {
      _showSnack('Please enter an academic year.', isError: true);
      return;
    }
    final dateStr = _fmtDate(_selectedDate);
    final generation = ++_markLoadGeneration;
    setState(() {
      _loading = true;
      _error   = null;
      _loaded  = false;
      _loadedClass = null;
      _loadedYear = null;
      _loadedDate = null;
      _students = [];
      _statuses.clear();
    });
    try {
      final allStudents = await StudentApiService.getAllStudents();
      final students = allStudents
          .where((s) =>
              s.classForAdmission?.toLowerCase() == className.toLowerCase())
          .toList();
      students.sort((a, b) {
        final rA = int.tryParse(a.rollNumber ?? '');
        final rB = int.tryParse(b.rollNumber ?? '');
        if (rA != null && rB != null) return rA.compareTo(rB);
        if (rA != null) return -1;
        if (rB != null) return 1;
        return a.fullName.compareTo(b.fullName);
      });
      // A failed read must not turn a previously marked class into all-present.
      final existing =
          await AttendanceApiService.getClassAttendance(className, dateStr);
      if (!mounted || generation != _markLoadGeneration) return;

      final statuses = <String, String>{
        for (final rec in existing) rec.studentId: rec.status,
      };
      for (final s in students) {
        if (s.id != null && !statuses.containsKey(s.id)) {
          statuses[s.id!] = 'PRESENT';
        }
      }
      setState(() {
        _students = students;
        _statuses.addAll(statuses);
        _loadedClass = className;
        _loadedYear = academicYear;
        _loadedDate = dateStr;
        _loaded = true;
      });
    } catch (e) {
      if (mounted && generation == _markLoadGeneration) {
        setState(() => _error = 'Could not load attendance: $e');
      }
    } finally {
      if (mounted && generation == _markLoadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  void _markAll(String status) {
    setState(() {
      for (final s in _students) {
        if (s.id != null) _statuses[s.id!] = status;
      }
    });
    _showSnack(
      status == 'PRESENT'
          ? 'Marked all students as Present'
          : 'Marked all students as Absent',
    );
  }

  List<StudentModel> get _filteredStudents {
    final q = _markSearchCtrl.text.trim().toLowerCase();
    return _students.where((s) {
      if (_statusFilter != 'ALL') {
        final current = _statuses[s.id] ?? 'PRESENT';
        if (current != _statusFilter) return false;
      }
      if (q.isNotEmpty) {
        final nameMatch = s.fullName.toLowerCase().contains(q);
        final rollMatch = s.rollNumber?.toLowerCase().contains(q) ?? false;
        final admMatch = s.admissionNumber?.toLowerCase().contains(q) ?? false;
        if (!nameMatch && !rollMatch && !admMatch) return false;
      }
      return true;
    }).toList();
  }

  int get _presentCount =>
      _students.where((s) => (_statuses[s.id] ?? 'PRESENT') == 'PRESENT').length;
  int get _absentCount =>
      _students.where((s) => _statuses[s.id] == 'ABSENT').length;
  int get _lateCount =>
      _students.where((s) => _statuses[s.id] == 'LATE').length;
  int get _halfDayCount =>
      _students.where((s) => _statuses[s.id] == 'HALF_DAY').length;
  double get _attendancePercentage => _students.isEmpty
      ? 0.0
      : ((_presentCount + _lateCount) / _students.length * 100);

  Future<void> _submitAttendance() async {
    if (!_canSubmitMark) {
      _showSnack('Load this class and date before saving.', isError: true);
      return;
    }
    final className = _loadedClass!;
    final academicYear = _loadedYear!;
    final dateStr = _loadedDate!;
    setState(() => _submitting = true);
    try {
      final entries = _students
          .where((s) => s.id != null)
          .map((s) => {
                'studentId':   s.id!,
                'studentName': s.fullName,
                'status':      _statuses[s.id] ?? 'PRESENT',
                'remarks':     '',
              })
          .toList();

      await AttendanceApiService.markBulkAttendance(
        className:    className,
        academicYear: academicYear,
        date:         dateStr,
        markedBy:     _markedByCtrl.text.trim(),
        entries:      entries,
      );
      if (mounted) _showSnack('Attendance saved successfully!');
    } catch (e) {
      if (mounted) _showSnack('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Reports tab helpers ───────────────────────────────────────────────

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _rMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select any day in the target month',
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.navy, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _rMonth = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _loadReport() async {
    if (_rClass == null) {
      _showSnack('Please select a class.', isError: true);
      return;
    }
    setState(() {
      _rLoading = true;
      _rError   = null;
      _rLoaded  = false;
      _summaries.clear();
    });
    try {
      final from = DateTime(_rMonth.year, _rMonth.month, 1);
      // last day of month: month+1, day 0 rolls back to last day of month
      final to   = DateTime(_rMonth.year, _rMonth.month + 1, 0);

      final records = await AttendanceApiService.getClassAttendanceRange(
        _rClass!,
        _rYearCtrl.text.trim(),
        _fmtDate(from),
        _fmtDate(to),
      );

      final Map<String, _StudentSummary> map = {};
      for (final r in records) {
        final s = map.putIfAbsent(
          r.studentId,
          () => _StudentSummary(
              studentId: r.studentId, studentName: r.studentName),
        );
        switch (r.status) {
          case 'PRESENT':  s.present++;  break;
          case 'ABSENT':   s.absent++;   break;
          case 'LATE':     s.late++;     break;
          case 'HALF_DAY': s.halfDay++;  break;
        }
      }
      _summaries = map.values.toList()
        ..sort((a, b) => a.studentName.compareTo(b.studentName));

      setState(() => _rLoaded = true);
    } catch (e) {
      setState(() => _rError = e.toString());
    } finally {
      setState(() => _rLoading = false);
    }
  }

  void _prevMonth() {
    setState(() {
      _rMonth = DateTime(_rMonth.year, _rMonth.month - 1);
    });
    _loadReport();
  }

  void _nextMonth() {
    final next = DateTime(_rMonth.year, _rMonth.month + 1);
    if (next.isAfter(DateTime.now())) return;
    setState(() {
      _rMonth = next;
    });
    _loadReport();
  }

  List<_StudentSummary> get _filteredSummaries {
    final q = _reportSearchCtrl.text.trim().toLowerCase();
    return _summaries.where((s) {
      final pct = s.percentage;
      if (_reportFilter == 'AT_RISK' && pct >= 75) return false;
      if (_reportFilter == 'CRITICAL' && pct >= 60) return false;
      if (_reportFilter == 'GOOD' && pct < 75) return false;
      if (q.isNotEmpty && !s.studentName.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  int get _reportAtRiskCount =>
      _summaries.where((s) => s.percentage < 75 && s.percentage >= 60).length;
  int get _reportCriticalCount =>
      _summaries.where((s) => s.percentage < 60).length;
  int get _reportGoodCount =>
      _summaries.where((s) => s.percentage >= 75).length;
  double get _reportAvgPercentage => _summaries.isEmpty
      ? 0.0
      : _summaries.fold<double>(0.0, (acc, s) => acc + s.percentage) /
          _summaries.length;

  void _exportReportCsv() {
    if (_summaries.isEmpty) return;
    final headers = [
      'Student Name',
      'Present Days',
      'Absent Days',
      'Late Days',
      'Half Days',
      'Total Working Days',
      'Attendance Percentage',
      'Health Status',
    ];
    final rows = _summaries.map((s) => [
      s.studentName,
      s.present.toString(),
      s.absent.toString(),
      s.late.toString(),
      s.halfDay.toString(),
      s.total.toString(),
      '${s.percentage.toStringAsFixed(1)}%',
      s.percentage >= 75
          ? 'Regular (>=75%)'
          : s.percentage >= 60
              ? 'Warning (60-74%)'
              : 'Defaulter (<60%)',
    ]).toList();

    final cls = (_rClass ?? 'Class').replaceAll(' ', '_');
    final mStr = _monthLabel(_rMonth).replaceAll(' ', '_');
    CsvExportService.exportCustomCsv(
      filename: 'Attendance_${cls}_$mStr.csv',
      headers: headers,
      rows: rows,
    );
    _showSnack('Exported monthly attendance CSV.');
  }

  // ── Shared helpers ────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _monthLabel(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${m[d.month - 1]} ${d.year}';
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunitoSans()),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Attendance Hub',
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy)),
                    Text(
                        'Mark daily class attendance, track live percentages, and analyze monthly trends',
                        style: GoogleFonts.nunitoSans(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── Tab bar ───────────────────────────────────────────────────
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.creamDark,
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              border: Border.all(color: AppColors.border, width: 0.8),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(AppSizes.radiusLG - 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w600, fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fact_check_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Daily Attendance Marking'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assessment_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Monthly Class Reports'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildMarkTab(), _buildReportsTab()],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // MARK ATTENDANCE TAB
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildMarkTab() => Column(children: [
        _buildMarkFilterBar(),
        const SizedBox(height: 12),
        Expanded(child: _buildMarkBody()),
      ]);

  Widget _buildMarkFilterBar() => Card(
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
          side: const BorderSide(color: AppColors.border, width: 0.8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      value: _markClass,
                      decoration:
                          _inputDecor('Select Class', Icons.school_outlined),
                      isExpanded: true,
                      items: SchoolConstants.allClasses
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    style: GoogleFonts.nunitoSans(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _markClass = v;
                        _invalidateMarkData();
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _yearCtrl,
                      decoration: _inputDecor(
                          'Academic Year', Icons.calendar_today_outlined),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _markedByCtrl,
                      decoration:
                          _inputDecor('Marked By', Icons.person_outline),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _loadAttendance,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_rounded, size: 16),
                    label: Text(_loading ? 'Loading…' : 'Load Class'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 0.6, color: AppColors.border),
              const SizedBox(height: 10),
              // Date picker row with quick day chips
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 20),
                        tooltip: 'Previous Day',
                        visualDensity: VisualDensity.compact,
                        onPressed: _prevDay,
                      ),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.navy.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.navy.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_month_outlined,
                                  size: 15, color: AppColors.navy),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('EEE, dd MMM yyyy')
                                    .format(_selectedDate),
                                style: GoogleFonts.nunitoSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppColors.navy),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 20),
                        tooltip: 'Next Day',
                        visualDensity: VisualDensity.compact,
                        onPressed:
                            DateUtils.isSameDay(_selectedDate, DateTime.now())
                                ? null
                                : _nextDay,
                      ),
                    ],
                  ),
                  _dateChip(
                    label: 'Today',
                    selected: DateUtils.isSameDay(_selectedDate, DateTime.now()),
                    onTap: _setToday,
                  ),
                  _dateChip(
                    label: 'Yesterday',
                    selected: DateUtils.isSameDay(
                      _selectedDate,
                      DateTime.now().subtract(const Duration(days: 1)),
                    ),
                    onTap: _setYesterday,
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _dateChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.navy : AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunitoSans(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMarkBody() {
    if (_loading) return _buildShimmer();
    if (_error != null) return _buildError(_error!, _loadAttendance);
    if (!_loaded) {
      return _buildIdle('Select a class and date, then tap Load Class');
    }
    if (_students.isEmpty) return _buildEmpty('"${_markClass ?? ''}"');
    return _buildAttendanceList();
  }

  Widget _buildAttendanceList() {
    final filtered = _filteredStudents;
    final total = _students.length;
    final pct = _attendancePercentage;
    final pctColor = pct >= 75
        ? AppColors.success
        : pct >= 60
            ? AppColors.warning
            : AppColors.error;

    return Column(
      children: [
        // ── Real-time KPI Stats Banner ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            border: Border.all(color: AppColors.border, width: 0.8),
          ),
          child: LayoutBuilder(builder: (ctx, constraints) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _kpiPill(
                  label: 'Present',
                  count: _presentCount,
                  color: AppColors.success,
                  icon: Icons.check_circle_rounded,
                  active: _statusFilter == 'PRESENT',
                  onTap: () => setState(() => _statusFilter =
                      _statusFilter == 'PRESENT' ? 'ALL' : 'PRESENT'),
                ),
                _kpiPill(
                  label: 'Absent',
                  count: _absentCount,
                  color: AppColors.error,
                  icon: Icons.cancel_rounded,
                  active: _statusFilter == 'ABSENT',
                  onTap: () => setState(() => _statusFilter =
                      _statusFilter == 'ABSENT' ? 'ALL' : 'ABSENT'),
                ),
                _kpiPill(
                  label: 'Late',
                  count: _lateCount,
                  color: AppColors.warning,
                  icon: Icons.schedule_rounded,
                  active: _statusFilter == 'LATE',
                  onTap: () => setState(() => _statusFilter =
                      _statusFilter == 'LATE' ? 'ALL' : 'LATE'),
                ),
                _kpiPill(
                  label: 'Half Day',
                  count: _halfDayCount,
                  color: AppColors.info,
                  icon: Icons.timelapse_rounded,
                  active: _statusFilter == 'HALF_DAY',
                  onTap: () => setState(() => _statusFilter =
                      _statusFilter == 'HALF_DAY' ? 'ALL' : 'HALF_DAY'),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: pctColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: pctColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pie_chart_rounded, size: 16, color: pctColor),
                      const SizedBox(width: 6),
                      Text(
                        '${pct.toStringAsFixed(1)}% Attendance Rate',
                        style: GoogleFonts.nunitoSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: pctColor),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: 10),

        // ── Search & Batch Quick Action Bar ────────────────────────────
        Row(
          children: [
            Expanded(
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _markSearchCtrl,
                  style: GoogleFonts.nunitoSans(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by student name, roll number, admission number…',
                    hintStyle: GoogleFonts.nunitoSans(
                        color: AppColors.textLight, fontSize: 12),
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: AppColors.textLight),
                    suffixIcon: _markSearchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => _markSearchCtrl.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => _markAll('PRESENT'),
              icon: const Icon(Icons.done_all_rounded,
                  size: 16, color: AppColors.success),
              label: Text('All Present',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: AppColors.success.withValues(alpha: 0.5)),
                backgroundColor: AppColors.success.withValues(alpha: 0.06),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
              ),
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              onPressed: () => _markAll('ABSENT'),
              icon: const Icon(Icons.close_rounded,
                  size: 16, color: AppColors.error),
              label: Text('All Absent',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                backgroundColor: AppColors.error.withValues(alpha: 0.05),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Filter Chips Bar ───────────────────────────────────────────
        Row(
          children: [
            Text(
              'Showing ${filtered.length} of $total students',
              style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
            if (_statusFilter != 'ALL') ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Filtered: $_statusFilter',
                        style: GoogleFonts.nunitoSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy)),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => setState(() => _statusFilter = 'ALL'),
                      child: const Icon(Icons.close,
                          size: 12, color: AppColors.navy),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),

        // ── Students List ──────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 48,
                          color: AppColors.textLight.withValues(alpha: 0.6)),
                      const SizedBox(height: 10),
                      Text('No students match the current filter',
                          style: GoogleFonts.nunitoSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      TextButton(
                        onPressed: () {
                          _markSearchCtrl.clear();
                          setState(() => _statusFilter = 'ALL');
                        },
                        child: const Text('Reset Filters'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, i) {
                    final s = filtered[i];
                    final current = _statuses[s.id] ?? 'PRESENT';
                    return Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusLG),
                        side: const BorderSide(
                            color: AppColors.border, width: 0.8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  AppColors.navy.withValues(alpha: 0.1),
                              child: Text(
                                s.fullName.isNotEmpty
                                    ? s.fullName[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.cormorantGaramond(
                                    fontSize: 17,
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
                                    s.fullName,
                                    style: GoogleFonts.nunitoSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 3),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (s.rollNumber != null &&
                                          s.rollNumber!.trim().isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6366F1)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'Roll #${s.rollNumber}',
                                            style: GoogleFonts.nunitoSans(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    const Color(0xFF6366F1)),
                                          ),
                                        ),
                                      if (s.admissionNumber != null &&
                                          s.admissionNumber!.trim().isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: AppColors.gold
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'Adm: ${s.admissionNumber}',
                                            style: GoogleFonts.nunitoSans(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.gold),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Segmented Status Selector
                            Wrap(
                              spacing: 5,
                              children: [
                                _statusToggleButton(
                                  label: 'P',
                                  tooltip: 'Present',
                                  color: AppColors.success,
                                  active: current == 'PRESENT',
                                  onTap: () => setState(
                                      () => _statuses[s.id!] = 'PRESENT'),
                                ),
                                _statusToggleButton(
                                  label: 'A',
                                  tooltip: 'Absent',
                                  color: AppColors.error,
                                  active: current == 'ABSENT',
                                  onTap: () => setState(
                                      () => _statuses[s.id!] = 'ABSENT'),
                                ),
                                _statusToggleButton(
                                  label: 'L',
                                  tooltip: 'Late',
                                  color: AppColors.warning,
                                  active: current == 'LATE',
                                  onTap: () => setState(
                                      () => _statuses[s.id!] = 'LATE'),
                                ),
                                _statusToggleButton(
                                  label: 'HD',
                                  tooltip: 'Half Day',
                                  color: AppColors.info,
                                  active: current == 'HALF_DAY',
                                  onTap: () => setState(
                                      () => _statuses[s.id!] = 'HALF_DAY'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 10),

        // ── Bottom Sticky Bar ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Total: $total  •  $_presentCount Present  •  $_absentCount Absent  •  $_lateCount Late',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _canSubmitMark ? _submitAttendance : null,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline_rounded,
                        size: 18),
                label: Text(_submitting ? 'Saving…' : 'Save Attendance',
                    style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMD)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kpiPill({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? color
              : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              '$count $label',
              style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusToggleButton({
    required String label,
    required String tooltip,
    required Color color,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 34,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? color : color.withValues(alpha: 0.3),
              width: active ? 1.5 : 1.0,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.nunitoSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // MONTHLY REPORT TAB
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildReportsTab() => Column(children: [
        _buildReportFilterBar(),
        const SizedBox(height: 12),
        Expanded(child: _buildReportBody()),
      ]);

  Widget _buildReportFilterBar() => Card(
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
          side: const BorderSide(color: AppColors.border, width: 0.8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: _rClass,
                  decoration:
                      _inputDecor('Select Class', Icons.school_outlined),
                  isExpanded: true,
                  items: SchoolConstants.allClasses
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c,
                                style: GoogleFonts.nunitoSans(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _rClass = v),
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _rYearCtrl,
                  decoration: _inputDecor(
                      'Academic Year', Icons.calendar_today_outlined),
                ),
              ),
              // Month selector with prev/next buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    tooltip: 'Previous Month',
                    visualDensity: VisualDensity.compact,
                    onPressed: _prevMonth,
                  ),
                  InkWell(
                    onTap: _pickMonth,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                        color: Colors.white,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month_outlined,
                              size: 16, color: AppColors.navy),
                          const SizedBox(width: 8),
                          Text(_monthLabel(_rMonth),
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    tooltip: 'Next Month',
                    visualDensity: VisualDensity.compact,
                    onPressed: DateTime(_rMonth.year, _rMonth.month + 1)
                            .isAfter(DateTime.now())
                        ? null
                        : _nextMonth,
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _rLoading ? null : _loadReport,
                icon: _rLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.bar_chart_rounded, size: 16),
                label: Text(_rLoading ? 'Loading…' : 'Load Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMD)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildReportBody() {
    if (_rLoading) return _buildShimmer();
    if (_rError != null) return _buildError(_rError!, _loadReport);
    if (!_rLoaded) {
      return _buildIdle('Select class and month, then tap Load Report');
    }
    if (_summaries.isEmpty) {
      return _buildIdle(
          'No attendance records found for ${_rClass ?? ''}\nin ${_monthLabel(_rMonth)}');
    }
    return _buildSummaryTable();
  }

  Widget _buildSummaryTable() {
    final filtered = _filteredSummaries;
    final total = _summaries.length;
    final avgPct = _reportAvgPercentage;
    final atRisk = _reportAtRiskCount;
    final critical = _reportCriticalCount;
    final good = _reportGoodCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Monthly KPI Overview Cards ─────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            border: Border.all(color: AppColors.border, width: 0.8),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _metricBadge(
                label: 'Enrolled',
                value: '$total',
                color: AppColors.navy,
                icon: Icons.people_outline,
              ),
              _metricBadge(
                label: 'Class Avg',
                value: '${avgPct.toStringAsFixed(1)}%',
                color: avgPct >= 75 ? AppColors.success : AppColors.warning,
                icon: Icons.analytics_outlined,
              ),
              _metricBadge(
                label: 'Regular (≥75%)',
                value: '$good',
                color: AppColors.success,
                icon: Icons.check_circle_outline_rounded,
              ),
              _metricBadge(
                label: 'At Risk (<75%)',
                value: '$atRisk',
                color: AppColors.warning,
                icon: Icons.warning_amber_rounded,
              ),
              _metricBadge(
                label: 'Critical (<60%)',
                value: '$critical',
                color: AppColors.error,
                icon: Icons.error_outline_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── Controls: Search, Filter Chips, Export CSV ─────────────────
        Row(
          children: [
            Expanded(
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _reportSearchCtrl,
                  style: GoogleFonts.nunitoSans(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Filter by student name…',
                    hintStyle: GoogleFonts.nunitoSans(
                        color: AppColors.textLight, fontSize: 12),
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: AppColors.textLight),
                    suffixIcon: _reportSearchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => _reportSearchCtrl.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _exportReportCsv,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Export CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Filter Chips Bar ───────────────────────────────────────────
        Row(
          children: [
            _reportFilterChip('ALL', 'All ($total)'),
            const SizedBox(width: 6),
            _reportFilterChip('GOOD', 'Good ≥75% ($good)',
                color: AppColors.success),
            const SizedBox(width: 6),
            _reportFilterChip('AT_RISK', 'At Risk <75% ($atRisk)',
                color: AppColors.warning),
            const SizedBox(width: 6),
            _reportFilterChip('CRITICAL', 'Critical <60% ($critical)',
                color: AppColors.error),
          ],
        ),
        const SizedBox(height: 8),

        // ── Table Header ───────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            _hCell('Student Name', flex: 3),
            _hCell('P', flex: 1),
            _hCell('A', flex: 1),
            _hCell('L', flex: 1),
            _hCell('HD', flex: 1),
            _hCell('Days', flex: 1),
            _hCell('Attendance %', flex: 3),
          ]),
        ),
        const SizedBox(height: 4),

        // ── Table Rows ─────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('No students match the selected filter',
                      style: GoogleFonts.nunitoSans(
                          color: AppColors.textSecondary, fontSize: 13)),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final s = filtered[i];
                    final pct = s.percentage;
                    final col = pct >= 75
                        ? AppColors.success
                        : pct >= 60
                            ? AppColors.warning
                            : AppColors.error;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: i.isEven ? Colors.white : AppColors.creamDark,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMD),
                        border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.6)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      child: Row(children: [
                        Expanded(
                          flex: 3,
                          child: Text(s.studentName,
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                        ),
                        _dCell('${s.present}',
                            flex: 1, color: AppColors.success),
                        _dCell('${s.absent}', flex: 1, color: AppColors.error),
                        _dCell('${s.late}',
                            flex: 1, color: AppColors.warning),
                        _dCell('${s.halfDay}', flex: 1, color: AppColors.info),
                        _dCell('${s.total}', flex: 1),
                        Expanded(
                          flex: 3,
                          child: Row(children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct / 100,
                                  minHeight: 6,
                                  backgroundColor:
                                      col.withValues(alpha: 0.15),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(col),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: col.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${pct.toStringAsFixed(1)}%',
                                style: GoogleFonts.nunitoSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: col),
                              ),
                            ),
                          ]),
                        ),
                      ]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _reportFilterChip(String value, String label, {Color? color}) {
    final active = _reportFilter == value;
    final c = color ?? AppColors.navy;
    return InkWell(
      onTap: () => setState(() => _reportFilter = value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? c : c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: active ? c : c.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunitoSans(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? Colors.white : c,
          ),
        ),
      ),
    );
  }

  Widget _metricBadge({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: GoogleFonts.nunitoSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────

  Widget _buildIdle(String message) => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rule_folder_outlined,
                  size: 60,
                  color: AppColors.textLight.withValues(alpha: 0.4)),
              const SizedBox(height: 14),
              Text(message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary, fontSize: 14)),
            ]),
      );

  Widget _buildEmpty(String className) => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search_outlined,
                  size: 60,
                  color: AppColors.textLight.withValues(alpha: 0.4)),
              const SizedBox(height: 14),
              Text('No students in $className',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy)),
              const SizedBox(height: 6),
              Text('Admit students with this class name first.',
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary, fontSize: 13)),
            ]),
      );

  Widget _buildShimmer() => Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        child: ListView.builder(
          itemCount: 6,
          itemBuilder: (_, __) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 48,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
          ),
        ),
      );

  Widget _buildError(String error, VoidCallback retry) => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppColors.error, size: 52),
              const SizedBox(height: 12),
              Text('Failed to load',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error)),
              const SizedBox(height: 6),
              Text(error,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: retry, child: const Text('Retry')),
            ]),
      );

  // ── Table cell helpers ────────────────────────────────────────────────

  Widget _hCell(String text, {int flex = 1}) => Expanded(
        flex: flex,
        child: Text(text,
            style: GoogleFonts.nunitoSans(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      );

  Widget _dCell(String text, {int flex = 1, Color? color}) => Expanded(
        flex: flex,
        child: Text(text,
            style: GoogleFonts.nunitoSans(
                fontSize: 13, color: color ?? AppColors.textPrimary)),
      );

  InputDecoration _inputDecor(String hint, IconData icon) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.nunitoSans(color: AppColors.textLight, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: AppColors.navy),
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
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        isDense: true,
      );
}
