import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/quiz_api_service.dart';

class QuizManagementScreen extends StatefulWidget {
  const QuizManagementScreen({super.key});

  @override
  State<QuizManagementScreen> createState() => _QuizManagementScreenState();
}

class _QuizManagementScreenState extends State<QuizManagementScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _quizzes = [];
  String? _filterClass;
  String? _filterSubject;
  String _filterStatus = 'ALL'; // ALL, DRAFT, PUBLISHED

  late final List<String> _allSubjects;

  @override
  void initState() {
    super.initState();
    final subjectSet = <String>{
      ...SchoolConstants.commonSubjects,
      'Physics',
      'Chemistry',
      'Biology',
      'History',
      'Geography',
      'Economics',
    };
    _allSubjects = subjectSet.toList()..sort();
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    setState(() => _loading = true);
    try {
      final data = await QuizApiService.getAllQuizzes();
      if (mounted) setState(() => _quizzes = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load quizzes: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredQuizzes {
    return _quizzes.where((q) {
      if (_filterClass != null && q['className'] != _filterClass) return false;
      if (_filterSubject != null && q['subject'] != _filterSubject) {
        return false;
      }
      if (_filterStatus != 'ALL' && q['status'] != _filterStatus) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Header row ---
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Quiz Manager',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Class filter
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      value: _filterClass,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: 'All Classes',
                        prefixIcon: const Icon(Icons.filter_list, size: 18),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Classes'),
                        ),
                        ...SchoolConstants.baseClasses.map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() => _filterClass = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Subject filter
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      value: _filterSubject,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: 'All Subjects',
                        prefixIcon:
                            const Icon(Icons.subject_outlined, size: 18),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Subjects'),
                        ),
                        ..._allSubjects.map(
                          (s) => DropdownMenuItem(value: s, child: Text(s)),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() => _filterSubject = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    onPressed: () => _showQuizFormDialog(null),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      'Create Quiz',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // --- Status filter chips ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              _buildStatusChip('ALL', 'All'),
              _buildStatusChip('DRAFT', 'Draft'),
              _buildStatusChip('PUBLISHED', 'Published'),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // --- Quiz list ---
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredQuizzes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.quiz_outlined,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            'No quizzes found.',
                            style: GoogleFonts.poppins(
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadQuizzes,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredQuizzes.length,
                        itemBuilder: (context, index) {
                          return _buildQuizCard(_filteredQuizzes[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // ─── Status Filter Chip ───

  Widget _buildStatusChip(String value, String label) {
    final selected = _filterStatus == value;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: selected ? AppColors.white : AppColors.textSecondary,
        ),
      ),
      selected: selected,
      selectedColor: AppColors.navy,
      checkmarkColor: AppColors.white,
      backgroundColor: AppColors.cream,
      side: BorderSide(
        color: selected ? AppColors.navy : AppColors.border,
      ),
      onSelected: (_) {
        setState(() => _filterStatus = value);
      },
    );
  }

  // ─── Quiz Card ───

  Widget _buildQuizCard(Map<String, dynamic> quiz) {
    final id = quiz['id'] as String? ?? '';
    final title = quiz['title'] as String? ?? 'Untitled Quiz';
    final subject = quiz['subject'] as String? ?? '';
    final className = quiz['className'] as String? ?? '';
    final difficulty = quiz['difficulty'] as String? ?? 'EASY';
    final questions = quiz['questions'] as List<dynamic>? ?? [];
    final timeLimitMinutes = quiz['timeLimitMinutes'] as int? ?? 0;
    final status = quiz['status'] as String? ?? 'DRAFT';
    final isDraft = status == 'DRAFT';

    Color difficultyColor;
    switch (difficulty) {
      case 'HARD':
        difficultyColor = AppColors.error;
        break;
      case 'MEDIUM':
        difficultyColor = AppColors.warning;
        break;
      default:
        difficultyColor = AppColors.success;
    }

    Color statusBgColor;
    Color statusTextColor;
    if (status == 'PUBLISHED') {
      statusBgColor = AppColors.success.withOpacity(0.15);
      statusTextColor = AppColors.success;
    } else {
      statusBgColor = AppColors.warning.withOpacity(0.15);
      statusTextColor = AppColors.warning;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: title + status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSM),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: subject chip, class chip, difficulty badge
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(subject, AppColors.info),
                _chip(className, AppColors.navy),
                _chip(
                  difficulty,
                  difficultyColor,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 3: question count + time limit
            Row(
              children: [
                Icon(Icons.help_outline,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${questions.length} question${questions.length == 1 ? '' : 's'}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.timer_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  timeLimitMinutes > 0
                      ? '$timeLimitMinutes min'
                      : 'No time limit',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 4: Actions
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showQuizFormDialog(quiz),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(
                    'Edit',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
                if (isDraft) ...[
                  const SizedBox(width: 4),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.gold,
                    ),
                    onPressed: () => _publishQuiz(id),
                    icon: const Icon(Icons.publish_outlined, size: 16),
                    label: Text(
                      'Publish',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _showAttemptsDialog(id, title),
                  icon: const Icon(Icons.people_outline, size: 16),
                  label: Text(
                    'View Attempts',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  onPressed: () => _deleteQuiz(id),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(
                    'Delete',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusSM),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ─── Actions ───

  Future<void> _publishQuiz(String id) async {
    try {
      await QuizApiService.publishQuiz(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz published successfully')),
        );
      }
      _loadQuizzes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish quiz: $e')),
        );
      }
    }
  }

  Future<void> _deleteQuiz(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Quiz',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to delete this quiz? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.poppins(color: AppColors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await QuizApiService.deleteQuiz(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz deleted')),
        );
      }
      _loadQuizzes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete quiz: $e')),
        );
      }
    }
  }

  // ─── View Attempts Dialog ───

  Future<void> _showAttemptsDialog(String quizId, String quizTitle) async {
    showDialog(
      context: context,
      builder: (ctx) {
        return _AttemptsDialog(quizId: quizId, quizTitle: quizTitle);
      },
    );
  }

  // ─── Create / Edit Quiz Dialog ───

  void _showQuizFormDialog(Map<String, dynamic>? existing) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _QuizFormDialog(
          existing: existing,
          allSubjects: _allSubjects,
          onSaved: () {
            _loadQuizzes();
          },
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Quiz Form Dialog (Create / Edit)
// ═════════════════════════════════════════════════════════════════════════════

class _QuizFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<String> allSubjects;
  final VoidCallback onSaved;

  const _QuizFormDialog({
    required this.existing,
    required this.allSubjects,
    required this.onSaved,
  });

  @override
  State<_QuizFormDialog> createState() => _QuizFormDialogState();
}

class _QuizFormDialogState extends State<_QuizFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _chapterCtrl;
  late final TextEditingController _timeLimitCtrl;

  String? _selectedSubject;
  String? _selectedClass;
  String _difficulty = 'EASY';
  bool _shuffleQuestions = false;
  List<Map<String, dynamic>> _questions = [];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?['title'] as String? ?? '');
    _chapterCtrl =
        TextEditingController(text: e?['chapter'] as String? ?? '');
    _timeLimitCtrl = TextEditingController(
        text: '${e?['timeLimitMinutes'] as int? ?? 0}');
    _selectedSubject = e?['subject'] as String?;
    _selectedClass = e?['className'] as String?;
    _difficulty = e?['difficulty'] as String? ?? 'EASY';
    _shuffleQuestions = e?['shuffleQuestions'] as bool? ?? false;

    if (e != null && e['questions'] != null) {
      final raw = e['questions'] as List<dynamic>;
      _questions = raw.map((q) {
        final qMap = q as Map<String, dynamic>;
        final options = (qMap['options'] as List<dynamic>?)
                ?.map((o) => o.toString())
                .toList() ??
            ['', '', '', ''];
        return <String, dynamic>{
          'questionText': qMap['questionText'] as String? ?? '',
          'options': List<String>.from(options),
          'correctAnswer': qMap['correctAnswer'] as int? ?? 0,
          'marks': qMap['marks'] as int? ?? 1,
          'explanation': qMap['explanation'] as String? ?? '',
        };
      }).toList();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _chapterCtrl.dispose();
    _timeLimitCtrl.dispose();
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add({
        'questionText': '',
        'options': ['', '', '', ''],
        'correctAnswer': 0,
        'marks': 1,
        'explanation': '',
      });
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one question')),
      );
      return;
    }

    // Validate all questions have text and all options filled
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if ((q['questionText'] as String).trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Question ${i + 1} text is required')),
        );
        return;
      }
      final opts = q['options'] as List<String>;
      for (int j = 0; j < opts.length; j++) {
        if (opts[j].trim().isEmpty) {
          final label = String.fromCharCode(65 + j); // A, B, C, D
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Question ${i + 1}: Option $label is required'),
            ),
          );
          return;
        }
      }
    }

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'subject': _selectedSubject,
      'className': _selectedClass,
      'chapter': _chapterCtrl.text.trim(),
      'difficulty': _difficulty,
      'timeLimitMinutes': int.tryParse(_timeLimitCtrl.text.trim()) ?? 0,
      'shuffleQuestions': _shuffleQuestions,
      'questions': _questions.map((q) {
        return {
          'questionText': (q['questionText'] as String).trim(),
          'options':
              (q['options'] as List<String>).map((o) => o.trim()).toList(),
          'correctAnswer': q['correctAnswer'] as int,
          'marks': q['marks'] as int,
          'explanation': (q['explanation'] as String).trim(),
        };
      }).toList(),
    };

    try {
      if (_isEdit) {
        final id = widget.existing!['id'] as String;
        await QuizApiService.updateQuiz(id, data);
      } else {
        await QuizApiService.createQuiz(data);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit
                ? 'Quiz updated successfully'
                : 'Quiz created successfully'),
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save quiz: $e')),
        );
      }
    }

    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.9;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusXL),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.quiz_outlined, color: AppColors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    _isEdit ? 'Edit Quiz' : 'Create Quiz',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: AppColors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Scrollable body
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Quiz Details ──
                      Text(
                        'Quiz Details',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Title
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: _inputDecoration('Title *'),
                        style: GoogleFonts.poppins(fontSize: 14),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Subject + Class row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedSubject,
                              isExpanded: true,
                              decoration: _inputDecoration('Subject *'),
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.textPrimary),
                              items: widget.allSubjects
                                  .map((s) => DropdownMenuItem(
                                      value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedSubject = v),
                              validator: (v) =>
                                  v == null ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedClass,
                              isExpanded: true,
                              decoration: _inputDecoration('Class *'),
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.textPrimary),
                              items: SchoolConstants.baseClasses
                                  .map((c) => DropdownMenuItem(
                                      value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedClass = v),
                              validator: (v) =>
                                  v == null ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Chapter
                      TextFormField(
                        controller: _chapterCtrl,
                        decoration: _inputDecoration('Chapter (optional)'),
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      const SizedBox(height: 12),

                      // Difficulty + Time Limit row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _difficulty,
                              isExpanded: true,
                              decoration: _inputDecoration('Difficulty'),
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.textPrimary),
                              items: const [
                                DropdownMenuItem(
                                    value: 'EASY', child: Text('EASY')),
                                DropdownMenuItem(
                                    value: 'MEDIUM', child: Text('MEDIUM')),
                                DropdownMenuItem(
                                    value: 'HARD', child: Text('HARD')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _difficulty = v);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _timeLimitCtrl,
                              decoration: _inputDecoration(
                                  'Time Limit (minutes, 0=no limit)'),
                              style: GoogleFonts.poppins(fontSize: 14),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Shuffle toggle
                      SwitchListTile(
                        title: Text(
                          'Shuffle Questions',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        value: _shuffleQuestions,
                        activeColor: AppColors.gold,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) =>
                            setState(() => _shuffleQuestions = v),
                      ),

                      const Divider(height: 32),

                      // ── Questions Section ──
                      Row(
                        children: [
                          Text(
                            'Questions',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                            ),
                            onPressed: _addQuestion,
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(
                              'Add Question',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_questions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No questions added yet. Click "Add Question" to begin.',
                              style: GoogleFonts.poppins(
                                  color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                        ),

                      ..._questions.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final q = entry.value;
                        return _buildQuestionCard(idx, q);
                      }),
                    ],
                  ),
                ),
              ),
            ),

            // Save button footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child:
                        Text('Cancel', style: GoogleFonts.poppins()),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.white),
                          )
                        : Text(
                            'Save',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, Map<String, dynamic> q) {
    final options = q['options'] as List<String>;
    final correctAnswer = q['correctAnswer'] as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text(
                  'Question ${index + 1}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppColors.error, size: 20),
                  tooltip: 'Remove question',
                  onPressed: () => _removeQuestion(index),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Question text
            TextFormField(
              initialValue: q['questionText'] as String,
              decoration: _inputDecoration('Question Text *'),
              style: GoogleFonts.poppins(fontSize: 14),
              maxLines: 3,
              onChanged: (v) => q['questionText'] = v,
            ),
            const SizedBox(height: 12),

            // Options A-D
            ...List.generate(4, (oi) {
              final label = String.fromCharCode(65 + oi); // A, B, C, D
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextFormField(
                  initialValue: options[oi],
                  decoration: _inputDecoration('Option $label *'),
                  style: GoogleFonts.poppins(fontSize: 14),
                  onChanged: (v) => options[oi] = v,
                ),
              );
            }),

            const SizedBox(height: 8),

            // Correct answer radio group
            Text(
              'Correct Answer *',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            Row(
              children: List.generate(4, (oi) {
                final label = String.fromCharCode(65 + oi);
                return Expanded(
                  child: RadioListTile<int>(
                    title: Text(label,
                        style: GoogleFonts.poppins(fontSize: 13)),
                    value: oi,
                    groupValue: correctAnswer,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.gold,
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => q['correctAnswer'] = v);
                      }
                    },
                  ),
                );
              }),
            ),

            const SizedBox(height: 8),

            // Marks + Explanation row
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    initialValue: '${q['marks'] as int}',
                    decoration: _inputDecoration('Marks'),
                    style: GoogleFonts.poppins(fontSize: 14),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        q['marks'] = int.tryParse(v) ?? 1,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: q['explanation'] as String,
                    decoration:
                        _inputDecoration('Explanation (optional)'),
                    style: GoogleFonts.poppins(fontSize: 14),
                    onChanged: (v) => q['explanation'] = v,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Attempts Dialog
