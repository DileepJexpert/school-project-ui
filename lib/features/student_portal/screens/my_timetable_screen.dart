import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/student_portal_api_service.dart';

class MyTimetableScreen extends StatefulWidget {
  const MyTimetableScreen({super.key});

  @override
  State<MyTimetableScreen> createState() => _MyTimetableScreenState();
}

class _MyTimetableScreenState extends State<MyTimetableScreen> {
  bool _loading = true;
  String? _error;
  dynamic _timetable;

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await StudentPortalApiService.getMyTimetable();
      if (mounted) setState(() => _timetable = data);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load timetable: $e');
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

    final days = _timetable is Map ? (_timetable as Map) : {};
    if (days.isEmpty) {
      return Center(
        child: Text('No timetable available.',
            style: GoogleFonts.poppins(color: AppColors.textSecondary)),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Timetable',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 16),
          ...days.entries.map((entry) {
            final day = entry.key as String;
            final periods = entry.value as List<dynamic>? ?? [];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text(day,
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                initiallyExpanded: true,
                children: periods.map((p) {
                  final period = p as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.navy.withOpacity(0.1),
                      child: Text('${period['period'] ?? ''}',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.navy)),
                    ),
                    title: Text(period['subject'] as String? ?? '',
                        style: GoogleFonts.poppins(fontSize: 14)),
                    subtitle: Text(period['teacher'] as String? ?? '',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textSecondary)),
                    trailing: Text(
                      '${period['startTime'] ?? ''} - ${period['endTime'] ?? ''}',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }
}
