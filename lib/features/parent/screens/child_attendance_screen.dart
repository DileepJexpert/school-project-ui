import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/parent_api_service.dart';

class ChildAttendanceScreen extends StatefulWidget {
  final String? studentId;
  final String? studentName;

  const ChildAttendanceScreen({super.key, this.studentId, this.studentName});

  @override
  State<ChildAttendanceScreen> createState() => _ChildAttendanceScreenState();
}

class _ChildAttendanceScreenState extends State<ChildAttendanceScreen> {
  bool _loading = false;
  String? _error;
  List<dynamic> _records = [];
  Map<String, dynamic>? _summary;
  String _filter = 'ALL';

  @override
  void didUpdateWidget(ChildAttendanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentId != widget.studentId && widget.studentId != null) {
      _loadData();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.studentId != null) _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ParentApiService.getChildAttendance(widget.studentId!),
        ParentApiService.getChildAttendanceSummary(widget.studentId!),
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

  List<dynamic> get _filteredRecords {
    if (_filter == 'ALL') return _records;
    return _records.where((r) {
      final status = (r['status'] as String? ?? '').toUpperCase();
      return status == _filter;
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PRESENT':
        return const Color(0xFF059669);
      case 'ABSENT':
        return AppColors.error;
      case 'LATE':
      case 'HALF_DAY':
        return const Color(0xFFD97706);
      default:
        return AppColors.navy;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PRESENT':
        return Icons.check_circle_outline_rounded;
      case 'ABSENT':
        return Icons.cancel_outlined;
      case 'LATE':
        return Icons.access_time_outlined;
      default:
        return Icons.calendar_today_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (widget.studentId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_outlined,
                size: 52, color: palette.brand.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('Please select a student from the Overview tab.',
                style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 460),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppColors.error.withValues(alpha: 0.8)),
              const SizedBox(height: 12),
              Text('Could not load attendance',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.brand)),
              const SizedBox(height: 6),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredRecords;

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.studentName ?? "Student"}\'s Attendance Register',
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: palette.brand),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Daily morning roll-call record and cumulative term attendance percentage.',
                      style: GoogleFonts.nunitoSans(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh records',
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_summary != null) _buildSummaryCards(),
          const SizedBox(height: 20),

          // Filter Row
          Row(
            children: [
              Text('Records:',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.brand)),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                children: [
                  _filterChip('All Days', 'ALL'),
                  _filterChip('Present', 'PRESENT',
                      color: const Color(0xFF059669)),
                  _filterChip('Absent', 'ABSENT', color: AppColors.error),
                ],
              ),
              const Spacer(),
              Text(
                '${filtered.length} days logged',
                style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: palette.border.withValues(alpha: 0.6)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_available_outlined,
                          size: 48,
                          color: palette.brand.withValues(alpha: 0.3)),
                      const SizedBox(height: 10),
                      Text('No records found for this filter.',
                          style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            )
          else
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: palette.border.withValues(alpha: 0.6)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: palette.border.withValues(alpha: 0.4)),
                itemBuilder: (context, index) {
                  final record = filtered[index] as Map<String, dynamic>;
                  final date = record['date'] as String? ?? '';
                  final status = record['status'] as String? ?? 'PRESENT';
                  final color = _statusColor(status);

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(_statusIcon(status), color: color, size: 18),
                    ),
                    title: Text(date,
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, {Color? color}) {
    final selected = _filter == value;
    final chipColor = color ?? context.palette.brand;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: chipColor.withValues(alpha: 0.12),
      labelStyle: GoogleFonts.nunitoSans(
        color: selected ? chipColor : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      side: BorderSide(
        color: selected
            ? chipColor
            : context.palette.border.withValues(alpha: 0.6),
      ),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _buildSummaryCards() {
    final present = (_summary?['presentDays'] as num?)?.toInt() ?? 0;
    final absent = (_summary?['absentDays'] as num?)?.toInt() ?? 0;
    final total = (_summary?['totalDays'] as num?)?.toInt() ?? 0;
    final percentage =
        (_summary?['attendancePercentage'] as num?)?.toDouble() ?? 0;
    final isGood = percentage >= 75.0;

    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 650;
      final width = isNarrow
          ? (constraints.maxWidth - 12) / 2
          : (constraints.maxWidth - 36) / 4;

      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _summaryCard('Present Days', '$present',
              const Color(0xFF059669), Icons.check_circle_outline_rounded, width),
          _summaryCard('Absent Days', '$absent', AppColors.error,
              Icons.cancel_outlined, width),
          _summaryCard('Working Days', '$total', context.palette.brand,
              Icons.calendar_month_outlined, width),
          _summaryCard(
              'Attendance Rate',
              '${percentage.toStringAsFixed(1)}%',
              isGood ? const Color(0xFF059669) : AppColors.error,
              Icons.pie_chart_outline_rounded,
              width,
              caption: isGood ? 'Above 75% Target' : 'Below Minimum'),
        ],
      );
    });
  }

  Widget _summaryCard(String label, String value, Color color, IconData icon,
      double width, {String? caption}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
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
