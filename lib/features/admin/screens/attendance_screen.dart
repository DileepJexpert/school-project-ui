import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/attendance_model.dart';
import '../../../models/student_model.dart';
import '../../../services/attendance_api_service.dart';
import '../../../services/student_api_service.dart';

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
  final _classCtrl    = TextEditingController();
  final _yearCtrl     = TextEditingController(text: '2024-25');
  final _markedByCtrl = TextEditingController(text: 'Admin');
  DateTime _selectedDate = DateTime.now();
  List<StudentModel> _students = [];
  final Map<String, String> _statuses = {};
  bool _loading   = false;
  bool _submitting = false;
  String? _error;
  bool _loaded = false;

  // ── Reports tab state ─────────────────────────────────────────────────
  String? _rClass;
  final _rYearCtrl = TextEditingController(text: '2024-25');
  DateTime _rMonth = DateTime.now();
  List<_StudentSummary> _summaries = [];
  bool _rLoading = false;
  bool _rLoaded  = false;
  String? _rError;

  // ─────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _classCtrl.dispose();
    _yearCtrl.dispose();
    _markedByCtrl.dispose();
    _rYearCtrl.dispose();
    super.dispose();
  }

  // ── Mark tab helpers ──────────────────────────────────────────────────

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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _loadAttendance() async {
    final className = _classCtrl.text.trim();
    if (className.isEmpty) {
      _showSnack('Please enter a class name.', isError: true);
      return;
    }
    setState(() {
      _loading = true;
      _error   = null;
      _loaded  = false;
      _statuses.clear();
    });
    try {
      final allStudents = await StudentApiService.getAllStudents();
      _students = allStudents
          .where((s) =>
              s.classForAdmission?.toLowerCase() == className.toLowerCase())
          .toList();

      final dateStr = _fmtDate(_selectedDate);
      try {
        final existing =
            await AttendanceApiService.getClassAttendance(className, dateStr);
        for (final rec in existing) {
          _statuses[rec.studentId] = rec.status;
        }
      } catch (_) {}

      for (final s in _students) {
        if (s.id != null && !_statuses.containsKey(s.id)) {
          _statuses[s.id!] = 'PRESENT';
        }
      }
      setState(() => _loaded = true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitAttendance() async {
    if (_students.isEmpty) return;
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
        className:    _classCtrl.text.trim(),
        academicYear: _yearCtrl.text.trim(),
        date:         _fmtDate(_selectedDate),
        markedBy:     _markedByCtrl.text.trim(),
        entries:      entries,
      );
      _showSnack('Attendance saved successfully!');
    } catch (e) {
      _showSnack('Failed: $e', isError: true);
    } finally {
      setState(() => _submitting = false);
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attendance',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          Text('Mark and review daily class attendance',
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          // ── Tab bar ───────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.creamDark,
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.nunitoSans(fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Mark Attendance'),
                Tab(text: 'Monthly Report'),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
        const SizedBox(height: 16),
        Expanded(child: _buildMarkBody()),
      ]);

  Widget _buildMarkFilterBar() => Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 160,
                child: TextField(
                    controller: _classCtrl,
                    decoration:
                        _inputDecor('Class Name', Icons.school_outlined)),
              ),
              SizedBox(
                width: 130,
                child: TextField(
                    controller: _yearCtrl,
                    decoration: _inputDecor(
                        'Academic Year', Icons.calendar_today_outlined)),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                    controller: _markedByCtrl,
                    decoration:
                        _inputDecor('Marked By', Icons.person_outline)),
              ),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    color: Colors.white,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.date_range_outlined,
                        size: 18, color: AppColors.navy),
                    const SizedBox(width: 8),
                    Text(_fmtDate(_selectedDate),
                        style: GoogleFonts.nunitoSans(
                            fontSize: 14, color: AppColors.textPrimary)),
                  ]),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _loading ? null : _loadAttendance,
                icon: _loading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 16),
                label: Text(_loading ? 'Loading…' : 'Load Students'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12)),
              ),
            ],
          ),
        ),
      );

  Widget _buildMarkBody() {
    if (_loading) return _buildShimmer();
    if (_error != null) return _buildError(_error!, _loadAttendance);
    if (!_loaded)
      return _buildIdle('Enter a class and date, then tap Load');
    if (_students.isEmpty) return _buildEmpty('"${_classCtrl.text}"');
    return _buildAttendanceList();
  }

  Widget _buildAttendanceList() => Column(children: [
        Row(children: [
          Text(
              '${_students.length} students — ${_fmtDate(_selectedDate)}',
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() {
              for (final s in _students) {
                if (s.id != null) _statuses[s.id!] = 'PRESENT';
              }
            }),
            icon: const Icon(Icons.select_all, size: 16),
            label: const Text('All Present'),
            style: TextButton.styleFrom(foregroundColor: AppColors.success),
          ),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: _students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (ctx, i) {
              final s       = _students[i];
              final current = _statuses[s.id] ?? 'PRESENT';
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusLG)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.navy.withOpacity(0.1),
                      child: Text(
                        s.fullName.isNotEmpty
                            ? s.fullName[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(s.fullName,
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimary))),
                    Wrap(
                      spacing: 6,
                      children: _kStatusColors.entries.map((e) {
                        final active = current == e.key;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _statuses[s.id!] = e.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: active
                                  ? e.value
                                  : e.value.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: active
                                      ? e.value
                                      : e.value.withOpacity(0.3)),
                            ),
                            child: Text(e.key,
                                style: GoogleFonts.nunitoSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: active
                                        ? Colors.white
                                        : e.value)),
                          ),
                        );
                      }).toList(),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submitAttendance,
            icon: _submitting
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(_submitting ? 'Saving…' : 'Mark Attendance',
                style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
            ),
          ),
        ),
      ]);

  // ══════════════════════════════════════════════════════════════════════
  // MONTHLY REPORT TAB
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildReportsTab() => Column(children: [
        _buildReportFilterBar(),
        const SizedBox(height: 16),
        Expanded(child: _buildReportBody()),
      ]);

  Widget _buildReportFilterBar() => Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
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
                width: 130,
                child: TextField(
                    controller: _rYearCtrl,
                    decoration: _inputDecor(
                        'Academic Year', Icons.calendar_today_outlined)),
              ),
              InkWell(
                onTap: _pickMonth,
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    color: Colors.white,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.calendar_month_outlined,
                        size: 18, color: AppColors.navy),
                    const SizedBox(width: 8),
                    Text(_monthLabel(_rMonth),
                        style: GoogleFonts.nunitoSans(
                            fontSize: 14, color: AppColors.textPrimary)),
                  ]),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _rLoading ? null : _loadReport,
                icon: _rLoading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.bar_chart_rounded, size: 16),
                label: Text(_rLoading ? 'Loading…' : 'Load Report'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12)),
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
          'No attendance records found for $_rClass\nin ${_monthLabel(_rMonth)}');
    }
    return _buildSummaryTable();
  }

  Widget _buildSummaryTable() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend + count row
          Row(children: [
            Text('${_summaries.length} students — ${_monthLabel(_rMonth)}',
                style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            _legendDot('≥75%', AppColors.success),
            const SizedBox(width: 10),
            _legendDot('60–74%', AppColors.warning),
            const SizedBox(width: 10),
            _legendDot('<60%', AppColors.error),
          ]),
          const SizedBox(height: 8),
          // Header
          Container(
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              _hCell('Student Name', flex: 3),
              _hCell('P',     flex: 1),
              _hCell('A',     flex: 1),
              _hCell('L',     flex: 1),
              _hCell('HD',    flex: 1),
              _hCell('Days',  flex: 1),
              _hCell('Attendance %', flex: 2),
            ]),
          ),
          const SizedBox(height: 4),
          // Rows
          Expanded(
            child: ListView.builder(
              itemCount: _summaries.length,
              itemBuilder: (ctx, i) {
                final s   = _summaries[i];
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
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    border: Border.all(
                        color: AppColors.border.withOpacity(0.5)),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Expanded(
                      flex: 3,
                      child: Text(s.studentName,
                          style: GoogleFonts.nunitoSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ),
                    _dCell('${s.present}', flex: 1, color: AppColors.success),
                    _dCell('${s.absent}',  flex: 1, color: AppColors.error),
                    _dCell('${s.late}',    flex: 1, color: AppColors.warning),
                    _dCell('${s.halfDay}', flex: 1, color: AppColors.info),
                    _dCell('${s.total}',   flex: 1),
                    Expanded(
                      flex: 2,
                      child: Row(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct / 100,
                              minHeight: 6,
                              backgroundColor: col.withOpacity(0.15),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(col),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${pct.toStringAsFixed(1)}%',
                            style: GoogleFonts.nunitoSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: col)),
                      ]),
                    ),
                  ]),
                );
              },
            ),
          ),
        ],
      );

  // ── Shared widgets ────────────────────────────────────────────────────

  Widget _buildIdle(String message) => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rule_folder_outlined,
                  size: 60,
                  color: AppColors.textLight.withOpacity(0.4)),
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
                  color: AppColors.textLight.withOpacity(0.4)),
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
                borderRadius:
                    BorderRadius.circular(AppSizes.radiusLG)),
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
              ElevatedButton(
                  onPressed: retry, child: const Text('Retry')),
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

  Widget _legendDot(String label, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.nunitoSans(
                fontSize: 11, color: AppColors.textSecondary)),
      ]);

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

  static const _kStatusColors = {
    'PRESENT':  AppColors.success,
    'ABSENT':   AppColors.error,
    'LATE':     AppColors.warning,
    'HALF_DAY': AppColors.info,
  };
}
