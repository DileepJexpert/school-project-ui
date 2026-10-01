import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/searchable_dropdown.dart';
import '../../../services/homework_api_service.dart';

class HomeworkScreen extends StatefulWidget {
  const HomeworkScreen({super.key});

  @override
  State<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends State<HomeworkScreen> {
  bool _loading = true;
  List<dynamic> _homeworkList = [];
  String? _filterClass;
  String _searchQuery = '';
  String? _error;

  // Remember last used values for quick re-assignment
  String? _lastUsedClass;
  String? _lastUsedSubject;

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await HomeworkApiService.getAllHomework(className: _filterClass);
      if (mounted) setState(() => _homeworkList = data);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Homework could not be loaded right now.');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isOverdue(String value) {
    final date = DateTime.tryParse(value);
    return date != null && date.isBefore(DateTime.now());
  }

  List<Map<String, dynamic>> get _visibleHomework {
    final query = _searchQuery.trim().toLowerCase();
    return _homeworkList.whereType<Map<String, dynamic>>().where((hw) {
      if (query.isEmpty) return true;
      final text = [
        hw['title'],
        hw['description'],
        hw['subject'],
        hw['teacherName']
      ].whereType<String>().join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final visibleHomework = _visibleHomework;
    final overdueCount = visibleHomework
        .where((hw) => _isOverdue(hw['dueDate'] as String? ?? ''))
        .length;
    final dueSoonCount = visibleHomework.where((hw) {
      final date = DateTime.tryParse(hw['dueDate'] as String? ?? '');
      if (date == null || _isOverdue(hw['dueDate'] as String? ?? ''))
        return false;
      return date.difference(DateTime.now()).inDays <= 7;
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(Responsive.contentPadding(context), 22,
              Responsive.contentPadding(context), 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Homework',
                            style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: palette.brand)),
                        const SizedBox(height: 4),
                        Text(
                            'Assign work, track due dates, and keep every class on schedule.',
                            style: GoogleFonts.nunitoSans(
                                fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _showFormDialog(null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Assign Homework'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: Responsive.isMobile(context) ? double.infinity : 220,
                    child: SearchableDropdownFormField<String>(
                      initialValue: _filterClass ?? 'All Classes',
                      hintText: 'All Classes',
                      items: ['All Classes', ...SchoolConstants.allClasses],
                      onChanged: (v) {
                        setState(() => _filterClass =
                            (v == null || v == 'All Classes') ? null : v);
                        _loadHomework();
                      },
                    ),
                  ),
                  SizedBox(
                    width: Responsive.isMobile(context) ? double.infinity : 280,
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: const InputDecoration(
                        hintText: 'Search homework or subject',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh homework',
                    onPressed: _loading ? null : _loadHomework,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _summaryPill(Icons.menu_book_outlined,
                      '${visibleHomework.length} total', palette.brand),
                  _summaryPill(Icons.schedule_rounded,
                      '$dueSoonCount due this week', palette.accent),
                  _summaryPill(Icons.warning_amber_rounded,
                      '$overdueCount overdue', AppColors.error),
                ],
              ),
            ],
          ),
        ),
        // --- Homework list ---
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorState(palette)
                  : visibleHomework.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.menu_book_outlined,
                                  size: 52,
                                  color: palette.brand.withValues(alpha: 0.25)),
                              const SizedBox(height: 12),
                              Text(
                                  _searchQuery.isEmpty
                                      ? 'No homework assigned yet'
                                      : 'No homework matches your search',
                                  style: GoogleFonts.poppins(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(
                                  _searchQuery.isEmpty
                                      ? 'Assign the first task for a class to get started.'
                                      : 'Try a different title, subject, or teacher name.',
                                  style: GoogleFonts.nunitoSans(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () => _showFormDialog(null),
                                  icon: const Icon(Icons.add, size: 17),
                                  label: const Text('Assign Homework'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadHomework,
                          child: ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                                Responsive.contentPadding(context),
                                4,
                                Responsive.contentPadding(context),
                                24),
                            itemCount: visibleHomework.length,
                            itemBuilder: (context, index) {
                              return _buildHomeworkCard(visibleHomework[index]);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _summaryPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Text(text,
            style: GoogleFonts.nunitoSans(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _buildErrorState(AppThemePalette palette) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded,
              size: 42, color: AppColors.error.withValues(alpha: 0.8)),
          const SizedBox(height: 12),
          Text('Could not load homework',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.brand)),
          const SizedBox(height: 5),
          Text('$_error Please retry in a moment.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: _loadHomework,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Retry')),
        ]),
      ),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> hw) {
    final title = hw['title'] as String? ?? '';
    final description = hw['description'] as String? ?? '';
    final className = hw['className'] as String? ?? '';
    final subject = hw['subject'] as String? ?? '';
    final teacherName = hw['teacherName'] as String? ?? '';
    final dueDate = hw['dueDate'] as String? ?? '';
    final assignedDate = hw['assignedDate'] as String? ?? '';
    final id = hw['id'] as String? ?? '';
    final palette = context.palette;
    final isDue = _isOverdue(dueDate);
    final parsedDueDate = DateTime.tryParse(dueDate);
    final isDueSoon = parsedDueDate != null &&
        !isDue &&
        parsedDueDate.difference(DateTime.now()).inDays <= 7;
    final dueColor = isDue ? AppColors.error : palette.accent;
    final dueLabel = isDue ? 'Overdue' : (isDueSoon ? 'Due soon' : 'Scheduled');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: palette.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.menu_book_rounded,
                      color: palette.brand, size: 20),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(className,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: palette.brand)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(subject,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0D9488))),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') _showFormDialog(hw);
                    if (val == 'delete') _deleteHomework(id);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.brand)),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(description,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textSecondary),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.person_outline,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(teacherName,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 16),
                Icon(Icons.calendar_today,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('Assigned: $assignedDate',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 16),
                Icon(Icons.flag_outlined, size: 14, color: dueColor),
                const SizedBox(width: 4),
                Text('$dueLabel · $dueDate',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: dueColor)),
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

    // For add: pre-fill with last used values; for edit: use existing values
    String? selectedClass =
        isEdit ? existing['className'] as String? : _lastUsedClass;
    String? selectedSubject =
        isEdit ? existing['subject'] as String? : _lastUsedSubject;
    bool isOtherSubject = false;

    // Check if editing with a subject not in the common list
    if (selectedSubject != null &&
        !SchoolConstants.commonSubjects.contains(selectedSubject)) {
      isOtherSubject = true;
    }

    final titleCtrl =
        TextEditingController(text: existing?['title'] as String? ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description'] as String? ?? '');
    final otherSubjectCtrl = TextEditingController(
        text: isOtherSubject ? selectedSubject ?? '' : '');

    DateTime? dueDate;
    final dueDateStr = existing?['dueDate'] as String? ?? '';
    if (dueDateStr.isNotEmpty) {
      dueDate = DateTime.tryParse(dueDateStr);
    }

    // Quick date chip labels and offsets
    final now = DateTime.now();
    final quickDates = <String, DateTime>{
      'Tomorrow': now.add(const Duration(days: 1)),
      'In 2 Days': now.add(const Duration(days: 2)),
      'Next Week': now.add(const Duration(days: 7)),
    };

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> submit({bool addAnother = false}) async {
              final actualSubject = isOtherSubject
                  ? otherSubjectCtrl.text.trim()
                  : selectedSubject;
              final currentDueDate = dueDate;

              if (selectedClass == null ||
                  actualSubject == null ||
                  actualSubject.isEmpty ||
                  titleCtrl.text.trim().isEmpty ||
                  currentDueDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please fill all required fields')),
                );
                return;
              }

              final data = {
                'className': selectedClass,
                'subject': actualSubject,
                'title': titleCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'dueDate': _formatDate(currentDueDate),
              };

              // Remember for next time
              _lastUsedClass = selectedClass;
              _lastUsedSubject = actualSubject;

              try {
                if (existing != null) {
                  await HomeworkApiService.updateHomework(
                      existing['id'] as String, data);
                } else {
                  await HomeworkApiService.createHomework(data);
                }
                if (!addAnother && ctx.mounted) Navigator.pop(ctx);
                _loadHomework();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(isEdit
                            ? 'Homework updated'
                            : 'Homework assigned successfully')),
                  );
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Homework could not be saved. Please retry.')),
                  );
                }
              }

              // If "Add Another", clear title/desc/date but keep class+subject
              if (addAnother) {
                setDialogState(() {
                  titleCtrl.clear();
                  descCtrl.clear();
                  dueDate = null;
                });
              }
            }

            return AlertDialog(
              title: Text(isEdit ? 'Edit Homework' : 'Assign Homework',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Class Dropdown ──
                      SearchableDropdownFormField<String>(
                        initialValue: selectedClass,
                        labelText: 'Class *',
                        hintText: 'Select or type class…',
                        items: SchoolConstants.allClasses,
                        onChanged: (v) =>
                            setDialogState(() => selectedClass = v),
                      ),
                      const SizedBox(height: 12),

                      // ── Subject Dropdown ──
                      SearchableDropdownFormField<String>(
                        initialValue: isOtherSubject
                            ? 'Other'
                            : (SchoolConstants.commonSubjects
                                    .contains(selectedSubject)
                                ? selectedSubject
                                : null),
                        labelText: 'Subject *',
                        hintText: 'Select or type subject…',
                        items: [
                          ...SchoolConstants.commonSubjects,
                          'Other',
                        ],
                        onChanged: (v) {
                          setDialogState(() {
                            if (v == 'Other') {
                              isOtherSubject = true;
                              selectedSubject = null;
                            } else {
                              isOtherSubject = false;
                              selectedSubject = v;
                            }
                          });
                        },
                      ),
                      if (isOtherSubject) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: otherSubjectCtrl,
                          decoration: InputDecoration(
                            hintText: 'Type subject name',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // ── Title ──
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Title *',
                          hintText: 'e.g. Chapter 5 Exercise',
                          prefixIcon: const Icon(Icons.title, size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Description (optional) ──
                      TextField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Description (optional)',
                          hintText: 'Instructions for students...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Quick Due Date Chips ──
                      Text('Due Date *',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...quickDates.entries.map((e) {
                            final isSelected = dueDate != null &&
                                _formatDate(dueDate!) == _formatDate(e.value);
                            return ChoiceChip(
                              label: Text(e.key),
                              selected: isSelected,
                              selectedColor:
                                  AppColors.navy.withValues(alpha: 0.15),
                              labelStyle: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppColors.navy
                                    : AppColors.textSecondary,
                              ),
                              onSelected: (_) =>
                                  setDialogState(() => dueDate = e.value),
                            );
                          }),
                          ActionChip(
                            avatar: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              dueDate != null &&
                                      !quickDates.values.any((qd) =>
                                          _formatDate(qd) ==
                                          _formatDate(dueDate!))
                                  ? _formatDate(dueDate!)
                                  : 'Custom...',
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate:
                                    dueDate ?? now.add(const Duration(days: 1)),
                                firstDate: now,
                                lastDate: now.add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setDialogState(() => dueDate = picked);
                              }
                            },
                          ),
                        ],
                      ),

                      if (dueDate != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Due: ${_formatDate(dueDate!)}',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                if (!isEdit)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: AppColors.navy),
                    ),
                    onPressed: () => submit(addAnother: true),
                    child: Text('Assign & Add Another',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => submit(),
                  child: Text(isEdit ? 'Update' : 'Assign',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteHomework(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Homework'),
        content: const Text('Are you sure you want to delete this homework?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await HomeworkApiService.deleteHomework(id);
        _loadHomework();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Homework could not be deleted. Please retry.')),
          );
        }
      }
    }
  }
}
