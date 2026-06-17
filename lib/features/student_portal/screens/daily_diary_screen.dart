import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/daily_diary_api_service.dart';

class StudentDailyDiaryScreen extends StatefulWidget {
  const StudentDailyDiaryScreen({super.key});

  @override
  State<StudentDailyDiaryScreen> createState() =>
      _StudentDailyDiaryScreenState();
}

class _StudentDailyDiaryScreenState extends State<StudentDailyDiaryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _entries = [];
  DateTime _selectedDate = DateTime.now();
  String _selectedSubject = 'All';

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = [
      '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
    ];
    return '${days[d.weekday]}, ${d.day} ${months[d.month]} ${d.year}';
  }

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    try {
      final data = await DailyDiaryApiService.getMyDiary(
        date: _formatDate(_selectedDate),
      );
      if (mounted) {
        setState(() {
          _entries = data
              .map((e) => e as Map<String, dynamic>)
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load diary: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  List<String> get _availableSubjects {
    final subjects = _entries
        .map((e) => e['subject'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...subjects];
  }

  List<Map<String, dynamic>> get _filteredEntries {
    if (_selectedSubject == 'All') return _entries;
    return _entries
        .where((e) => e['subject'] == _selectedSubject)
        .toList();
  }

  void _goToPreviousDay() {
    setState(() =>
        _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
    _selectedSubject = 'All';
    _loadEntries();
  }

  void _goToNextDay() {
    setState(
        () => _selectedDate = _selectedDate.add(const Duration(days: 1)));
    _selectedSubject = 'All';
    _loadEntries();
  }

  void _goToToday() {
    setState(() => _selectedDate = DateTime.now());
    _selectedSubject = 'All';
    _loadEntries();
  }

  IconData _subjectIcon(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':
        return Icons.calculate_outlined;
      case 'english':
        return Icons.abc;
      case 'hindi':
      case 'sanskrit':
        return Icons.translate;
      case 'science':
      case 'physics':
      case 'chemistry':
      case 'biology':
        return Icons.science_outlined;
      case 'social studies':
      case 'history':
      case 'geography':
        return Icons.public_outlined;
      case 'computer science':
        return Icons.computer_outlined;
      case 'physical education':
        return Icons.sports_soccer_outlined;
      case 'art':
        return Icons.palette_outlined;
      case 'music':
        return Icons.music_note_outlined;
      case 'economics':
        return Icons.trending_up_outlined;
      default:
        return Icons.menu_book_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries;

    return Column(
      children: [
        // ── Date navigation ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: _goToPreviousDay,
                icon: const Icon(Icons.chevron_left),
                color: AppColors.navy,
                tooltip: 'Previous day',
              ),
              Expanded(
                child: Text(
                  _displayDate(_selectedDate),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
              ),
              IconButton(
                onPressed: _goToNextDay,
                icon: const Icon(Icons.chevron_right),
                color: AppColors.navy,
                tooltip: 'Next day',
              ),
              const SizedBox(width: 4),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: _goToToday,
                child: Text('Today',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),

        // ── Subject filter chips ──
        if (!_loading && _entries.isNotEmpty)
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _availableSubjects.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final subject = _availableSubjects[index];
                final isSelected = _selectedSubject == subject;
                return ChoiceChip(
                  label: Text(subject),
                  selected: isSelected,
                  selectedColor: AppColors.navy.withOpacity(0.15),
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color:
                        isSelected ? AppColors.navy : AppColors.textSecondary,
                  ),
                  onSelected: (_) =>
                      setState(() => _selectedSubject = subject),
                );
              },
            ),
          ),

        const SizedBox(height: 8),

        // ── Content ──
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_stories_outlined,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('No diary entries for this date',
                              style: GoogleFonts.poppins(
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadEntries,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            _buildEntryCard(filtered[index]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry) {
    final subject = entry['subject'] as String? ?? '';
    final title = entry['title'] as String? ?? '';
    final content = entry['content'] as String? ?? '';
    final homework = entry['homeworkGiven'] as String? ?? '';
    final teacherName = entry['teacherName'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject name with icon
            Row(
              children: [
                Icon(_subjectIcon(subject),
                    size: 20, color: AppColors.navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(subject,
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Title
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(content,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
            // Homework section
            if (homework.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                        color: Colors.orange.shade600, width: 3),
                  ),
                  color: Colors.orange.shade50,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Homework:',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800)),
                    const SizedBox(height: 2),
                    Text(homework,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.orange.shade900)),
                  ],
                ),
              ),
            ],
            // Teacher name (bottom right)
            if (teacherName.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline,
                        size: 14, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Text(teacherName,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textLight)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
