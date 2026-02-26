import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/timetable_model.dart';
import '../../../services/timetable_api_service.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with SingleTickerProviderStateMixin {
  final _classCtrl = TextEditingController();
  final _yearCtrl = TextEditingController(text: '2024-25');

  List<TimetableModel> _timetable = [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  TabController? _tabCtrl;

  static const _days = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY'
  ];

  @override
  void dispose() {
    _classCtrl.dispose();
    _yearCtrl.dispose();
    _tabCtrl?.dispose();
    super.dispose();
  }

  Future<void> _loadTimetable() async {
    final className = _classCtrl.text.trim();
    final year = _yearCtrl.text.trim();
    if (className.isEmpty || year.isEmpty) {
      _showSnack('Enter class name and academic year.', isError: true);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _loaded = false;
    });
    try {
      final data =
          await TimetableApiService.getClassTimetable(className, year);
      _timetable = data;
      _tabCtrl?.dispose();
      _tabCtrl = TabController(length: _days.length, vsync: this);
      setState(() => _loaded = true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunitoSans()),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  TimetableModel? _getDay(String day) {
    try {
      return _timetable.firstWhere((t) => t.dayOfWeek == day);
    } catch (_) {
      return null;
    }
  }

  void _openAddEditDialog([TimetableModel? existing]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddDayDialog(
        className: _classCtrl.text.trim(),
        academicYear: _yearCtrl.text.trim(),
        existing: existing,
        onSaved: () {
          Navigator.pop(_);
          _loadTimetable();
          _showSnack('Timetable saved!');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Timetable',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          Text('View and manage the class schedule',
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          _buildFilterBar(),
          const SizedBox(height: 16),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 180,
              child: TextField(
                controller: _classCtrl,
                decoration: _inputDecor('Class Name e.g. Class-5A',
                    Icons.school_outlined),
              ),
            ),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _yearCtrl,
                decoration: _inputDecor(
                    'Academic Year', Icons.calendar_today_outlined),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _loading ? null : _loadTimetable,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search_rounded, size: 16),
              label: Text(_loading ? 'Loading…' : 'Load Timetable'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12)),
            ),
            if (_loaded)
              OutlinedButton.icon(
                onPressed: () => _openAddEditDialog(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add / Edit Day'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.navy),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12)),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecor(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunitoSans(
            color: AppColors.textLight, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: AppColors.navy),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          borderSide: const BorderSide(color: AppColors.navy, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        isDense: true,
      );

  Widget _buildBody() {
    if (_loading) return _buildShimmer();
    if (_error != null) return _buildError();
    if (!_loaded) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.table_chart_outlined,
              size: 60, color: AppColors.textLight.withOpacity(0.4)),
          const SizedBox(height: 14),
          Text('Enter class details and tap Load',
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 14)),
        ]),
      );
    }
    return Column(
      children: [
        TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: AppColors.navy,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.gold,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700),
          tabs: _days
              .map((d) => Tab(text: d.substring(0, 3)))
              .toList(),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: _days.map((day) {
              final entry = _getDay(day);
              if (entry == null) {
                return _buildEmptyDay(day);
              }
              return _buildPeriodsTable(entry);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyDay(String day) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.event_busy_outlined,
              size: 52, color: AppColors.textLight.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text('No schedule for $day',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openAddEditDialog(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Schedule'),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.navy),
          ),
        ]),
      );

  Widget _buildPeriodsTable(TimetableModel entry) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(entry.dayOfWeek,
                style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.navy)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _openAddEditDialog(entry),
              icon: const Icon(Icons.edit_rounded, size: 14),
              label: const Text('Edit'),
              style:
                  TextButton.styleFrom(foregroundColor: AppColors.navy),
            ),
          ]),
          const SizedBox(height: 8),
          ...entry.periods.map((p) => _PeriodCard(period: p)),
        ],
      ),
    );
  }

  Widget _buildShimmer() => Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        child: ListView.builder(
          itemCount: 5,
          itemBuilder: (_, __) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 70,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
          ),
        ),
      );

  Widget _buildError() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off_rounded,
              color: AppColors.error, size: 52),
          const SizedBox(height: 12),
          Text('Failed to load timetable',
              style: GoogleFonts.nunitoSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error)),
          const SizedBox(height: 6),
          Text(_error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _loadTimetable, child: const Text('Retry')),
        ]),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// Period Card
// ──────────────────────────────────────────────────────────────────────────────
class _PeriodCard extends StatelessWidget {
  final PeriodModel period;

