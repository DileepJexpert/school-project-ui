import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
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

  // Remember last used values for quick re-assignment
  String? _lastUsedClass;
  String? _lastUsedSubject;

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    setState(() => _loading = true);
    try {
      final data = await HomeworkApiService.getAllHomework(
          className: _filterClass);
      if (mounted) setState(() => _homeworkList = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load homework: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Header with filter dropdown + assign button ---
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Homework Management',
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Class filter dropdown
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      value: _filterClass,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: 'All Classes',
                        prefixIcon:
                            const Icon(Icons.filter_list, size: 18),
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
                        _loadHomework();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    onPressed: () => _showFormDialog(null),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('Assign Homework',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
        // --- Homework list ---
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _homeworkList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('No homework assigned yet.',
                              style: GoogleFonts.poppins(
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHomework,
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _homeworkList.length,
                        itemBuilder: (context, index) {
                          final hw = _homeworkList[index]
                              as Map<String, dynamic>;
                          return _buildHomeworkCard(hw);
                        },
                      ),
                    ),
        ),
      ],
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

    final isDue = dueDate.isNotEmpty && DateTime.tryParse(dueDate) != null
        ? DateTime.parse(dueDate).isBefore(DateTime.now())
        : false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
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
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') _showFormDialog(hw);
                    if (val == 'delete') _deleteHomework(id);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                        value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(description,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textSecondary),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 10),
            Row(
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
                Icon(Icons.flag_outlined,
                    size: 14,
                    color: isDue ? Colors.red : Colors.orange),
                const SizedBox(width: 4),
                Text('Due: $dueDate',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDue ? Colors.red : Colors.orange)),
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
    String? selectedClass = isEdit
        ? existing['className'] as String?
        : _lastUsedClass;
    String? selectedSubject = isEdit
        ? existing['subject'] as String?
        : _lastUsedSubject;
    bool isOtherSubject = false;

    // Check if editing with a subject not in the common list
    if (selectedSubject != null &&
        !SchoolConstants.commonSubjects.contains(selectedSubject)) {
      isOtherSubject = true;
    }

    final titleCtrl = TextEditingController(
        text: existing?['title'] as String? ?? '');
    final descCtrl = TextEditingController(
        text: existing?['description'] as String? ?? '');
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

              if (selectedClass == null ||
                  actualSubject == null ||
                  actualSubject.isEmpty ||
                  titleCtrl.text.trim().isEmpty ||
                  dueDate == null) {
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
                'dueDate': _formatDate(dueDate!),
              };

              // Remember for next time
              _lastUsedClass = selectedClass;
              _lastUsedSubject = actualSubject;

              try {
                if (isEdit) {
                  await HomeworkApiService.updateHomework(
                      existing!['id'] as String, data);
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
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
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
                  style:
                      GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Class Dropdown ──
                      DropdownButtonFormField<String>(
                        value: selectedClass,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Class *',
                          prefixIcon: const Icon(Icons.school_outlined,
                              size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: SchoolConstants.allClasses
                            .map((c) => DropdownMenuItem(
                                value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedClass = v),
                      ),
                      const SizedBox(height: 12),

                      // ── Subject Dropdown ──
                      DropdownButtonFormField<String>(
                        value: isOtherSubject
                            ? 'Other'
                            : (SchoolConstants.commonSubjects
                                    .contains(selectedSubject)
                                ? selectedSubject
                                : null),
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Subject *',
                          prefixIcon: const Icon(
                              Icons.menu_book_outlined,
                              size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          ...SchoolConstants.commonSubjects.map((s) =>
                              DropdownMenuItem(
                                  value: s, child: Text(s))),
                          const DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other...')),
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
                                _formatDate(dueDate!) ==
                                    _formatDate(e.value);
                            return ChoiceChip(
                              label: Text(e.key),
                              selected: isSelected,
                              selectedColor:
                                  AppColors.navy.withOpacity(0.15),
                              labelStyle: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppColors.navy
                                    : AppColors.textSecondary,
                              ),
                              onSelected: (_) => setDialogState(
                                  () => dueDate = e.value),
                            );
                          }),
                          ActionChip(
                            avatar: const Icon(Icons.calendar_today,
                                size: 16),
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
                                initialDate: dueDate ??
                                    now.add(const Duration(days: 1)),
                                firstDate: now,
                                lastDate:
                                    now.add(const Duration(days: 365)),
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
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600)),
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
        content:
            const Text('Are you sure you want to delete this homework?'),
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
        await HomeworkApiService.deleteHomework(id);
        _loadHomework();
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
