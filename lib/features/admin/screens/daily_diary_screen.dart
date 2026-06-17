import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/daily_diary_api_service.dart';

class DailyDiaryScreen extends StatefulWidget {
  const DailyDiaryScreen({super.key});

  @override
  State<DailyDiaryScreen> createState() => _DailyDiaryScreenState();
}

class _DailyDiaryScreenState extends State<DailyDiaryScreen> {
  bool _loading = true;
  List<dynamic> _entries = [];
  String? _filterClass;
  DateTime _selectedDate = DateTime.now();

  static final List<String> _allSubjects = [
    ...SchoolConstants.commonSubjects,
    'Physics',
    'Chemistry',
    'Biology',
    'History',
    'Geography',
    'Economics',
  ];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    try {
      final data = await DailyDiaryApiService.getAllEntries(
        className: _filterClass,
      );
      // Filter by selected date client-side
      final dateStr = _formatDate(_selectedDate);
      final filtered = data.where((e) {
        final entryDate = (e as Map<String, dynamic>)['date'] as String? ?? '';
        return entryDate.startsWith(dateStr);
      }).toList();
      // Sort newest first
      filtered.sort((a, b) {
        final da = (a as Map<String, dynamic>)['date'] as String? ?? '';
        final db = (b as Map<String, dynamic>)['date'] as String? ?? '';
        return db.compareTo(da);
      });
      if (mounted) setState(() => _entries = filtered);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load diary entries: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadEntries();
    }
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
              Text('Daily Diary',
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date picker button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_displayDate(_selectedDate),
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(width: 12),
                  // Class filter dropdown
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      value: _filterClass,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: 'All Classes',
                        prefixIcon: const Icon(Icons.filter_list, size: 18),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Classes'),
                        ),
                        ...SchoolConstants.allClasses.map((c) =>
                            DropdownMenuItem(value: c, child: Text(c))),
                      ],
                      onChanged: (v) {
                        setState(() => _filterClass = v);
                        _loadEntries();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    onPressed: () => _showFormDialog(null),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('Add Entry',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
        // --- Entry list ---
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _entries.isEmpty
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
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          final entry =
                              _entries[index] as Map<String, dynamic>;
                          return _buildEntryCard(entry);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry) {
    final title = entry['title'] as String? ?? '';
    final content = entry['content'] as String? ?? '';
    final className = entry['className'] as String? ?? '';
    final subject = entry['subject'] as String? ?? '';
    final teacherName = entry['teacherName'] as String? ?? '';
    final date = entry['date'] as String? ?? '';
    final homework = entry['homeworkGiven'] as String? ?? '';
    final id = (entry['id'] ?? entry['_id']) as String? ?? '';

    // Parse date for display
    String dateDisplay = date;
    final parsed = DateTime.tryParse(date);
    if (parsed != null) {
      dateDisplay = _displayDate(parsed);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Subject chip (teal)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(subject,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0D9488))),
                ),
                const SizedBox(width: 8),
                // Class chip (navy)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.navy.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(className,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy)),
                ),
                const Spacer(),
                // Date badge (top-right)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.goldPale,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(dateDisplay,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Title
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(content,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            // Homework section (orange left border)
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
            const SizedBox(height: 10),
            // Teacher name + action buttons
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(teacherName,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary)),
                const Spacer(),
                // Edit button (navy)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: () => _showFormDialog(entry),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text('Edit',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 4),
                // Delete button (red)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: () => _deleteEntry(id),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text('Delete',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Form Dialog (Add / Edit) ───

  void _showFormDialog(Map<String, dynamic>? existing) {
    final isEdit = existing != null;

    String? selectedClass = existing?['className'] as String?;
    String? selectedSubject = existing?['subject'] as String?;

    final titleCtrl =
        TextEditingController(text: existing?['title'] as String? ?? '');
    final contentCtrl =
        TextEditingController(text: existing?['content'] as String? ?? '');
    final sectionCtrl =
        TextEditingController(text: existing?['section'] as String? ?? '');
    final homeworkCtrl = TextEditingController(
        text: existing?['homeworkGiven'] as String? ?? '');
    final academicYearCtrl = TextEditingController(
        text: existing?['academicYear'] as String? ?? '2024-25');

    DateTime entryDate = _selectedDate;
    final existingDate = existing?['date'] as String? ?? '';
    if (existingDate.isNotEmpty) {
      final parsed = DateTime.tryParse(existingDate);
      if (parsed != null) entryDate = parsed;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> submit() async {
              if (selectedClass == null ||
                  selectedSubject == null ||
                  titleCtrl.text.trim().isEmpty ||
                  contentCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please fill all required fields')),
                );
                return;
              }

              final data = <String, dynamic>{
                'date': _formatDate(entryDate),
                'className': selectedClass,
                'subject': selectedSubject,
                'title': titleCtrl.text.trim(),
                'content': contentCtrl.text.trim(),
                'academicYear': academicYearCtrl.text.trim(),
              };

              final section = sectionCtrl.text.trim();
              if (section.isNotEmpty) data['section'] = section;

              final hw = homeworkCtrl.text.trim();
              if (hw.isNotEmpty) data['homeworkGiven'] = hw;

              try {
                if (isEdit) {
                  final id =
                      (existing['id'] ?? existing['_id']) as String? ?? '';
                  await DailyDiaryApiService.update(id, data);
                } else {
                  await DailyDiaryApiService.create(data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadEntries();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(isEdit
                            ? 'Entry updated'
                            : 'Entry created successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            }

            return AlertDialog(
              title: Text(isEdit ? 'Edit Diary Entry' : 'Add Diary Entry',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Date Picker ──
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: entryDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => entryDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date *',
                            prefixIcon: const Icon(
                                Icons.calendar_today,
                                size: 18),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(_displayDate(entryDate),
                              style: GoogleFonts.poppins(fontSize: 14)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Class Dropdown ──
                      DropdownButtonFormField<String>(
                        value: selectedClass,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Class *',
                          prefixIcon:
                              const Icon(Icons.school_outlined, size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: SchoolConstants.allClasses
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedClass = v),
                      ),
                      const SizedBox(height: 12),

                      // ── Section (optional) ──
                      TextField(
                        controller: sectionCtrl,
                        decoration: InputDecoration(
                          labelText: 'Section (optional)',
                          prefixIcon:
                              const Icon(Icons.group_outlined, size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Subject Dropdown ──
                      DropdownButtonFormField<String>(
                        value: _allSubjects.contains(selectedSubject)
                            ? selectedSubject
                            : null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Subject *',
                          prefixIcon:
                              const Icon(Icons.menu_book_outlined, size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: _allSubjects
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedSubject = v),
                      ),
                      const SizedBox(height: 12),

                      // ── Title ──
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Title *',
                          hintText: 'e.g. Chapter 5 - Photosynthesis',
                          prefixIcon: const Icon(Icons.title, size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Content (multiline, 5 lines) ──
                      TextField(
                        controller: contentCtrl,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Content *',
                          hintText: 'What was covered in class today...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Homework Given (optional, 3 lines) ──
                      TextField(
                        controller: homeworkCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Homework Given (optional)',
                          hintText: 'Any homework assigned...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Academic Year ──
                      TextField(
                        controller: academicYearCtrl,
                        decoration: InputDecoration(
                          labelText: 'Academic Year',
                          hintText: '2024-25',
                          prefixIcon: const Icon(
                              Icons.date_range_outlined,
                              size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => submit(),
                  child: Text(isEdit ? 'Update' : 'Create',
                      style:
                          GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEntry(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text(
            'Are you sure you want to delete this diary entry?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await DailyDiaryApiService.delete(id);
        _loadEntries();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entry deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }
}
