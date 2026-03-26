import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/student_portal_api_service.dart';

class MyAttendanceScreen extends StatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  State<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends State<MyAttendanceScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _records = [];
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        StudentPortalApiService.getMyAttendance(),
        StudentPortalApiService.getMyAttendanceSummary(),
      ]);
      if (mounted) {
        setState(() {
          _records = results[0] as List<dynamic>;
          _summary = results[1] as Map<String, dynamic>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load attendance: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: Text(_error!, style: GoogleFonts.poppins(color: Colors.red)));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Attendance',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 16),
          if (_summary != null) _buildSummaryCards(),
          const SizedBox(height: 24),
          Text('Records',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (_records.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                    child: Text('No attendance records found.',
                        style: GoogleFonts.poppins(
                            color: AppColors.textSecondary))),
              ),
            )
          else
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _records.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final record = _records[index] as Map<String, dynamic>;
                  final date = record['date'] as String? ?? '';
                  final status = record['status'] as String? ?? '';
                  return ListTile(
                    leading: _statusIcon(status),
                    title: Text(date, style: GoogleFonts.poppins(fontSize: 14)),
                    trailing: Chip(
                      label: Text(status,
                          style: GoogleFonts.poppins(fontSize: 12)),
                      backgroundColor: _statusColor(status).withOpacity(0.1),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final present = (_summary?['presentDays'] as num?)?.toInt() ?? 0;
    final absent = (_summary?['absentDays'] as num?)?.toInt() ?? 0;
    final total = (_summary?['totalDays'] as num?)?.toInt() ?? 0;
    final pct = (_summary?['attendancePercentage'] as num?)?.toDouble() ?? 0;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _summaryCard('Present', '$present', Colors.green),
        _summaryCard('Absent', '$absent', Colors.red),
        _summaryCard('Total', '$total', AppColors.navy),
        _summaryCard('Percentage', '${pct.toStringAsFixed(1)}%',
            pct >= 75 ? Colors.green : Colors.red),
      ],
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Icon _statusIcon(String status) {
    return switch (status.toUpperCase()) {
      'PRESENT' => const Icon(Icons.check_circle, color: Colors.green, size: 20),
      'ABSENT' => const Icon(Icons.cancel, color: Colors.red, size: 20),
      'LATE' => const Icon(Icons.watch_later, color: Colors.orange, size: 20),
      'HALF_DAY' =>
        const Icon(Icons.timelapse, color: Colors.deepOrange, size: 20),
      _ => const Icon(Icons.circle, color: Colors.grey, size: 20),
    };
  }

  Color _statusColor(String status) {
    return switch (status.toUpperCase()) {
      'PRESENT' => Colors.green,
      'ABSENT' => Colors.red,
      'LATE' => Colors.orange,
      'HALF_DAY' => Colors.deepOrange,
      _ => Colors.grey,
    };
  }
}
