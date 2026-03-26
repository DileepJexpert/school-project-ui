import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/student_portal_api_service.dart';

class MyResultsScreen extends StatefulWidget {
  const MyResultsScreen({super.key});

  @override
  State<MyResultsScreen> createState() => _MyResultsScreenState();
}

class _MyResultsScreenState extends State<MyResultsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _results;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await StudentPortalApiService.getMyResults();
      if (mounted) setState(() => _results = data);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load results: $e');
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
    if (_results == null) {
      return Center(
          child: Text('No results available.',
              style: GoogleFonts.poppins(color: AppColors.textSecondary)));
    }

    final subjects = (_results?['subjects'] as List<dynamic>?) ?? [];
    final overallPct =
        (_results?['overallPercentage'] as num?)?.toDouble() ?? 0;
    final overallGrade = _results?['overallGrade'] as String? ?? '';

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Results',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.navy.withOpacity(0.1),
                    child: Text(overallGrade,
                        style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy)),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Overall Performance',
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: AppColors.textSecondary)),
                      Text('${overallPct.toStringAsFixed(1)}%',
                          style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Subject-wise Results',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subjects.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final subject = subjects[index] as Map<String, dynamic>;
                final name = subject['subjectName'] as String? ?? '';
                final marks =
                    (subject['marksObtained'] as num?)?.toDouble() ?? 0;
                final total =
                    (subject['totalMarks'] as num?)?.toDouble() ?? 100;
                final grade = subject['grade'] as String? ?? '';
                final pct = total > 0 ? (marks / total * 100) : 0.0;

                return ListTile(
                  title: Text(name, style: GoogleFonts.poppins(fontSize: 14)),
                  subtitle: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: Colors.grey[200],
                    color: pct >= 80
                        ? Colors.green
                        : pct >= 60
                            ? Colors.orange
                            : Colors.red,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${marks.toInt()}/${total.toInt()}',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(grade,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
