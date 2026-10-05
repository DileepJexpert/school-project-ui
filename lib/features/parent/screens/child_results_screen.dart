import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/parent_api_service.dart';

class ChildResultsScreen extends StatefulWidget {
  final String? studentId;
  final String? studentName;

  const ChildResultsScreen({super.key, this.studentId, this.studentName});

  @override
  State<ChildResultsScreen> createState() => _ChildResultsScreenState();
}

class _ChildResultsScreenState extends State<ChildResultsScreen> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _results;

  @override
  void didUpdateWidget(ChildResultsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentId != widget.studentId && widget.studentId != null) {
      _loadResults();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.studentId != null) _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ParentApiService.getChildResults(widget.studentId!);
      if (mounted) setState(() => _results = data);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load results: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _gradeColor(String grade) {
    final g = grade.toUpperCase();
    if (g.startsWith('A')) return const Color(0xFF059669);
    if (g.startsWith('B')) return const Color(0xFF4F46E5);
    if (g.startsWith('C')) return const Color(0xFFD97706);
    return AppColors.error;
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
              Text('Could not load academic marks',
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
                onPressed: _loadResults,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_results == null) {
      return Center(
        child: Text('No results published yet.',
            style: GoogleFonts.poppins(color: AppColors.textSecondary)),
      );
    }

    final subjects = (_results?['subjects'] as List<dynamic>?) ?? [];
    final overallPct =
        (_results?['overallPercentage'] as num?)?.toDouble() ?? 0;
    final overallGrade = _results?['overallGrade'] as String? ?? 'A';
    final gradeCol = _gradeColor(overallGrade);

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
                      '${widget.studentName ?? "Student"}\'s Academic Report',
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: palette.brand),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Term examination scores, letter grades, and aggregate percentage standing.',
                      style: GoogleFonts.nunitoSans(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh results',
                onPressed: _loadResults,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Overall Score Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: gradeCol.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: gradeCol.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(
                      overallGrade,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: gradeCol,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cumulative Performance',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${overallPct.toStringAsFixed(1)}%',
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: palette.brand,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: gradeCol.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              overallPct >= 80 ? 'Distinction' : 'Passing',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: gradeCol,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          Text('Subject-wise Performance',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.brand)),
          const SizedBox(height: 12),

          if (subjects.isEmpty)
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: palette.border.withValues(alpha: 0.6)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No subject marks published yet.')),
              ),
            )
          else
            ...subjects.map((sub) {
              final subject = sub as Map<String, dynamic>;
              final name = subject['subjectName'] as String? ?? 'Subject';
              final marks =
                  (subject['marksObtained'] as num?)?.toDouble() ?? 0;
              final total =
                  (subject['totalMarks'] as num?)?.toDouble() ?? 100;
              final grade = subject['grade'] as String? ?? 'A';
              final pct = total > 0 ? (marks / total * 100) : 0.0;
              final subGradeCol = _gradeColor(grade);

              return Card(
                elevation: 0.5,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side:
                      BorderSide(color: palette.border.withValues(alpha: 0.6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: palette.brand,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${marks.toStringAsFixed(0)} / ${total.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: palette.brand,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: subGradeCol.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              grade,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: subGradeCol,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (pct / 100).clamp(0.0, 1.0),
                          minHeight: 7,
                          backgroundColor:
                              palette.border.withValues(alpha: 0.3),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(subGradeCol),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pct.toStringAsFixed(1)}% scored',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
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
