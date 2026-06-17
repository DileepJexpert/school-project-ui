import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/quiz_api_service.dart';

class LearningProgressScreen extends StatefulWidget {
  const LearningProgressScreen({super.key});

  @override
  State<LearningProgressScreen> createState() =>
      _LearningProgressScreenState();
}

class _LearningProgressScreenState extends State<LearningProgressScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _progress;
  List<Map<String, dynamic>> _attempts = [];

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
        QuizApiService.getMyProgress(),
        QuizApiService.getMyAttempts(),
      ]);
      if (mounted) {
        setState(() {
          _progress = results[0] as Map<String, dynamic>;
          _attempts = (results[1] as List<Map<String, dynamic>>);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to load progress data: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.poppins(color: AppColors.error, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('Retry', style: GoogleFonts.poppins(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                side: const BorderSide(color: AppColors.navy),
              ),
            ),
          ],
        ),
      );
    }

    final totalQuizzes = (_progress?['totalQuizzes'] as num?)?.toInt() ?? 0;
    final averageScore =
        (_progress?['averageScore'] as num?)?.toDouble() ?? 0.0;
    final bestSubject = _progress?['bestSubject'] as String? ?? '-';
    final subjectPerformance =
        (_progress?['subjectPerformance'] as Map<String, dynamic>?) ?? {};
    final recentAttempts =
        _attempts.length > 10 ? _attempts.sublist(0, 10) : _attempts;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.gold,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(Responsive.contentPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Stats Row --
            _buildStatsRow(totalQuizzes, averageScore, bestSubject),
            const SizedBox(height: 24),

            // -- Subject Performance --
            _buildSectionTitle('Subject Performance', Icons.bar_chart),
            const SizedBox(height: 12),
            _buildSubjectPerformanceCard(subjectPerformance),
            const SizedBox(height: 24),

            // -- Recent Attempts --
            _buildSectionTitle('Recent Attempts', Icons.history),
            const SizedBox(height: 12),
            if (recentAttempts.isEmpty)
              _buildEmptyState(
                'No quiz attempts yet.',
                Icons.quiz_outlined,
              )
            else
              ...recentAttempts.map(_buildAttemptCard),
            const SizedBox(height: 24),

            // -- Motivational Message --
            _buildMotivationalMessage(totalQuizzes, averageScore),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats Row
  // ---------------------------------------------------------------------------
  Widget _buildStatsRow(
      int totalQuizzes, double averageScore, String bestSubject) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildStatCard(
          icon: Icons.quiz,
          label: 'Total Quizzes Taken',
          value: '$totalQuizzes',
          color: AppColors.navy,
        ),
        _buildStatCard(
          icon: Icons.trending_up,
          label: 'Average Score',
          value: '${averageScore.toStringAsFixed(1)}%',
          color: AppColors.gold,
        ),
        _buildStatCard(
          icon: Icons.emoji_events,
          label: 'Best Subject',
          value: bestSubject,
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return SizedBox(
      width: Responsive.isMobile(context) ? double.infinity : 200,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
          side: const BorderSide(color: AppColors.border),
        ),
        color: AppColors.white,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section Title
  // ---------------------------------------------------------------------------
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.navy),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Subject Performance Card
  // ---------------------------------------------------------------------------
  Widget _buildSubjectPerformanceCard(
      Map<String, dynamic> subjectPerformance) {
    if (subjectPerformance.isEmpty) {
      return _buildEmptyState(
        'No subject data available yet.',
        Icons.school_outlined,
      );
    }

    final entries = subjectPerformance.entries.toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingMD),
        child: Column(
          children: List.generate(entries.length, (index) {
            final subject = entries[index].key;
            final data = entries[index].value as Map<String, dynamic>;
            final average = (data['average'] as num?)?.toDouble() ?? 0.0;
            final attempted = (data['attempted'] as num?)?.toInt() ?? 0;

            return Padding(
              padding: EdgeInsets.only(
                  bottom: index < entries.length - 1 ? 16 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          subject,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${average.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusSM),
                          child: LinearProgressIndicator(
                            value: (average / 100).clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: AppColors.cream,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$attempted quiz${attempted == 1 ? '' : 'zes'} attempted',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Attempt Card
  // ---------------------------------------------------------------------------
  Widget _buildAttemptCard(Map<String, dynamic> attempt) {
    final quizTitle = attempt['quizTitle'] as String? ?? 'Untitled Quiz';
    final subject = attempt['subject'] as String? ?? '';
    final score = (attempt['score'] as num?)?.toInt() ?? 0;
    final totalMarks = (attempt['totalMarks'] as num?)?.toInt() ?? 0;
    final percentage = (attempt['percentage'] as num?)?.toDouble() ?? 0.0;
    final completedAt = attempt['completedAt'] as String? ?? '';

    final Color percentageColor;
    if (percentage >= 70) {
      percentageColor = AppColors.success;
    } else if (percentage >= 50) {
      percentageColor = AppColors.warning;
    } else {
      percentageColor = AppColors.error;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingMD,
          vertical: 12,
        ),
        child: Row(
          children: [
            // Left content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quizTitle,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (subject.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.goldPale,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusSM),
                          ),
                          child: Text(
                            subject,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        _formatDate(completedAt),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Right: score & percentage
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$score/$totalMarks',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: percentageColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSM),
                  ),
                  child: Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: percentageColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Motivational Message
  // ---------------------------------------------------------------------------
  Widget _buildMotivationalMessage(int totalQuizzes, double averageScore) {
    final String message;
    final IconData icon;
    final Color color;

    if (totalQuizzes == 0) {
      message = 'Start taking quizzes to track your progress!';
      icon = Icons.school;
      color = AppColors.navy;
    } else if (averageScore >= 90) {
      message = "Outstanding! You're a star learner!";
      icon = Icons.star;
      color = AppColors.success;
    } else if (averageScore >= 70) {
      message = 'Great progress! Keep up the good work!';
      icon = Icons.thumb_up;
      color = AppColors.info;
    } else if (averageScore >= 50) {
      message = "You're getting there! Practice makes perfect.";
      icon = Icons.trending_up;
      color = AppColors.warning;
    } else {
      message = "Don't give up! Every attempt makes you stronger.";
      icon = Icons.favorite;
      color = AppColors.error;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingMD),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty State
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState(String text, IconData icon) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: AppColors.textLight),
              const SizedBox(height: 12),
              Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final date = DateTime.parse(isoDate);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return isoDate;
    }
  }
}
