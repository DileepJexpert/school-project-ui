import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../models/timetable_model.dart';
import '../../../services/timetable_api_service.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late final TextEditingController _yearCtrl;

  String? _className;
  String _selectedDay = _days.first;
  List<TimetableModel> _timetable = [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  static const _days = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
  ];

  @override
  void initState() {
    super.initState();
    _yearCtrl = TextEditingController(text: _currentAcademicYear());
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    super.dispose();
  }

  String _currentAcademicYear() {
    final now = DateTime.now();
    final start = now.month >= 4 ? now.year : now.year - 1;
    return '$start-${(start + 1).toString().substring(2)}';
  }

  Future<void> _loadTimetable() async {
    final className = _className;
    final year = _yearCtrl.text.trim();
    if (className == null || className.isEmpty || year.isEmpty) {
      _snack('Select class and academic year.', isError: true);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _loaded = false;
    });
    try {
      final data = await TimetableApiService.getClassTimetable(className, year);
      data.sort((a, b) => _days.indexOf(a.dayOfWeek).compareTo(
            _days.indexOf(b.dayOfWeek),
          ));
      if (!mounted) return;
      setState(() {
        _timetable = data;
        _loaded = true;
        final firstScheduled = data.isNotEmpty ? data.first.dayOfWeek : null;
        if (firstScheduled != null && _days.contains(firstScheduled)) {
          _selectedDay = firstScheduled;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  TimetableModel? _entryFor(String day) {
    for (final entry in _timetable) {
      if (entry.dayOfWeek == day) return entry;
    }
    return null;
  }

  int get _totalPeriods =>
      _timetable.fold(0, (sum, entry) => sum + entry.periods.length);

  String get _busiestDay {
    if (_timetable.isEmpty) return 'No day';
    final sorted = List<TimetableModel>.from(_timetable)
      ..sort((a, b) => b.periods.length.compareTo(a.periods.length));
    return _shortDay(sorted.first.dayOfWeek);
  }

  Future<void> _openEditor([TimetableModel? existing]) async {
    final className = _className;
    final year = _yearCtrl.text.trim();
    if (className == null || className.isEmpty || year.isEmpty) {
      _snack('Select class and academic year first.', isError: true);
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TimetableDayDialog(
        className: className,
        academicYear: year,
        initialDay: existing?.dayOfWeek ?? _selectedDay,
        existing: existing,
      ),
    );
    if (saved == true) {
      _snack('Timetable saved.');
      _loadTimetable();
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
    return Padding(
      padding: EdgeInsets.all(
        Responsive.isMobile(context) ? AppSizes.paddingMD : AppSizes.paddingLG,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdminPageHeader(
          title: 'Timetable',
          subtitle:
              'Manage class schedules day by day with a compact weekly view.',
          icon: Icons.calendar_view_week_outlined,
          actions: [
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadTimetable,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Refresh'),
            ),
            ElevatedButton.icon(
              onPressed: () => _openEditor(_entryFor(_selectedDay)),
              icon: const Icon(Icons.edit_calendar_outlined, size: 17),
              label: const Text('Add / Edit Day'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _filterCard(),
        const SizedBox(height: 14),
        if (_loaded) ...[
          _summaryCards(),
          const SizedBox(height: 14),
        ],
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _filterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String>(
                initialValue: _className,
                decoration: _inputDecoration('Class', Icons.school_outlined),
                isExpanded: true,
                items: SchoolConstants.allClasses
                    .map((className) => DropdownMenuItem(
                          value: className,
                          child: Text(className),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _className = value),
              ),
            ),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _yearCtrl,
                decoration:
                    _inputDecoration('Academic year', Icons.event_outlined),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _loading ? null : _loadTimetable,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search_rounded, size: 17),
              label: Text(_loading ? 'Loading' : 'Load Timetable'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCards() {
    final cards = [
      AdminMetricCard(
        title: 'Scheduled Days',
        value: '${_timetable.length}',
        icon: Icons.date_range_outlined,
        color: context.palette.brand,
        caption: 'Out of ${_days.length}',
      ),
      AdminMetricCard(
        title: 'Total Periods',
        value: '$_totalPeriods',
        icon: Icons.view_timeline_outlined,
        color: AppColors.info,
        caption: 'Weekly load',
      ),
      AdminMetricCard(
        title: 'Busiest Day',
        value: _busiestDay,
        icon: Icons.trending_up_rounded,
        color: AppColors.warning,
        caption: 'Most periods',
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 840 ? 3 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children:
            cards.map((card) => SizedBox(width: width, child: card)).toList(),
      );
    });
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _errorState();
    if (!_loaded) {
      return _emptyState(
        icon: Icons.calendar_view_week_outlined,
        title: 'Load a timetable',
        subtitle: 'Select class and academic year to view the weekly schedule.',
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 900;
      if (!wide) {
        return Column(children: [
          _daySelector(horizontal: true),
          const SizedBox(height: 12),
          Expanded(child: _dayDetails(_selectedDay)),
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 240, child: _daySelector(horizontal: false)),
        const SizedBox(width: 14),
        Expanded(child: _dayDetails(_selectedDay)),
      ]);
    });
  }

  Widget _daySelector({required bool horizontal}) {
    final children = _days.map((day) {
      final entry = _entryFor(day);
      final selected = _selectedDay == day;
      return Padding(
        padding: EdgeInsets.only(
          right: horizontal ? 8 : 0,
          bottom: horizontal ? 0 : 8,
        ),
        child: InkWell(
          onTap: () => setState(() => _selectedDay = day),
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? context.palette.brand.withValues(alpha: 0.1)
                  : context.palette.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              border: Border.all(
                color:
                    selected ? context.palette.brand : context.palette.border,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                entry == null
                    ? Icons.event_busy_outlined
                    : Icons.event_available_outlined,
                size: 18,
                color: entry == null ? AppColors.textLight : AppColors.success,
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _shortDay(day),
                  style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w900,
                    color: selected
                        ? context.palette.brand
                        : AppColors.textPrimary,
                  ),
                ),
                Text(
                  entry == null
                      ? 'No periods'
                      : '${entry.periods.length} periods',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ]),
            ]),
          ),
        ),
      );
    }).toList();

    if (horizontal) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: children),
      );
    }
    return ListView(children: children);
  }

  Widget _dayDetails(String day) {
    final entry = _entryFor(day);
    if (entry == null) {
      return _emptyState(
        icon: Icons.event_busy_outlined,
        title: 'No schedule for ${_shortDay(day)}',
        subtitle: 'Add periods for this day to complete the weekly timetable.',
        action: ElevatedButton.icon(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_rounded, size: 17),
          label: const Text('Add Day Schedule'),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_shortDay(day)} Schedule',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${entry.className} - ${entry.academicYear}',
                      style: GoogleFonts.nunitoSans(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ]),
            ),
            OutlinedButton.icon(
              onPressed: () => _openEditor(entry),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: ListView.separated(
          itemCount: entry.periods.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, index) => _periodCard(entry.periods[index]),
        ),
      ),
    ]);
  }

  Widget _periodCard(PeriodModel period) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.palette.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            ),
            child: Center(
              child: Text(
                '${period.periodNumber}',
                style: GoogleFonts.nunitoSans(
                  color: context.palette.brand,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                period.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                period.teacherName.isEmpty
                    ? 'Teacher not assigned'
                    : period.teacherName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: context.palette.canvas,
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            ),
            child: Text(
              '${period.startTime} - ${period.endTime}',
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 54, color: AppColors.textLight.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text(
          title,
          style: GoogleFonts.nunitoSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        if (action != null) ...[const SizedBox(height: 16), action],
      ]),
    );
  }

  Widget _errorState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 48),
        const SizedBox(height: 12),
        Text(
          'Could not load timetable',
          style: GoogleFonts.nunitoSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _error ?? '',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunitoSans(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _loadTimetable,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('Retry'),
        ),
      ]),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      isDense: true,
      fillColor: context.palette.canvas,
    );
  }

  String _shortDay(String day) {
    return day.substring(0, 1) + day.substring(1).toLowerCase();
  }
}

