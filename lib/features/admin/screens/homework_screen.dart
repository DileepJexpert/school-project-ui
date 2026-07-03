import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/homework_api_service.dart';

class HomeworkScreen extends StatefulWidget {
  const HomeworkScreen({super.key});

  @override
  State<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends State<HomeworkScreen> {
  final _searchCtrl = TextEditingController();
  final _displayDate = DateFormat('dd MMM yyyy');

  bool _loading = true;
  String? _error;
  String? _filterClass;
  String? _filterSubject;
  String? _lastUsedClass;
  String? _lastUsedSubject;
  List<Map<String, dynamic>> _homework = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _loadHomework();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visible {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _homework.where((item) {
      final subject = _text(item, 'subject');
      final searchable = [
        _text(item, 'title'),
        _text(item, 'description'),
        _text(item, 'className'),
        subject,
        _text(item, 'teacherName'),
      ].join(' ').toLowerCase();
      return (_filterSubject == null || subject == _filterSubject) &&
          (query.isEmpty || searchable.contains(query));
    }).toList();

    filtered.sort((a, b) {
      final aDate = _parseDate(_text(a, 'dueDate'));
      final bDate = _parseDate(_text(b, 'dueDate'));
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return filtered;
  }

  List<String> get _subjects {
    final values = {
      ...SchoolConstants.commonSubjects,
      ..._homework
          .map((item) => _text(item, 'subject'))
          .where((s) => s.isNotEmpty),
    }.toList()
      ..sort();
    return values;
  }

  int get _overdueCount => _homework.where(_isOverdue).length;
  int get _dueSoonCount => _homework.where(_isDueSoon).length;
  int get _classCount => _homework
      .map((item) => _text(item, 'className'))
      .where((c) => c.isNotEmpty)
      .toSet()
      .length;

  Future<void> _loadHomework() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data =
          await HomeworkApiService.getAllHomework(className: _filterClass);
      if (!mounted) return;
      setState(() {
        _homework = data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showFormDialog(Map<String, dynamic>? existing) async {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final titleCtrl =
        TextEditingController(text: isEdit ? _text(existing, 'title') : '');
    final descriptionCtrl = TextEditingController(
      text: isEdit ? _text(existing, 'description') : '',
    );
    final customSubjectCtrl = TextEditingController();

    String? selectedClass =
        isEdit ? _text(existing, 'className') : _lastUsedClass;
    String? selectedSubject =
        isEdit ? _text(existing, 'subject') : _lastUsedSubject;
    bool customSubject = selectedSubject != null &&
        selectedSubject.isNotEmpty &&
        !SchoolConstants.commonSubjects.contains(selectedSubject);
    if (customSubject) customSubjectCtrl.text = selectedSubject;
    DateTime? dueDate = isEdit ? _parseDate(_text(existing, 'dueDate')) : null;
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> submit({bool addAnother = false}) async {
              if (!formKey.currentState!.validate()) return;
              if (dueDate == null) {
                _snack('Please select a due date.', isError: true);
                return;
              }

              final subject = customSubject
                  ? customSubjectCtrl.text.trim()
                  : selectedSubject?.trim();
              if (subject == null || subject.isEmpty) {
                _snack('Please select a subject.', isError: true);
                return;
              }

              setDialogState(() => saving = true);
              final payload = {
                'className': selectedClass,
                'subject': subject,
                'title': titleCtrl.text.trim(),
                'description': descriptionCtrl.text.trim(),
                'dueDate': _apiDate(dueDate!),
              };

              try {
                if (isEdit) {
                  await HomeworkApiService.updateHomework(
                    _text(existing, 'id'),
                    payload,
                  );
                } else {
                  await HomeworkApiService.createHomework(payload);
                }

                _lastUsedClass = selectedClass;
                _lastUsedSubject = subject;
                await _loadHomework();
                if (!mounted) return;
                _snack(isEdit ? 'Homework updated.' : 'Homework assigned.');

                if (addAnother) {
                  setDialogState(() {
                    titleCtrl.clear();
                    descriptionCtrl.clear();
                    dueDate = null;
                    saving = false;
                  });
                } else if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              } catch (e) {
                if (mounted) {
                  _snack('Could not save homework: $e', isError: true);
                }
                setDialogState(() => saving = false);
              }
            }

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
              contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              actionsPadding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
              title: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: context.palette.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.assignment_outlined,
                      color: context.palette.brand,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit homework' : 'Assign homework',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 640,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 560;
                            final width = compact
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 10) / 2;
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                SizedBox(
                                  width: width,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: selectedClass,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Class',
                                      prefixIcon: Icon(
                                        Icons.school_outlined,
                                        size: 19,
                                      ),
                                    ),
                                    items: SchoolConstants.allClasses
                                        .map(
                                          (item) => DropdownMenuItem(
                                            value: item,
                                            child: Text(item),
                                          ),
                                        )
                                        .toList(),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'Select class'
                                            : null,
                                    onChanged: (value) => setDialogState(
                                      () => selectedClass = value,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: customSubject
                                        ? 'Other'
                                        : selectedSubject,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Subject',
                                      prefixIcon: Icon(
                                        Icons.menu_book_outlined,
                                        size: 19,
                                      ),
                                    ),
                                    items: [
                                      ...SchoolConstants.commonSubjects.map(
                                        (item) => DropdownMenuItem(
                                          value: item,
                                          child: Text(item),
                                        ),
                                      ),
                                      const DropdownMenuItem(
                                        value: 'Other',
                                        child: Text('Other'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setDialogState(() {
                                        customSubject = value == 'Other';
                                        selectedSubject =
                                            customSubject ? null : value;
                                      });
                                    },
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'Select subject'
                                            : null,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        if (customSubject) ...[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: customSubjectCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Custom subject',
                            ),
                            validator: (value) {
                              if (!customSubject) return null;
                              return value == null || value.trim().isEmpty
                                  ? 'Enter subject'
                                  : null;
                            },
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Homework title',
                            hintText: 'Example: Chapter 5 exercises',
                            prefixIcon: Icon(Icons.title_rounded, size: 19),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter title'
                                  : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: descriptionCtrl,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Instructions',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Due date',
                          style: GoogleFonts.nunitoSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final option in _quickDates())
                              ChoiceChip(
                                selected: dueDate != null &&
                                    _sameDate(dueDate!, option.date),
                                label: Text(option.label),
                                onSelected: (_) => setDialogState(
                                  () => dueDate = option.date,
                                ),
                              ),
                            ActionChip(
                              avatar: const Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                              ),
                              label: Text(
                                dueDate == null
                                    ? 'Pick date'
                                    : _displayDate.format(dueDate!),
                              ),
                              onPressed: () async {
                                final picked = await _pickDueDate(dueDate);
                                if (picked != null) {
                                  setDialogState(() => dueDate = picked);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                if (!isEdit)
                  OutlinedButton(
                    onPressed: saving ? null : () => submit(addAnother: true),
                    child: const Text('Assign and add another'),
                  ),
                ElevatedButton.icon(
                  onPressed: saving ? null : submit,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(saving
                      ? 'Saving...'
                      : isEdit
                          ? 'Update'
                          : 'Assign'),
                ),
              ],
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    descriptionCtrl.dispose();
    customSubjectCtrl.dispose();
  }

  Future<DateTime?> _pickDueDate(DateTime? current) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: current ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: context.palette.brand,
                surface: context.palette.surface,
              ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
            child: child!,
          ),
        ),
      ),
    );
  }

  Future<void> _deleteHomework(Map<String, dynamic> homework) async {
    final id = _text(homework, 'id');
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete homework'),
        content: Text('Delete "${_text(homework, 'title')}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await HomeworkApiService.deleteHomework(id);
      await _loadHomework();
      _snack('Homework deleted.');
    } catch (e) {
      _snack('Could not delete homework: $e', isError: true);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.contentPadding(context);

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          _buildMetrics(),
          const SizedBox(height: 14),
          _buildToolbar(),
          const SizedBox(height: 12),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Homework',
                style: GoogleFonts.nunitoSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Plan assignments, track due work, and keep class workload visible.',
                style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _loading ? null : _loadHomework,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _showFormDialog(null),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Assign'),
        ),
      ],
    );
  }

  Widget _buildMetrics() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 780;
        final width = compact
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 30) / 4;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricCard(
              width: width,
              label: 'Assignments',
              value: _homework.length.toString(),
              icon: Icons.assignment_outlined,
              color: context.palette.brand,
            ),
            _MetricCard(
              width: width,
              label: 'Overdue',
              value: _overdueCount.toString(),
              icon: Icons.warning_amber_rounded,
              color: AppColors.error,
            ),
            _MetricCard(
              width: width,
              label: 'Due in 3 days',
              value: _dueSoonCount.toString(),
              icon: Icons.event_available_outlined,
              color: AppColors.warning,
            ),
            _MetricCard(
              width: width,
              label: 'Classes',
              value: _classCount.toString(),
              icon: Icons.groups_outlined,
              color: AppColors.success,
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 800;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? constraints.maxWidth : 340,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search title, subject, class...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                ),
              ),
              SizedBox(
                width: compact ? (constraints.maxWidth - 10) / 2 : 190,
                child: DropdownButtonFormField<String>(
                  initialValue: _filterClass,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All classes'),
                    ),
                    ...SchoolConstants.allClasses.map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _filterClass = value);
                    _loadHomework();
                  },
                ),
              ),
              SizedBox(
                width: compact ? (constraints.maxWidth - 10) / 2 : 190,
                child: DropdownButtonFormField<String>(
                  initialValue: _filterSubject,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All subjects'),
                    ),
                    ..._subjects.map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _filterSubject = value),
                ),
              ),
              if (_searchCtrl.text.isNotEmpty ||
                  _filterClass != null ||
                  _filterSubject != null)
                TextButton.icon(
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _filterClass = null;
                      _filterSubject = null;
                    });
                    _loadHomework();
                  },
                  icon: const Icon(Icons.close_rounded, size: 17),
                  label: const Text('Clear'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _StateCard(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load homework',
        subtitle: _error!,
        actionLabel: 'Retry',
        onAction: _loadHomework,
      );
    }

    final visible = _visible;
    if (visible.isEmpty) {
      return _StateCard(
        icon: Icons.assignment_outlined,
        title: 'No homework found',
        subtitle: 'Use filters differently or assign homework for a class.',
        actionLabel: 'Assign homework',
        onAction: () => _showFormDialog(null),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHomework,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _HomeworkRow(
          homework: visible[index],
          dueLabel: _dueLabel(visible[index]),
          dueColor: _dueColor(visible[index]),
          displayDate: _displayDate,
          onEdit: () => _showFormDialog(visible[index]),
          onDelete: () => _deleteHomework(visible[index]),
        ),
      ),
    );
  }

  bool _isOverdue(Map<String, dynamic> item) {
    final due = _parseDate(_text(item, 'dueDate'));
    if (due == null) return false;
    return DateUtils.dateOnly(due).isBefore(DateUtils.dateOnly(DateTime.now()));
  }

  bool _isDueSoon(Map<String, dynamic> item) {
    final due = _parseDate(_text(item, 'dueDate'));
    if (due == null) return false;
    final days = DateUtils.dateOnly(due)
        .difference(DateUtils.dateOnly(DateTime.now()))
        .inDays;
    return days >= 0 && days <= 3;
  }

  String _dueLabel(Map<String, dynamic> item) {
    final due = _parseDate(_text(item, 'dueDate'));
    if (due == null) return 'No due date';
    final days = DateUtils.dateOnly(due)
        .difference(DateUtils.dateOnly(DateTime.now()))
        .inDays;
    if (days < 0) return '${days.abs()}d overdue';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in ${days}d';
  }

  Color _dueColor(Map<String, dynamic> item) {
    if (_isOverdue(item)) return AppColors.error;
    if (_isDueSoon(item)) return AppColors.warning;
    return AppColors.success;
  }

  List<_QuickDate> _quickDates() {
    final now = DateTime.now();
    return [
      _QuickDate('Tomorrow', now.add(const Duration(days: 1))),
      _QuickDate('In 2 days', now.add(const Duration(days: 2))),
      _QuickDate('Next week', now.add(const Duration(days: 7))),
    ];
  }

  static bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static String _apiDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _text(Map<String, dynamic>? item, String key) {
    final value = item?[key];
    return value == null ? '' : value.toString();
  }
}

