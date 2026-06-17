import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/quiz_api_service.dart';

enum _QuizViewState { list, taking, results }

class StudentQuizScreen extends StatefulWidget {
  const StudentQuizScreen({super.key});

  @override
  State<StudentQuizScreen> createState() => _StudentQuizScreenState();
}

class _StudentQuizScreenState extends State<StudentQuizScreen> {
  // ── List view state ──
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _quizzes = [];
  String _selectedSubject = 'All';
  List<String> _subjects = [];
  final Map<String, Map<String, dynamic>> _attemptCache = {};

  // ── View state ──
  _QuizViewState _viewState = _QuizViewState.list;

  // ── Quiz-taking state ──
  Map<String, dynamic>? _activeQuiz;
  int _currentQuestionIndex = 0;
  Map<int, int> _selectedAnswers = {};
  Timer? _timer;
  int _remainingSeconds = 0;
  late DateTime _quizStartTime;

  // ── Results state ──
  Map<String, dynamic>? _resultData;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ────────────────────────── Data Loading ──────────────────────────

  Future<void> _loadQuizzes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await QuizApiService.getMyQuizzes();
      if (!mounted) return;

      // Extract unique subjects
      final subjectSet = <String>{};
      for (final q in data) {
        final s = q['subject'] as String?;
        if (s != null && s.isNotEmpty) subjectSet.add(s);
      }

