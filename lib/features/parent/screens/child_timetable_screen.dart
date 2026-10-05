import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/parent_api_service.dart';

class ChildTimetableScreen extends StatefulWidget {
  final String? studentId;
  final String? studentName;

  const ChildTimetableScreen({super.key, this.studentId, this.studentName});

  @override
  State<ChildTimetableScreen> createState() => _ChildTimetableScreenState();
}

class _ChildTimetableScreenState extends State<ChildTimetableScreen> {
  bool _loading = false;
  String? _error;
  dynamic _timetable;
  String _selectedDay = 'Monday';

  static const _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void didUpdateWidget(ChildTimetableScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentId != widget.studentId && widget.studentId != null) {
      _loadTimetable();
    }
  }

  @override
  void initState() {
    super.initState();
    final weekday = DateTime.now().weekday;
    if (weekday >= 1 && weekday <= 6) {
      _selectedDay = _daysOfWeek[weekday - 1];
    }
    if (widget.studentId != null) _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ParentApiService.getChildTimetable(widget.studentId!);
      if (mounted) setState(() => _timetable = data);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load timetable: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _subjectColor(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) return const Color(0xFF4F46E5);
    if (s.contains('sci') || s.contains('phys') || s.contains('chem') || s.contains('bio')) {
      return const Color(0xFF059669);
    }
    if (s.contains('eng')) return const Color(0xFF7C3AED);
    if (s.contains('soc') || s.contains('hist') || s.contains('geog')) {
      return const Color(0xFFD97706);
    }
    if (s.contains('comp') || s.contains('it')) return const Color(0xFF0284C7);
    if (s.contains('hindi') || s.contains('lang')) return const Color(0xFFDC2626);
    return const Color(0xFF0D9488);
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
              Text('Could not load timetable',
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
                onPressed: _loadTimetable,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final days = _timetable is Map ? (_timetable as Map) : {};
    if (days.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.table_chart_outlined,
                  size: 52, color: palette.brand.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text('No class timetable published yet.',
                  style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    final activeDayPeriods =
        (days[_selectedDay] as List<dynamic>?) ?? [];

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
                      '${widget.studentName ?? "Student"}\'s Weekly Schedule',
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: palette.brand),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Day-wise period timings, assigned subjects, and subject instructors.',
                      style: GoogleFonts.nunitoSans(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh schedule',
                onPressed: _loadTimetable,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Day Selection Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _daysOfWeek.map((day) {
                final isSelected = _selectedDay.toLowerCase() == day.toLowerCase();
                final hasClasses = days.keys.any((k) =>
                    k.toString().toLowerCase() == day.toLowerCase());

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(day),
                    selected: isSelected,
                    selectedColor: palette.brand,
                    labelStyle: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? palette.brand
                          : (hasClasses
                              ? palette.border.withValues(alpha: 0.6)
                              : palette.border.withValues(alpha: 0.3)),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedDay = day);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Periods list for selected day
          Row(
            children: [
              Text(
                '$_selectedDay Schedule',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.brand,
                ),
              ),
              const Spacer(),
              Text(
                '${activeDayPeriods.length} periods',
                style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (activeDayPeriods.isEmpty)
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
                      Icon(Icons.weekend_outlined,
                          size: 48,
                          color: palette.brand.withValues(alpha: 0.3)),
                      const SizedBox(height: 10),
                      Text('No classes scheduled for $_selectedDay.',
                          style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            )
          else
            ...activeDayPeriods.map((p) {
              final period = p as Map<String, dynamic>;
              final periodNum = period['period']?.toString() ?? '1';
              final subject = period['subject'] as String? ?? 'Subject';
              final teacher = period['teacher'] as String? ?? 'Teacher';
              final startTime = period['startTime'] as String? ?? '';
              final endTime = period['endTime'] as String? ?? '';
              final timeStr = startTime.isNotEmpty && endTime.isNotEmpty
                  ? '$startTime - $endTime'
                  : '';
              final color = _subjectColor(subject);

              return Card(
                elevation: 0.5,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: palette.border.withValues(alpha: 0.6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: color.withValues(alpha: 0.25)),
                        ),
                        child: Center(
                          child: Text(
                            'P$periodNum',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: palette.brand,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.person_outline,
                                    size: 13,
                                    color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  teacher,
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
                      if (timeStr.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: palette.brand.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule,
                                  size: 13, color: palette.brand),
                              const SizedBox(width: 5),
                              Text(
                                timeStr,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: palette.brand,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