class _HomeworkRow extends StatelessWidget {
  final Map<String, dynamic> homework;
  final String dueLabel;
  final Color dueColor;
  final DateFormat displayDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HomeworkRow({
    required this.homework,
    required this.dueLabel,
    required this.dueColor,
    required this.displayDate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = _text('title');
    final description = _text('description');
    final subject = _text('subject');
    final className = _text('className');
    final teacher = _text('teacherName');
    final due = DateTime.tryParse(_text('dueDate'));
    final assigned = DateTime.tryParse(_text('assignedDate'));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.palette.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.menu_book_outlined,
              color: context.palette.brand,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title.isEmpty ? 'Untitled homework' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunitoSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _MiniChip(label: dueLabel, color: dueColor),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (className.isNotEmpty)
                      _MiniChip(label: className, color: context.palette.brand),
                    if (subject.isNotEmpty)
                      _MiniChip(label: subject, color: AppColors.info),
                    if (teacher.isNotEmpty)
                      _MiniChip(
                          label: 'By $teacher', color: AppColors.textSecondary),
                    if (assigned != null)
                      _MiniChip(
                        label: 'Assigned ${displayDate.format(assigned)}',
                        color: AppColors.textSecondary,
                      ),
                    if (due != null)
                      _MiniChip(
                        label: 'Due ${displayDate.format(due)}',
                        color: dueColor,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  String _text(String key) {
    final value = homework[key];
    return value == null ? '' : value.toString();
  }
}

class _QuickDate {
  final String label;
  final DateTime date;

  const _QuickDate(this.label, this.date);
}

class _MetricCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border.all(color: context.palette.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
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
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunitoSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border.all(color: context.palette.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
