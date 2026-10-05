import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../services/staff_api_service.dart';

class StaffAttendanceScreen extends StatefulWidget {
  const StaffAttendanceScreen({super.key});

  @override
  State<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  List<dynamic> _staffList = [];
  List<dynamic> _attendanceRecords = [];
  final Map<String, String> _statusMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final results = await Future.wait([
        StaffApiService.getAllStaff(),
        StaffApiService.getStaffAttendanceByDate(dateStr),
      ]);
      if (mounted) {
        _staffList = results[0];
        _attendanceRecords = results[1];
        _statusMap.clear();
        for (final record in _attendanceRecords) {
          final r = record as Map<String, dynamic>;
          _statusMap[r['staffId'] as String] = r['status'] as String? ?? 'PRESENT';
        }
        for (final staff in _staffList) {
          final s = staff as Map<String, dynamic>;
          _statusMap.putIfAbsent(s['id'] as String, () => 'PRESENT');
        }
        setState(() {});
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveAttendance() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final records = _staffList.map((s) {
      final staff = s as Map<String, dynamic>;
      final staffId = staff['id'] as String;
      return {
        'staffId': staffId,
        'staffName': staff['fullName'] ?? '',
        'date': dateStr,
        'status': _statusMap[staffId] ?? 'PRESENT',
      };
    }).toList();

    try {
      await StaffApiService.markStaffAttendance(records);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  int get _presentCount => _statusMap.values.where((v) => v == 'PRESENT').length;
  int get _absentCount => _statusMap.values.where((v) => v == 'ABSENT').length;
  int get _lateCount => _statusMap.values.where((v) => v == 'LATE' || v == 'HALF_DAY').length;

  void _markAll(String status) {
    setState(() {
      for (final staff in _staffList) {
        final id = (staff as Map<String, dynamic>)['id'] as String;
        _statusMap[id] = status;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date & Save Bar
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _loadData();
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.navy),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd MMM yyyy').format(_selectedDate),
                            style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.navy),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _markAll('PRESENT'),
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text('All Present'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: AppColors.navy),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onPressed: _loading ? null : _saveAttendance,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text('Save Attendance',
                        style: GoogleFonts.nunitoSans(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // KPI Strip
          _buildKpiStrip(),
          const SizedBox(height: 16),

          // Staff Attendance Table
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_staffList.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('No staff found.', style: GoogleFonts.nunitoSans(color: AppColors.textSecondary)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _staffList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final staff = _staffList[index] as Map<String, dynamic>;
                final staffId = staff['id'] as String;
                final name = staff['fullName'] as String? ?? '';
                final dept = staff['department'] as String? ?? '';
                final desig = staff['designation'] as String? ?? '';
                final currentStatus = _statusMap[staffId] ?? 'PRESENT';

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.navy)),
                            Text('$desig · $dept', style: GoogleFonts.nunitoSans(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      _statusButton(staffId, 'PRESENT', 'P', AppColors.success, currentStatus == 'PRESENT'),
                      const SizedBox(width: 4),
                      _statusButton(staffId, 'ABSENT', 'A', AppColors.error, currentStatus == 'ABSENT'),
                      const SizedBox(width: 4),
                      _statusButton(staffId, 'LATE', 'L', AppColors.warning, currentStatus == 'LATE'),
                      const SizedBox(width: 4),
                      _statusButton(staffId, 'HALF_DAY', 'HD', AppColors.info, currentStatus == 'HALF_DAY'),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildKpiStrip() {
    return LayoutBuilder(builder: (context, constraints) {
      final isCompact = constraints.maxWidth < 700;
      final kpis = [
        _kpiItem('Total Staff', '${_staffList.length}', Icons.groups_outlined, AppColors.navy),
        _kpiItem('Present', '$_presentCount', Icons.check_circle_outline, AppColors.success),
        _kpiItem('Absent', '$_absentCount', Icons.cancel_outlined, AppColors.error),
        _kpiItem('Late / Half-Day', '$_lateCount', Icons.watch_later_outlined, AppColors.warning),
      ];

      if (isCompact) {
        return Wrap(spacing: 8, runSpacing: 8, children: kpis.map((k) => SizedBox(width: (constraints.maxWidth - 8) / 2, child: k)).toList());
      }
      return Row(children: kpis.map((k) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: k))).toList());
    });
  }

  Widget _kpiItem(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(val, style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
                Text(title, style: GoogleFonts.nunitoSans(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusButton(String staffId, String statusValue, String label, Color color, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _statusMap[staffId] = statusValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.nunitoSans(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}
