import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/exam_schedule_api_service.dart';

class ExamScheduleScreen extends StatefulWidget {
  const ExamScheduleScreen({super.key});

  @override
  State<ExamScheduleScreen> createState() => _ExamScheduleScreenState();
}

class _ExamScheduleScreenState extends State<ExamScheduleScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _schedules = [];

  // Filters
  late String _selectedYear;
  String? _filterClass;
  String _filterStatus = 'ALL';

  // Academic year options
  late final List<String> _yearOptions;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final currentYear = now.month >= 4 ? now.year : now.year - 1;
    _yearOptions = [
      '${currentYear + 1}-${currentYear + 2}',
      '$currentYear-${currentYear + 1}',
      '${currentYear - 1}-$currentYear',
    ];
    _selectedYear = _yearOptions[1]; // current academic year
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = _filterClass != null
          ? await ExamScheduleApiService.getClassSchedules(
              _filterClass!, _selectedYear,
              status:
                  _filterStatus == 'ALL' ? null : _filterStatus)
          : await ExamScheduleApiService.getAllSchedules(_selectedYear);
      if (mounted) setState(() => _schedules = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _schedules.where((s) {
      if (_filterStatus != 'ALL' && s['status'] != _filterStatus) return false;
      if (_filterClass != null && s['className'] != _filterClass) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildStatusChips(),
          const SizedBox(height: 16),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Exam Scheduler',
            style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.navy)),
        const SizedBox(width: 16),
        // Academic year dropdown
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            value: _selectedYear,
            decoration: InputDecoration(
              labelText: 'Academic Year',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary),
            items: _yearOptions
                .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _selectedYear = v);
                _loadSchedules();
              }
            },
          ),
        ),
        // Class filter dropdown
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<String>(
            value: _filterClass,
            decoration: InputDecoration(
              labelText: 'Class',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Classes')),
              ...SchoolConstants.baseClasses
                  .map((c) => DropdownMenuItem(value: c, child: Text(c))),
            ],
            onChanged: (v) {
              setState(() => _filterClass = v);
              _loadSchedules();
            },
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showCreateEditDialog(null),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Create Schedule'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
        ),
        IconButton(
          onPressed: _loadSchedules,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          color: AppColors.navy,
        ),
      ],
    );
  }

  Widget _buildStatusChips() {
    final statuses = ['ALL', 'DRAFT', 'PUBLISHED', 'COMPLETED'];
    final labels = {'ALL': 'All', 'DRAFT': 'Draft', 'PUBLISHED': 'Published', 'COMPLETED': 'Completed'};
    final colors = {
      'ALL': AppColors.navy,
      'DRAFT': Colors.orange,
      'PUBLISHED': AppColors.success,
      'COMPLETED': Colors.grey,
    };

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: statuses.map((status) {
          final isSelected = _filterStatus == status;
          final color = colors[status] ?? AppColors.navy;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _filterStatus = status);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.12) : Colors.white,
                  border: Border.all(
                      color: isSelected ? color : AppColors.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(labels[status]!,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : AppColors.textSecondary)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
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
            Text('Failed to load schedules',
                style: GoogleFonts.poppins(
                    fontSize: 16, color: AppColors.error)),
            const SizedBox(height: 6),
            Text(_error!,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _loadSchedules, child: const Text('Retry')),
          ],
        ),
      );
    }

    final schedules = _filtered;
    if (schedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined,
                size: 56, color: AppColors.textLight.withOpacity(0.5)),
            const SizedBox(height: 14),
            Text('No exam schedules found',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy)),
            const SizedBox(height: 6),
            Text('Create one using the button above.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: schedules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ScheduleCard(
        schedule: schedules[i],
        onEdit: () => _showCreateEditDialog(schedules[i]),
        onPublish: () => _publishSchedule(schedules[i]),
        onDelete: () => _deleteSchedule(schedules[i]),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _publishSchedule(Map<String, dynamic> schedule) async {
    final id = schedule['id']?.toString();
    if (id == null) return;
    try {
      await ExamScheduleApiService.publishSchedule(id);
      _showSnack('Schedule published successfully');
      _loadSchedules();
    } catch (e) {
      _showSnack('Failed to publish: $e', isError: true);
    }
  }

  Future<void> _deleteSchedule(Map<String, dynamic> schedule) async {
    final id = schedule['id']?.toString();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Schedule',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
            'Are you sure you want to delete "${schedule['examName'] ?? 'this schedule'}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ExamScheduleApiService.deleteSchedule(id);
      _showSnack('Schedule deleted');
      _loadSchedules();
    } catch (e) {
      _showSnack('Failed to delete: $e', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ---------------------------------------------------------------------------
  // Create / Edit Dialog
  // ---------------------------------------------------------------------------

  void _showCreateEditDialog(Map<String, dynamic>? existing) {
    final isEdit = existing != null;
    final nameCtrl =
        TextEditingController(text: existing?['examName'] as String? ?? '');
    String examType = existing?['examType'] as String? ?? 'MID_TERM';
    String academicYear = existing?['academicYear'] as String? ?? _selectedYear;
    String? className = existing?['className'] as String?;

    // Parse existing slots
    final existingSlots =
        (existing?['examSlots'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final slots = existingSlots.isNotEmpty
        ? existingSlots.map((s) => _ExamSlotData.fromMap(s)).toList()
        : [_ExamSlotData()];

    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Row(
                      children: [
                        Icon(Icons.quiz_outlined,
                            color: AppColors.navy, size: 24),
                        const SizedBox(width: 10),
                        Text(
                            isEdit
                                ? 'Edit Exam Schedule'
                                : 'Create Exam Schedule',
                            style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy)),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    // Form fields
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Row 1: Exam Name + Type
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: nameCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Exam Name *',
                                      hintText:
                                          'e.g., Mid-Term Examination 2026',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              AppSizes.radiusMD)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 14),
                                    ),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    value: examType,
                                    decoration: InputDecoration(
                                      labelText: 'Exam Type *',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              AppSizes.radiusMD)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 14),
                                    ),
                                    style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: AppColors.textPrimary),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'UNIT_TEST',
                                          child: Text('Unit Test')),
                                      DropdownMenuItem(
                                          value: 'MID_TERM',
                                          child: Text('Mid Term')),
                                      DropdownMenuItem(
                                          value: 'FINAL',
                                          child: Text('Final')),
                                      DropdownMenuItem(
                                          value: 'PRACTICAL',
                                          child: Text('Practical')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setSt(() => examType = v);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Row 2: Academic Year + Class
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: academicYear,
                                    decoration: InputDecoration(
                                      labelText: 'Academic Year *',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              AppSizes.radiusMD)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 14),
                                    ),
                                    style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: AppColors.textPrimary),
                                    items: _yearOptions
                                        .map((y) => DropdownMenuItem(
                                            value: y, child: Text(y)))
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setSt(() => academicYear = v);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: className,
                                    decoration: InputDecoration(
                                      labelText: 'Class *',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              AppSizes.radiusMD)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 14),
                                    ),
                                    style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: AppColors.textPrimary),
                                    items: SchoolConstants.baseClasses
                                        .map((c) => DropdownMenuItem(
                                            value: c, child: Text(c)))
                                        .toList(),
                                    onChanged: (v) {
                                      setSt(() => className = v);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Exam Slots header
                            Row(
                              children: [
                                Text('Exam Slots',
                                    style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.navy)),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () {
                                    setSt(() => slots.add(_ExamSlotData()));
                                  },
                                  icon: const Icon(Icons.add_circle_outline,
                                      size: 18),
                                  label: const Text('Add Slot'),
                                  style: TextButton.styleFrom(
                                      foregroundColor: AppColors.navy),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Slot rows
                            ...List.generate(slots.length, (i) {
                              final slot = slots[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border:
                                      Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(
                                      AppSizes.radiusMD),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Text('Slot ${i + 1}',
                                            style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    AppColors.textSecondary)),
                                        const Spacer(),
                                        if (slots.length > 1)
                                          IconButton(
                                            onPressed: () {
                                              setSt(() =>
                                                  slots.removeAt(i));
                                            },
                                            icon: const Icon(
                                                Icons.remove_circle_outline,
                                                size: 18,
                                                color: AppColors.error),
                                            tooltip: 'Remove slot',
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Subject + Max Marks
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: TextField(
                                            controller: slot.subjectCtrl,
                                            decoration:
                                                _slotInputDecor('Subject'),
                                            style: GoogleFonts.poppins(
                                                fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 1,
                                          child: TextField(
                                            controller: slot.maxMarksCtrl,
                                            keyboardType:
                                                TextInputType.number,
                                            decoration:
                                                _slotInputDecor('Max Marks'),
                                            style: GoogleFonts.poppins(
                                                fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Date + Start Time + End Time
                                    Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: () async {
                                              final picked =
                                                  await showDatePicker(
                                                context: ctx,
                                                initialDate:
                                                    slot.date ?? DateTime.now(),
                                                firstDate: DateTime(2024),
                                                lastDate: DateTime(2030),
                                              );
                                              if (picked != null) {
                                                setSt(() =>
                                                    slot.date = picked);
                                              }
                                            },
                                            child: InputDecorator(
                                              decoration:
                                                  _slotInputDecor('Date'),
                                              child: Text(
                                                slot.date != null
                                                    ? DateFormat('dd MMM yyyy')
                                                        .format(slot.date!)
                                                    : 'Select',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    color: slot.date != null
                                                        ? AppColors
                                                            .textPrimary
                                                        : AppColors
                                                            .textLight),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () async {
                                              final picked =
                                                  await showTimePicker(
                                                context: ctx,
                                                initialTime:
                                                    slot.startTime ??
                                                        const TimeOfDay(
                                                            hour: 9,
                                                            minute: 0),
                                              );
                                              if (picked != null) {
                                                setSt(() =>
                                                    slot.startTime = picked);
                                              }
                                            },
                                            child: InputDecorator(
                                              decoration: _slotInputDecor(
                                                  'Start Time'),
                                              child: Text(
                                                slot.startTime != null
                                                    ? slot.startTime!
                                                        .format(ctx)
                                                    : 'Select',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    color:
                                                        slot.startTime != null
                                                            ? AppColors
                                                                .textPrimary
                                                            : AppColors
                                                                .textLight),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () async {
                                              final picked =
                                                  await showTimePicker(
                                                context: ctx,
                                                initialTime:
                                                    slot.endTime ??
                                                        const TimeOfDay(
                                                            hour: 11,
                                                            minute: 0),
                                              );
                                              if (picked != null) {
                                                setSt(() =>
                                                    slot.endTime = picked);
                                              }
                                            },
                                            child: InputDecorator(
                                              decoration:
                                                  _slotInputDecor('End Time'),
                                              child: Text(
                                                slot.endTime != null
                                                    ? slot.endTime!.format(ctx)
                                                    : 'Select',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    color: slot.endTime != null
                                                        ? AppColors
                                                            .textPrimary
                                                        : AppColors
                                                            .textLight),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Room + Invigilator
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: slot.roomCtrl,
                                            decoration:
                                                _slotInputDecor('Room'),
                                            style: GoogleFonts.poppins(
                                                fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller:
                                                slot.invigilatorCtrl,
                                            decoration:
                                                _slotInputDecor('Invigilator'),
                                            style: GoogleFonts.poppins(
                                                fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed:
                              saving ? null : () => Navigator.pop(ctx),
                          child: Text('Cancel',
                              style: GoogleFonts.poppins(
                                  color: AppColors.textSecondary)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (nameCtrl.text.trim().isEmpty ||
                                      className == null) {
                                    _showSnack(
                                        'Please fill in exam name and class',
                                        isError: true);
                                    return;
                                  }
                                  setSt(() => saving = true);
                                  try {
                                    final data = {
                                      'examName': nameCtrl.text.trim(),
                                      'examType': examType,
                                      'academicYear': academicYear,
                                      'className': className,
                                      'examSlots': slots
                                          .map((s) => s.toMap())
                                          .toList(),
                                    };
                                    if (isEdit &&
                                        existing['id'] != null) {
                                      await ExamScheduleApiService
                                          .updateSchedule(
                                              existing['id'].toString(),
                                              data);
                                    } else {
                                      await ExamScheduleApiService
                                          .createSchedule(data);
                                    }
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    _showSnack(isEdit
                                        ? 'Schedule updated'
                                        : 'Schedule created');
                                    _loadSchedules();
                                  } catch (e) {
                                    setSt(() => saving = false);
                                    _showSnack('Failed: $e',
                                        isError: true);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12)),
                          child: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(isEdit ? 'Update' : 'Create',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _slotInputDecor(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: AppColors.cream,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSM)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }
}

// ---------------------------------------------------------------------------
// Exam Slot data helper
// ---------------------------------------------------------------------------

class _ExamSlotData {
  final TextEditingController subjectCtrl;
  final TextEditingController maxMarksCtrl;
  final TextEditingController roomCtrl;
  final TextEditingController invigilatorCtrl;
  DateTime? date;
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  _ExamSlotData({
    String subject = '',
    String maxMarks = '',
    String room = '',
    String invigilator = '',
    this.date,
    this.startTime,
    this.endTime,
  })  : subjectCtrl = TextEditingController(text: subject),
        maxMarksCtrl = TextEditingController(text: maxMarks),
        roomCtrl = TextEditingController(text: room),
        invigilatorCtrl = TextEditingController(text: invigilator);

  factory _ExamSlotData.fromMap(Map<String, dynamic> m) {
    DateTime? date;
    if (m['date'] != null) {
      date = DateTime.tryParse(m['date'].toString());
    }
    TimeOfDay? start;
    if (m['startTime'] != null) {
      final parts = m['startTime'].toString().split(':');
      if (parts.length >= 2) {
        start = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0);
      }
    }
    TimeOfDay? end;
    if (m['endTime'] != null) {
      final parts = m['endTime'].toString().split(':');
      if (parts.length >= 2) {
        end = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0);
      }
    }
    return _ExamSlotData(
      subject: m['subject'] as String? ?? '',
      maxMarks: m['maxMarks']?.toString() ?? '',
      room: m['room'] as String? ?? '',
      invigilator: m['invigilator'] as String? ?? '',
      date: date,
      startTime: start,
      endTime: end,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subject': subjectCtrl.text.trim(),
      'maxMarks': int.tryParse(maxMarksCtrl.text.trim()) ?? 0,
      'room': roomCtrl.text.trim(),
      'invigilator': invigilatorCtrl.text.trim(),
      if (date != null) 'date': DateFormat('yyyy-MM-dd').format(date!),
      if (startTime != null)
        'startTime':
            '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}',
      if (endTime != null)
        'endTime':
            '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}',
    };
  }
}

// ---------------------------------------------------------------------------
// Schedule Card widget
// ---------------------------------------------------------------------------

class _ScheduleCard extends StatefulWidget {
  final Map<String, dynamic> schedule;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onDelete;

  const _ScheduleCard({
    required this.schedule,
    required this.onEdit,
    required this.onPublish,
    required this.onDelete,
  });

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.schedule;
    final status = s['status'] as String? ?? 'DRAFT';
    final examName = s['examName'] as String? ?? 'Untitled';
    final examType = s['examType'] as String? ?? '';
    final className = s['className'] as String? ?? '';
    final slots =
        (s['examSlots'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.vertical(
                top: const Radius.circular(12),
                bottom: _expanded ? Radius.zero : const Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(examName,
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navy)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _typeChip(examType),
                            _chip(className, AppColors.navy),
                            _statusBadge(status),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Action buttons
                  IconButton(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit',
                    color: AppColors.navy,
                  ),
                  if (status == 'DRAFT')
                    IconButton(
                      onPressed: widget.onPublish,
                      icon: const Icon(Icons.publish_outlined, size: 18),
                      tooltip: 'Publish',
                      color: AppColors.success,
                    ),
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Delete',
                    color: AppColors.error,
                  ),
                  Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          // Expanded slot table
          if (_expanded && slots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1),
                  4: FlexColumnWidth(1.5),
                  5: FlexColumnWidth(1),
                },
                border: TableBorder.all(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(8)),
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: AppColors.navy.withOpacity(0.05),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8)),
                    ),
                    children: [
                      _tableHeader('Subject'),
                      _tableHeader('Date'),
                      _tableHeader('Time'),
                      _tableHeader('Room'),
                      _tableHeader('Invigilator'),
                      _tableHeader('Max Marks'),
                    ],
                  ),
                  ...slots.map((slot) {
                    final date = slot['date'] as String? ?? '-';
                    final start = slot['startTime'] as String? ?? '';
                    final end = slot['endTime'] as String? ?? '';
                    final time = start.isNotEmpty
                        ? '$start${end.isNotEmpty ? ' - $end' : ''}'
                        : '-';
                    return TableRow(
                      children: [
                        _tableCell(slot['subject'] as String? ?? '-'),
                        _tableCell(date),
                        _tableCell(time),
                        _tableCell(slot['room'] as String? ?? '-'),
                        _tableCell(slot['invigilator'] as String? ?? '-'),
                        _tableCell(slot['maxMarks']?.toString() ?? '-'),
                      ],
                    );
                  }),
                ],
              ),
            ),
          if (_expanded && slots.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('No exam slots configured.',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(text,
          style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.navy)),
    );
  }

  Widget _tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(text,
          style: GoogleFonts.poppins(
              fontSize: 12, color: AppColors.textPrimary)),
    );
  }

  Widget _typeChip(String type) {
    final label = switch (type) {
      'UNIT_TEST' => 'Unit Test',
      'MID_TERM' => 'Mid Term',
      'FINAL' => 'Final',
      'PRACTICAL' => 'Practical',
      _ => type,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.gold)),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _statusBadge(String status) {
    final Color bgColor;
    final Color textColor;
    final String label;
    switch (status) {
      case 'DRAFT':
        bgColor = Colors.orange.withOpacity(0.15);
        textColor = Colors.orange;
        label = 'Draft';
      case 'PUBLISHED':
        bgColor = AppColors.success.withOpacity(0.15);
        textColor = AppColors.success;
        label = 'Published';
      case 'COMPLETED':
        bgColor = Colors.grey.withOpacity(0.15);
        textColor = Colors.grey;
        label = 'Completed';
      default:
        bgColor = Colors.grey.withOpacity(0.15);
        textColor = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w700, color: textColor)),
    );
  }
}
