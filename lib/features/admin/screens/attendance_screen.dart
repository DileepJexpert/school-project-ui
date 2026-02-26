import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/attendance_model.dart';
import '../../../models/student_model.dart';
import '../../../services/attendance_api_service.dart';
import '../../../services/student_api_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _classCtrl = TextEditingController();
  final _yearCtrl = TextEditingController(text: '2024-25');
  final _markedByCtrl = TextEditingController(text: 'Admin');

  DateTime _selectedDate = DateTime.now();
  List<StudentModel> _students = [];
  // studentId → status
  final Map<String, String> _statuses = {};
  bool _loading = false;
  bool _submitting = false;
  String? _error;
  bool _loaded = false;

  @override
  void dispose() {
    _classCtrl.dispose();
    _yearCtrl.dispose();
    _markedByCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme:
              const ColorScheme.light(primary: AppColors.navy, onPrimary: Colors.white),
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
      _error = null;
      _loaded = false;
      _statuses.clear();
    });
    try {
      // Load all students and filter by class
      final allStudents = await StudentApiService.getAllStudents();
      _students = allStudents
          .where((s) =>
              s.classForAdmission?.toLowerCase() ==
              className.toLowerCase())
          .toList();

      // Pre-fill with any already-marked attendance
      final dateStr = _formatDate(_selectedDate);
      try {
        final existing =
            await AttendanceApiService.getClassAttendance(className, dateStr);
        for (final rec in existing) {
          _statuses[rec.studentId] = rec.status;
        }
      } catch (_) {
        // No existing records — that's fine
      }

      // Default unmarked students to PRESENT
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
                'studentId': s.id!,
                'studentName': s.fullName,
                'status': _statuses[s.id] ?? 'PRESENT',
                'remarks': '',
              })
          .toList();

      await AttendanceApiService.markBulkAttendance(
        className: _classCtrl.text.trim(),
        academicYear: _yearCtrl.text.trim(),
        date: _formatDate(_selectedDate),
        markedBy: _markedByCtrl.text.trim(),
        entries: entries,
      );
      _showSnack('Attendance saved successfully!');
    } catch (e) {
      _showSnack('Failed: $e', isError: true);
    } finally {
      setState(() => _submitting = false);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunitoSans()),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

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
          Text('Mark daily attendance for a class',
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          _buildFilterBar(),
          const SizedBox(height: 16),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
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
                decoration: _inputDecor('Class Name', Icons.school_outlined),
              ),
            ),
            SizedBox(
              width: 130,
              child: TextField(
                controller: _yearCtrl,
                decoration: _inputDecor('Academic Year', Icons.calendar_today_outlined),
              ),
            ),
            SizedBox(
              width: 160,
              child: TextField(
                controller: _markedByCtrl,
                decoration: _inputDecor('Marked By', Icons.person_outline),
              ),
            ),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  color: Colors.white,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.date_range_outlined,
                      size: 18, color: AppColors.navy),
                  const SizedBox(width: 8),
                  Text(_formatDate(_selectedDate),
                      style: GoogleFonts.nunitoSans(
                          fontSize: 14, color: AppColors.textPrimary)),
                ]),
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
  }

  InputDecoration _inputDecor(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunitoSans(
            color: AppColors.textLight, fontSize: 13),
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

  Widget _buildBody() {
    if (_loading) return _buildShimmer();
    if (_error != null) return _buildError();
    if (!_loaded) return _buildIdle();
    if (_students.isEmpty) return _buildEmpty();
    return _buildAttendanceList();
  }

  Widget _buildIdle() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.rule_folder_outlined,
              size: 60, color: AppColors.textLight.withOpacity(0.4)),
          const SizedBox(height: 14),
          Text('Enter a class and date, then tap Load',
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 14)),
        ]),
      );

  Widget _buildEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.person_search_outlined,
              size: 60, color: AppColors.textLight.withOpacity(0.4)),
          const SizedBox(height: 14),
          Text('No students in "${_classCtrl.text}"',
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
            height: 68,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
          ),
        ),
      );

  Widget _buildError() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off_rounded,
              color: AppColors.error, size: 52),
          const SizedBox(height: 12),
          Text('Failed to load',
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
              onPressed: _loadAttendance, child: const Text('Retry')),
        ]),
      );

  Widget _buildAttendanceList() {
    return Column(
      children: [
        // Summary row
        Row(children: [
          Text('${_students.length} students — ${_formatDate(_selectedDate)}',
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              setState(() {
                for (final s in _students) {
                  if (s.id != null) _statuses[s.id!] = 'PRESENT';
                }
              });
            },
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
              final s = _students[i];
              final current = _statuses[s.id] ?? 'PRESENT';
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
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
                      children: _statusOptions.entries.map((e) {
                        final isActive = current == e.key;
                        return GestureDetector(
                          onTap: () => setState(
                              () => _statuses[s.id!] = e.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? e.value
                                  : e.value.withOpacity(0.08),
                              borderRadius:
                                  BorderRadius.circular(20),
                              border: Border.all(
                                  color: isActive
                                      ? e.value
                                      : e.value.withOpacity(0.3)),
                            ),
                            child: Text(e.key,
                                style: GoogleFonts.nunitoSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isActive
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
                    width: 18,
                    height: 18,
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
      ],
    );
  }

  static const _statusOptions = {
    'PRESENT': AppColors.success,
    'ABSENT': AppColors.error,
    'LATE': AppColors.warning,
    'HALF_DAY': AppColors.info,
  };
}
