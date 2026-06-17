import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/student_portal_api_service.dart';

class StudentExamScheduleScreen extends StatefulWidget {
  const StudentExamScheduleScreen({super.key});

  @override
  State<StudentExamScheduleScreen> createState() =>
      _StudentExamScheduleScreenState();
}

class _StudentExamScheduleScreenState extends State<StudentExamScheduleScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _schedules = [];

  late String _selectedYear;
  late final List<String> _yearOptions;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final currentYear = now.month >= 4 ? now.year : now.year - 1;
    _yearOptions = [
      '${currentYear + 1}-${currentYear + 2}',
      '$currentYear-${currentYear + 1}',
      '${currentYear - 1}-$currentYear',
    ];
    _selectedYear = _yearOptions[1];
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await StudentPortalApiService.getMyExamSchedule(_selectedYear);
      if (mounted) setState(() => _schedules = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Year selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('Exam Schedule',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              const Spacer(),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  value: _selectedYear,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textPrimary),
                  items: _yearOptions
                      .map((y) =>
                          DropdownMenuItem(value: y, child: Text(y)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedYear = v);
                      _loadSchedules();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        // Content
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text('Failed to load exam schedule',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.error)),
            const SizedBox(height: 8),
            TextButton(
                onPressed: _loadSchedules, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_schedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No exam schedules available',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('Published schedules will appear here.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textLight)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSchedules,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _schedules.length,
        itemBuilder: (_, i) => _buildScheduleCard(_schedules[i]),
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final examName = schedule['examName'] as String? ?? 'Exam';
    final examType = schedule['examType'] as String? ?? '';
    final status = schedule['status'] as String? ?? '';
    final slots = (schedule['examSlots'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    final typeLabel = switch (examType) {
      'UNIT_TEST' => 'Unit Test',
      'MID_TERM' => 'Mid Term',
      'FINAL' => 'Final',
      'PRACTICAL' => 'Practical',
      _ => examType,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(examName,
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy)),
                ),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(typeLabel,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gold)),
            ),
            if (slots.isNotEmpty) ...[
              const SizedBox(height: 14),
              // Table of exam slots
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1),
                },
                border: TableBorder.all(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(8)),
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: AppColors.navy.withOpacity(0.05),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8)),
                    ),
                    children: [
                      _header('Subject'),
                      _header('Date'),
                      _header('Time'),
                      _header('Room'),
                    ],
                  ),
                  ...slots.map((slot) {
                    final dateStr = slot['date'] as String? ?? '-';
                    String formattedDate = dateStr;
                    final parsed = DateTime.tryParse(dateStr);
                    if (parsed != null) {
                      formattedDate = DateFormat('dd MMM').format(parsed);
                    }
                    final start = slot['startTime'] as String? ?? '';
                    final end = slot['endTime'] as String? ?? '';
                    final time = start.isNotEmpty
                        ? '$start${end.isNotEmpty ? ' - $end' : ''}'
                        : '-';
                    return TableRow(children: [
                      _cell(slot['subject'] as String? ?? '-'),
                      _cell(formattedDate),
                      _cell(time),
                      _cell(slot['room'] as String? ?? '-'),
                    ]);
                  }),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.navy)),
      );

  Widget _cell(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textPrimary)),
      );

  Widget _statusBadge(String status) {
    final Color bgColor;
    final Color textColor;
    final String label;
    switch (status) {
      case 'PUBLISHED':
        bgColor = AppColors.success.withOpacity(0.15);
        textColor = AppColors.success;
        label = 'Published';
      case 'COMPLETED':
        bgColor = Colors.grey.withOpacity(0.15);
        textColor = Colors.grey;
        label = 'Completed';
      default:
        bgColor = Colors.orange.withOpacity(0.15);
        textColor = Colors.orange;
        label = status.isNotEmpty ? status : 'Draft';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w700, color: textColor)),
    );
  }
}
