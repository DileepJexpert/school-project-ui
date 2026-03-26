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
        _staffList = results[0] as List<dynamic>;
        _attendanceRecords = results[1] as List<dynamic>;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
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
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Text(
                          DateFormat('dd MMM yyyy').format(_selectedDate),
                          style: GoogleFonts.poppins(fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: _loading ? null : _saveAttendance,
                icon: const Icon(Icons.save, size: 18),
                label: Text('Save',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _staffList.isEmpty
                  ? Center(
                      child: Text('No staff found.',
                          style: GoogleFonts.poppins(
                              color: AppColors.textSecondary)))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _staffList.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final staff =
                            _staffList[index] as Map<String, dynamic>;
                        final staffId = staff['id'] as String;
                        final name = staff['fullName'] as String? ?? '';
                        final currentStatus =
                            _statusMap[staffId] ?? 'PRESENT';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.navy.withOpacity(0.1),
                            child: Text(
                                name.isNotEmpty ? name[0] : '?',
                                style: const TextStyle(
                                    color: AppColors.navy)),
                          ),
                          title: Text(name,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500)),
                          trailing: DropdownButton<String>(
                            value: currentStatus,
                            underline: const SizedBox(),
                            items: ['PRESENT', 'ABSENT', 'LATE', 'HALF_DAY']
                                .map((s) => DropdownMenuItem(
                                    value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(
                                    () => _statusMap[staffId] = v);
                              }
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