      // Check attempt status for each quiz
      for (final q in data) {
        final id = q['_id'] as String? ?? q['id'] as String? ?? '';
        if (id.isNotEmpty && !_attemptCache.containsKey(id)) {
          try {
            final status = await QuizApiService.hasAttempted(id);
            _attemptCache[id] = status;
          } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() {
        _quizzes = data;
        _subjects = subjectSet.toList()..sort();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredQuizzes {
    if (_selectedSubject == 'All') return _quizzes;
    return _quizzes.where((q) => q['subject'] == _selectedSubject).toList();
  }

  // ────────────────────────── Quiz Taking ──────────────────────────

  void _startQuiz(Map<String, dynamic> quiz) {
    final timeLimit = (quiz['timeLimitMinutes'] as num?)?.toInt() ?? 0;
    setState(() {
      _viewState = _QuizViewState.taking;
      _activeQuiz = quiz;
      _currentQuestionIndex = 0;
      _selectedAnswers = {};
      _remainingSeconds = timeLimit * 60;
      _quizStartTime = DateTime.now();
    });

    if (timeLimit > 0) {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds <= 0) {
            t.cancel();
            _submitQuiz();
          }
        });
      });
    }
  }

  List<Map<String, dynamic>> get _questions {
    final raw = _activeQuiz?['questions'] as List?;
    if (raw == null) return [];
    return raw.cast<Map<String, dynamic>>();
  }

  Future<void> _submitQuiz() async {
    _timer?.cancel();

    final quizId =
        _activeQuiz?['_id'] as String? ?? _activeQuiz?['id'] as String? ?? '';
    if (quizId.isEmpty) return;

    // Build answers map with string keys for JSON
    final answersMap = <String, dynamic>{};
    _selectedAnswers.forEach((k, v) => answersMap[k.toString()] = v);

    try {
      final result = await QuizApiService.submitAttempt(
        quizId,
        {'answers': answersMap},
      );
      if (!mounted) return;

      // Update attempt cache
      _attemptCache[quizId] = {
        'attempted': true,
        'score': result['score'],
        'totalMarks': result['totalMarks'],
      };

      setState(() {
        _resultData = result;
        _viewState = _QuizViewState.results;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit quiz: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showSubmitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        ),
        title: Text(
          'Submit Quiz?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        content: Text(
          'Are you sure? You cannot retake this quiz.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _submitQuiz();
            },
            child: Text('Submit', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _backToList() {
    _timer?.cancel();
    setState(() {
      _viewState = _QuizViewState.list;
      _activeQuiz = null;
      _resultData = null;
      _selectedAnswers = {};
    });
    _loadQuizzes();
  }

  // ────────────────────────── Build ──────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_viewState) {
      case _QuizViewState.list:
        return _buildListView();
      case _QuizViewState.taking:
        return _buildTakingView();
      case _QuizViewState.results:
        return _buildResultsView();
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  QUIZ LIST VIEW
  // ═══════════════════════════════════════════════════════════

  Widget _buildListView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Quizzes',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ),

        // Subject filter chips
        if (_subjects.isNotEmpty)
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('All'),
                ..._subjects.map(_buildFilterChip),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // Content
        Expanded(child: _buildListContent()),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedSubject == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? AppColors.white : AppColors.navy,
          ),
        ),
        backgroundColor: AppColors.white,
        selectedColor: AppColors.navy,
        side: BorderSide(
          color: isSelected ? AppColors.navy : AppColors.border,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        onSelected: (_) {
          setState(() => _selectedSubject = label);
        },
      ),
    );
  }

  Widget _buildListContent() {
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
            Text(
              'Failed to load quizzes',
              style: GoogleFonts.poppins(fontSize: 14, color: AppColors.error),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadQuizzes, child: const Text('Retry')),
          ],
        ),
      );
    }

    final filtered = _filteredQuizzes;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No quizzes available',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Published quizzes will appear here.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQuizzes,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: filtered.length,
        itemBuilder: (_, i) => _buildQuizCard(filtered[i]),
      ),
    );
  }

  Widget _buildQuizCard(Map<String, dynamic> quiz) {
    final title = quiz['title'] as String? ?? 'Untitled Quiz';
    final subject = quiz['subject'] as String? ?? '';
    final difficulty = (quiz['difficulty'] as String? ?? 'MEDIUM').toUpperCase();
    final questions = (quiz['questions'] as List?)?.length ?? 0;
    final timeLimit = (quiz['timeLimitMinutes'] as num?)?.toInt() ?? 0;
    final quizId = quiz['_id'] as String? ?? quiz['id'] as String? ?? '';

    final attemptInfo = _attemptCache[quizId];
    final attempted = attemptInfo?['attempted'] == true;
    final attemptScore = attemptInfo?['score'];
    final attemptTotal = attemptInfo?['totalMarks'];

    // Difficulty colors
    Color diffColor;
    Color diffBg;
    switch (difficulty) {
      case 'EASY':
        diffColor = AppColors.success;
        diffBg = AppColors.success.withOpacity(0.12);
      case 'HARD':
        diffColor = AppColors.error;
        diffBg = AppColors.error.withOpacity(0.12);
      default:
        diffColor = AppColors.warning;
        diffBg = AppColors.warning.withOpacity(0.12);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 10),

            // Subject chip + Difficulty badge
            Row(
              children: [
                if (subject.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      subject,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                if (subject.isNotEmpty) const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: diffBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    difficulty,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: diffColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Question count + Time limit
            Row(
              children: [
                Icon(Icons.help_outline, size: 15, color: AppColors.textLight),
                const SizedBox(width: 4),
                Text(
                  '$questions questions',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.timer_outlined, size: 15, color: AppColors.textLight),
                const SizedBox(width: 4),
                Text(
                  timeLimit > 0 ? '$timeLimit min' : 'No time limit',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Bottom row: attempted badge or start button
            if (attempted)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Completed',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                    const Spacer(),
                    if (attemptScore != null && attemptTotal != null)
                      Text(
                        'Score: $attemptScore / $attemptTotal',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _startQuiz(quiz),
                  child: Text(
                    'Start Quiz',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  QUIZ TAKING VIEW
  // ═══════════════════════════════════════════════════════════

  Widget _buildTakingView() {
    final questions = _questions;
    if (questions.isEmpty) {
      return Center(
        child: Text(
          'No questions in this quiz.',
          style: GoogleFonts.poppins(color: AppColors.textSecondary),
        ),
      );
    }

    final totalQuestions = questions.length;
    final currentQ = questions[_currentQuestionIndex];
    final questionText = currentQ['questionText'] as String? ?? '';
    final options = (currentQ['options'] as List?)?.cast<dynamic>() ?? [];
    final timeLimit =
        (_activeQuiz?['timeLimitMinutes'] as num?)?.toInt() ?? 0;
    final isLastQuestion = _currentQuestionIndex == totalQuestions - 1;

    return Column(
      children: [
        // Top bar: question indicator + timer
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1} of $totalQuestions',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              const Spacer(),
              if (timeLimit > 0) _buildTimer(),
            ],
          ),
        ),

        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / totalQuestions,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.gold),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Question + Options
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusLG),
                  ),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      questionText,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Options
                ...List.generate(options.length, (i) {
                  final isSelected =
                      _selectedAnswers[_currentQuestionIndex] == i;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusLG),
                      onTap: () {
                        setState(() {
                          _selectedAnswers[_currentQuestionIndex] = i;
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.goldPale
                              : AppColors.white,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusLG),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.gold
                                : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? AppColors.gold
                                    : AppColors.cream,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.gold
                                      : AppColors.border,
                                ),
                              ),
                              child: Center(
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        size: 16,
                                        color: AppColors.white)
                                    : Text(
                                        String.fromCharCode(65 + i),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                options[i].toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Navigation buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              // Previous
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: AppColors.navy),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMD),
                      ),
                    ),
                    onPressed: () {
                      setState(() => _currentQuestionIndex--);
                    },
                    child: Text(
                      'Previous',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (_currentQuestionIndex > 0) const SizedBox(width: 12),

              // Next / Submit
              Expanded(
                child: isLastQuestion
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: AppColors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppSizes.radiusMD),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _showSubmitConfirmation,
                        child: Text(
                          'Submit Quiz',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.navy,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppSizes.radiusMD),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          setState(() => _currentQuestionIndex++);
                        },
                        child: Text(
                          'Next',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimer() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final isUrgent = _remainingSeconds < 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isUrgent
            ? AppColors.error.withOpacity(0.1)
            : AppColors.navy.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            size: 16,
            color: isUrgent ? AppColors.error : AppColors.navy,
          ),
          const SizedBox(width: 4),
          Text(
            timeStr,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isUrgent ? AppColors.error : AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  RESULTS VIEW
  // ═══════════════════════════════════════════════════════════

  Widget _buildResultsView() {
    if (_resultData == null || _activeQuiz == null) {
      return Center(
        child: Text(
          'No results available.',
          style: GoogleFonts.poppins(color: AppColors.textSecondary),
        ),
      );
    }

    final score = (_resultData!['score'] as num?)?.toInt() ?? 0;
    final totalMarks = (_resultData!['totalMarks'] as num?)?.toInt() ?? 0;
    final percentage = (_resultData!['percentage'] as num?)?.toDouble() ?? 0.0;
    final timeTaken = _resultData!['timeTaken'] as String? ?? '';
    final correctAnswers =
        (_resultData!['correctAnswers'] as List?)?.cast<dynamic>() ?? [];
    final questions = _questions;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Score card
        _buildScoreCard(score, totalMarks, percentage, timeTaken),
        const SizedBox(height: 20),

        // Section title
        Text(
          'Question Review',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),

        // Question-by-question review
        ...List.generate(questions.length, (qIndex) {
          final q = questions[qIndex];
          final questionText = q['questionText'] as String? ?? '';
          final options =
              (q['options'] as List?)?.cast<dynamic>() ?? [];
          final correctIndex =
              qIndex < correctAnswers.length
                  ? (correctAnswers[qIndex] as num?)?.toInt()
                  : (q['correctAnswer'] as num?)?.toInt();
          final studentAnswer = _selectedAnswers[qIndex];
          final explanation = q['explanation'] as String?;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              ),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question number + text
                    Text(
                      'Q${qIndex + 1}. $questionText',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Options with coloring
                    ...List.generate(options.length, (oIndex) {
                      final isCorrect = oIndex == correctIndex;
                      final isStudentPick = oIndex == studentAnswer;
                      final isWrongPick =
                          isStudentPick && !isCorrect;

                      Color bgColor;
                      Color borderColor;
                      Color textColor = AppColors.textPrimary;
                      IconData? trailingIcon;

                      if (isCorrect) {
                        bgColor = AppColors.success.withOpacity(0.1);
                        borderColor =
                            AppColors.success.withOpacity(0.5);
                        trailingIcon = Icons.check_circle;
                      } else if (isWrongPick) {
                        bgColor = AppColors.error.withOpacity(0.1);
                        borderColor =
                            AppColors.error.withOpacity(0.5);
                        trailingIcon = Icons.cancel;
                      } else {
                        bgColor = Colors.grey.shade50;
                        borderColor = Colors.grey.shade200;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(
                                AppSizes.radiusMD),
                            border:
                                Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${String.fromCharCode(65 + oIndex)}. ${options[oIndex]}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: textColor,
                                    fontWeight: (isCorrect || isWrongPick)
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (trailingIcon != null)
                                Icon(
                                  trailingIcon,
                                  size: 18,
                                  color: isCorrect
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // Explanation
                    if (explanation != null &&
                        explanation.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(
                              AppSizes.radiusMD),
                          border: Border.all(
                              color: AppColors.info.withOpacity(0.25)),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline,
                                size: 16,
                                color: AppColors.info),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                explanation,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 8),

        // Back to Quizzes button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              side: const BorderSide(color: AppColors.navy, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
            ),
            onPressed: _backToList,
            child: Text(
              'Back to Quizzes',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildScoreCard(
      int score, int totalMarks, double percentage, String timeTaken) {
    // Performance badge
    final String badgeLabel;
    final Color badgeColor;
    final IconData badgeIcon;

    if (percentage >= 90) {
      badgeLabel = 'Excellent!';
      badgeColor = AppColors.success;
      badgeIcon = Icons.star;
    } else if (percentage >= 70) {
      badgeLabel = 'Good Job!';
      badgeColor = AppColors.info;
      badgeIcon = Icons.thumb_up;
    } else if (percentage >= 50) {
      badgeLabel = 'Average';
      badgeColor = AppColors.warning;
      badgeIcon = Icons.info_outline;
    } else {
      badgeLabel = 'Needs Improvement';
      badgeColor = AppColors.error;
      badgeIcon = Icons.warning_amber_rounded;
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Performance badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(badgeIcon, size: 20, color: badgeColor),
                  const SizedBox(width: 8),
                  Text(
                    badgeLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Score
            Text(
              '$score / $totalMarks',
              style: GoogleFonts.poppins(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),

            if (timeTaken.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined,
                      size: 16, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(
                    'Time taken: $timeTaken',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