class _TimetableDayDialog extends StatefulWidget {
  final String className;
  final String academicYear;
  final String initialDay;
  final TimetableModel? existing;

  const _TimetableDayDialog({
    required this.className,
    required this.academicYear,
    required this.initialDay,
    this.existing,
  });

  @override
  State<_TimetableDayDialog> createState() => _TimetableDayDialogState();
}

class _TimetableDayDialogState extends State<_TimetableDayDialog> {
  late String _day;
  late final List<_PeriodDraft> _periods;
  bool _saving = false;

  static const _days = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
  ];

  @override
  void initState() {
    super.initState();
    _day = widget.initialDay;
    _periods = widget.existing?.periods
            .map((period) => _PeriodDraft.fromPeriod(period))
            .toList() ??
        [_PeriodDraft(periodNumber: 1)];
  }

  @override
  void dispose() {
    for (final draft in _periods) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final validPeriods = _periods
        .where((draft) =>
            draft.subject.text.trim().isNotEmpty &&
            draft.start.text.trim().isNotEmpty &&
            draft.end.text.trim().isNotEmpty)
        .toList();
    if (validPeriods.isEmpty) {
      _snack('Add at least one valid period.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await TimetableApiService.saveOrUpdateTimetable(
        TimetableModel(
          id: widget.existing?.id,
          className: widget.className,
          academicYear: widget.academicYear,
          dayOfWeek: _day,
          periods: validPeriods
              .map((draft) => PeriodModel(
                    periodNumber: int.tryParse(draft.number.text.trim()) ?? 1,
                    subject: draft.subject.text.trim(),
                    teacherName: draft.teacher.text.trim(),
                    startTime: draft.start.text.trim(),
                    endTime: draft.end.text.trim(),
                  ))
              .toList()
            ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber)),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack('Save failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addPeriod() {
    setState(
        () => _periods.add(_PeriodDraft(periodNumber: _periods.length + 1)));
  }

  void _removePeriod(_PeriodDraft draft) {
    if (_periods.length == 1) return;
    setState(() {
      _periods.remove(draft);
      draft.dispose();
    });
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Add Day Schedule' : 'Edit Day Schedule',
        style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: _day,
              decoration: const InputDecoration(labelText: 'Day'),
              items: _days
                  .map((day) => DropdownMenuItem(value: day, child: Text(day)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _day = value);
              },
            ),
            const SizedBox(height: 14),
            ..._periods.map((draft) => _periodEditor(draft)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addPeriod,
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Add Period'),
              ),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded, size: 17),
          label: Text(_saving ? 'Saving' : 'Save'),
        ),
      ],
    );
  }

  Widget _periodEditor(_PeriodDraft draft) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: Text(
                'Period ${draft.number.text}',
                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              onPressed:
                  _periods.length == 1 ? null : () => _removePeriod(draft),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ]),
          Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(
              width: 88,
              child: TextField(
                controller: draft.number,
                decoration: const InputDecoration(labelText: 'No.'),
                keyboardType: TextInputType.number,
              ),
            ),
            SizedBox(
              width: 170,
              child: TextField(
                controller: draft.subject,
                decoration: const InputDecoration(labelText: 'Subject *'),
              ),
            ),
            SizedBox(
              width: 170,
              child: TextField(
                controller: draft.teacher,
                decoration: const InputDecoration(labelText: 'Teacher'),
              ),
            ),
            SizedBox(
              width: 120,
              child: TextField(
                controller: draft.start,
                decoration: const InputDecoration(labelText: 'Start *'),
              ),
            ),
            SizedBox(
              width: 120,
              child: TextField(
                controller: draft.end,
                decoration: const InputDecoration(labelText: 'End *'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _PeriodDraft {
  final TextEditingController number;
  final TextEditingController subject;
  final TextEditingController teacher;
  final TextEditingController start;
  final TextEditingController end;

  _PeriodDraft({required int periodNumber})
      : number = TextEditingController(text: '$periodNumber'),
        subject = TextEditingController(),
        teacher = TextEditingController(),
        start = TextEditingController(),
        end = TextEditingController();

  _PeriodDraft.fromPeriod(PeriodModel period)
      : number = TextEditingController(text: '${period.periodNumber}'),
        subject = TextEditingController(text: period.subject),
        teacher = TextEditingController(text: period.teacherName),
        start = TextEditingController(text: period.startTime),
        end = TextEditingController(text: period.endTime);

  void dispose() {
    number.dispose();
    subject.dispose();
    teacher.dispose();
    start.dispose();
    end.dispose();
  }
}