// ═════════════════════════════════════════════════════════════════════════════

class _AttemptsDialog extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const _AttemptsDialog({required this.quizId, required this.quizTitle});

  @override
  State<_AttemptsDialog> createState() => _AttemptsDialogState();
}

class _AttemptsDialogState extends State<_AttemptsDialog> {
  bool _loading = true;
  List<Map<String, dynamic>> _attempts = [];

  @override
  void initState() {
    super.initState();
    _loadAttempts();
  }

  Future<void> _loadAttempts() async {
    setState(() => _loading = true);
    try {
      final data = await QuizApiService.getQuizAttempts(widget.quizId);
      if (mounted) setState(() => _attempts = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load attempts: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusXL),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.people_outline,
                      color: AppColors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Attempts: ${widget.quizTitle}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: AppColors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _attempts.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              'No attempts yet.',
                              style: GoogleFonts.poppins(
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(16),
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                  AppColors.cream),
                              columns: [
                                DataColumn(
                                  label: Text('Student Name',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ),
                                DataColumn(
                                  label: Text('Score',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ),
                                DataColumn(
                                  label: Text('Percentage',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ),
                                DataColumn(
                                  label: Text('Time Taken',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ),
                                DataColumn(
                                  label: Text('Completed At',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ),
                              ],
                              rows: _attempts.map((a) {
                                final studentName =
                                    a['studentName'] as String? ?? '';
                                final score = a['score'] ?? 0;
                                final totalMarks = a['totalMarks'] ?? 0;
                                final percentage = a['percentage'] ?? 0;
                                final timeTaken =
                                    a['timeTaken'] as String? ?? '';
                                final completedAt =
                                    a['completedAt'] as String? ?? '';
                                return DataRow(cells: [
                                  DataCell(Text(studentName,
                                      style: GoogleFonts.poppins(
                                          fontSize: 13))),
                                  DataCell(Text('$score / $totalMarks',
                                      style: GoogleFonts.poppins(
                                          fontSize: 13))),
                                  DataCell(Text('$percentage%',
                                      style: GoogleFonts.poppins(
                                          fontSize: 13))),
                                  DataCell(Text(timeTaken,
                                      style: GoogleFonts.poppins(
                                          fontSize: 13))),
                                  DataCell(Text(completedAt,
                                      style: GoogleFonts.poppins(
                                          fontSize: 13))),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
            ),

            // Close button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: GoogleFonts.poppins()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