  const _PeriodCard({required this.period});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: AppColors.navy.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text('${period.periodNumber}',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(period.subject,
                    style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
                Text(period.teacherName,
                    style: GoogleFonts.nunitoSans(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(period.startTime,
                style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.navy)),
            Text(period.endTime,
                style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Add / Edit Day Dialog
// ──────────────────────────────────────────────────────────────────────────────
class _AddDayDialog extends StatefulWidget {
  final String className;
  final String academicYear;
  final TimetableModel? existing;
  final VoidCallback onSaved;

  const _AddDayDialog({
    required this.className,
    required this.academicYear,
    required this.onSaved,
    this.existing,
  });

  @override
  State<_AddDayDialog> createState() => _AddDayDialogState();
}

class _AddDayDialogState extends State<_AddDayDialog> {
  static const _days = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY'
  ];

  String _selectedDay = 'MONDAY';
  final List<_PeriodFormRow> _rows = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _selectedDay = widget.existing!.dayOfWeek;
      for (final p in widget.existing!.periods) {
        _rows.add(_PeriodFormRow(
          periodNo: p.periodNumber.toString(),
          subject: p.subject,
          teacher: p.teacherName,
          start: p.startTime,
          end: p.endTime,
        ));
      }
    } else {
      _rows.add(_PeriodFormRow());
    }
  }

  Future<void> _save() async {
    final periods = _rows
        .asMap()
        .entries
        .map((e) => PeriodModel(
              periodNumber: int.tryParse(e.value.periodCtrl.text) ?? (e.key + 1),
              subject: e.value.subjectCtrl.text.trim(),
              teacherName: e.value.teacherCtrl.text.trim(),
              startTime: e.value.startCtrl.text.trim(),
              endTime: e.value.endCtrl.text.trim(),
            ))
        .where((p) => p.subject.isNotEmpty)
        .toList();

    if (periods.isEmpty) return;

    setState(() => _saving = true);
    try {
      await TimetableApiService.saveOrUpdateTimetable(TimetableModel(
        id: widget.existing?.id,
        className: widget.className,
        academicYear: widget.academicYear,
        dayOfWeek: _selectedDay,
        periods: periods,
      ));
      widget.onSaved();
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
      title: Text('Schedule for ${widget.className}',
          style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.navy)),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedDay,
                items: _days
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedDay = v!),
                decoration: InputDecoration(
                  labelText: 'Day of Week',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text('Periods',
                  style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w700, color: AppColors.navy)),
              const SizedBox(height: 8),
              ..._rows.asMap().entries.map((e) => _buildPeriodRow(e.key, e.value)),
              TextButton.icon(
                onPressed: () => setState(() => _rows.add(_PeriodFormRow(
                      periodNo: (_rows.length + 1).toString(),
                    ))),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Period'),
                style: TextButton.styleFrom(foregroundColor: AppColors.navy),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildPeriodRow(int index, _PeriodFormRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(children: [
            Text('Period',
                style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.textSecondary)),
            const Spacer(),
            if (_rows.length > 1)
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 16, color: AppColors.error),
                onPressed: () => setState(() => _rows.removeAt(index)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _miniField(row.periodCtrl, '#', width: 60),
            _miniField(row.subjectCtrl, 'Subject', width: 150),
            _miniField(row.teacherCtrl, 'Teacher', width: 150),
            _miniField(row.startCtrl, 'Start (HH:mm)', width: 110),
            _miniField(row.endCtrl, 'End (HH:mm)', width: 110),
          ]),
        ],
      ),
    );
  }

  Widget _miniField(TextEditingController ctrl, String hint,
      {double width = 120}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.nunitoSans(
              color: AppColors.textLight, fontSize: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusSM)),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          isDense: true,
        ),
        style: GoogleFonts.nunitoSans(fontSize: 13),
      ),
    );
  }
}

class _PeriodFormRow {
  final TextEditingController periodCtrl;
  final TextEditingController subjectCtrl;
  final TextEditingController teacherCtrl;
  final TextEditingController startCtrl;
  final TextEditingController endCtrl;

  _PeriodFormRow({
    String periodNo = '',
    String subject = '',
    String teacher = '',
    String start = '',
    String end = '',
  })  : periodCtrl = TextEditingController(text: periodNo),
        subjectCtrl = TextEditingController(text: subject),
        teacherCtrl = TextEditingController(text: teacher),
        startCtrl = TextEditingController(text: start),
        endCtrl = TextEditingController(text: end);
}
