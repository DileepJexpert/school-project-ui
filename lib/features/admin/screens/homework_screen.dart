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
  String _filterClass = '';

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    setState(() => _loading = true);
    try {
      final data = await HomeworkApiService.getAllHomework(
          className: _filterClass.isNotEmpty ? _filterClass : null);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text('Homework Management',
                    style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy)),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Filter by class...',
                    prefixIcon: const Icon(Icons.filter_list, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    isDense: true,
                  ),
                  onSubmitted: (v) {
                    setState(() => _filterClass = v.trim());
                    _loadHomework();
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onPressed: () => _showAddDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Assign Homework',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _homeworkList.length,
                        itemBuilder: (context, index) {
                          final hw =
                              _homeworkList[index] as Map<String, dynamic>;
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
    final status = hw['status'] as String? ?? 'ACTIVE';
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
                const SizedBox(width: 8),
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
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') _showEditDialog(hw);
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

  void _showAddDialog() {
    _showFormDialog(null);
  }

  void _showEditDialog(Map<String, dynamic> hw) {
    _showFormDialog(hw);
  }

  void _showFormDialog(Map<String, dynamic>? existing) {
    final isEdit = existing != null;
    final classCtrl =
        TextEditingController(text: existing?['className'] as String? ?? '');
    final subjectCtrl =
        TextEditingController(text: existing?['subject'] as String? ?? '');
    final titleCtrl =
        TextEditingController(text: existing?['title'] as String? ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description'] as String? ?? '');
    DateTime? dueDate;
    final dueDateStr = existing?['dueDate'] as String? ?? '';
    if (dueDateStr.isNotEmpty) {
      dueDate = DateTime.tryParse(dueDateStr);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Homework' : 'Assign Homework',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: classCtrl,
                        decoration: InputDecoration(
                          labelText: 'Class *',
                          hintText: 'e.g. 5A, 10B',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: subjectCtrl,
                        decoration: InputDecoration(
                          labelText: 'Subject *',
                          hintText: 'e.g. Mathematics, English',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Title *',
                          hintText: 'e.g. Chapter 5 Exercise',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          hintText: 'Detailed instructions for students...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: dueDate ?? DateTime.now().add(
                                const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                                const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => dueDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Due Date *',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            suffixIcon:
                                const Icon(Icons.calendar_today, size: 18),
                          ),
                          child: Text(
                            dueDate != null
                                ? '${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}'
                                : 'Select due date',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: dueDate != null
                                    ? Colors.black87
                                    : AppColors.textSecondary),
                          ),
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
                  onPressed: () async {
                    if (classCtrl.text.trim().isEmpty ||
                        subjectCtrl.text.trim().isEmpty ||
                        titleCtrl.text.trim().isEmpty ||
                        dueDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Please fill all required fields')),
                      );
                      return;
                    }

                    final data = {
                      'className': classCtrl.text.trim(),
                      'subject': subjectCtrl.text.trim(),
                      'title': titleCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'dueDate':
                          '${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
                    };

                    Navigator.pop(ctx);

                    try {
                      if (isEdit) {
                        await HomeworkApiService.updateHomework(
                            existing!['id'] as String, data);
                      } else {
                        await HomeworkApiService.createHomework(data);
                      }
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
                  },
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
