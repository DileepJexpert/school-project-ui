import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/meeting_api_service.dart';

class MeetingScreen extends StatefulWidget {
  const MeetingScreen({super.key});

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<Map<String, dynamic>> _meetings = [];
  Map<String, dynamic> _stats = {};
  List<dynamic> _upcoming = [];

  // Filters
  String? _statusFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  static const _statuses = [
    null,
    'SCHEDULED',
    'COMPLETED',
    'CANCELLED',
    'NO_SHOW',
  ];
  static const _statusLabels = [
    'All',
    'Scheduled',
    'Completed',
    'Cancelled',
    'No Show',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        MeetingApiService.getAllMeetings(),
        MeetingApiService.getStats(),
        MeetingApiService.getUpcoming(),
      ]);
      if (mounted) {
        setState(() {
          _meetings = (results[0] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _stats = results[1] as Map<String, dynamic>;
          _upcoming = results[2] as List;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredMeetings {
    var list = _meetings;
    if (_statusFilter != null) {
      list = list.where((m) => m['status'] == _statusFilter).toList();
    }
    if (_dateFrom != null) {
      list = list.where((m) {
        try {
          final d = DateTime.parse(m['date'] as String);
          return !d.isBefore(_dateFrom!);
        } catch (_) {
          return true;
        }
      }).toList();
    }
    if (_dateTo != null) {
      list = list.where((m) {
        try {
          final d = DateTime.parse(m['date'] as String);
          return !d.isAfter(_dateTo!);
        } catch (_) {
          return true;
        }
      }).toList();
    }
    return list;
  }

  Color _statusColor(String? status) {
    return switch (status) {
      'SCHEDULED' => AppColors.info,
      'COMPLETED' => AppColors.success,
      'CANCELLED' => AppColors.error,
      'NO_SHOW' => AppColors.warning,
      _ => AppColors.textSecondary,
    };
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // Tab bar
        Container(
          color: AppColors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.navy,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.gold,
            labelStyle:
                GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
            tabs: const [
              Tab(text: 'Meetings'),
              Tab(text: 'Dashboard'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMeetingsTab(),
              _buildDashboardTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1 — Meetings
  // ---------------------------------------------------------------------------

  Widget _buildMeetingsTab() {
    final filtered = _filteredMeetings;
    final total = _meetings.length;
    final scheduled =
        _meetings.where((m) => m['status'] == 'SCHEDULED').length;
    final completed =
        _meetings.where((m) => m['status'] == 'COMPLETED').length;
    final cancelled =
        _meetings.where((m) => m['status'] == 'CANCELLED').length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          _buildStatsRow(total, scheduled, completed, cancelled, compact: true),
          const SizedBox(height: 16),

          // Filters row
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Date from
              _buildDateChip(
                label: _dateFrom != null
                    ? 'From: ${DateFormat('dd MMM yyyy').format(_dateFrom!)}'
                    : 'From Date',
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateFrom ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _dateFrom = picked);
                },
                onClear:
                    _dateFrom != null ? () => setState(() => _dateFrom = null) : null,
              ),
              // Date to
              _buildDateChip(
                label: _dateTo != null
                    ? 'To: ${DateFormat('dd MMM yyyy').format(_dateTo!)}'
                    : 'To Date',
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateTo ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _dateTo = picked);
                },
                onClear:
                    _dateTo != null ? () => setState(() => _dateTo = null) : null,
              ),
              // Status dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _statusFilter,
                    hint: Text('Status',
                        style: GoogleFonts.poppins(fontSize: 13)),
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textPrimary),
                    items: List.generate(_statuses.length, (i) {
                      return DropdownMenuItem(
                        value: _statuses[i],
                        child: Text(_statusLabels[i]),
                      );
                    }),
                    onChanged: (v) => setState(() => _statusFilter = v),
                  ),
                ),
              ),
              // Schedule Meeting button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _showScheduleDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Schedule Meeting',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              OutlinedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 16),
                label:
                    Text('Refresh', style: GoogleFonts.poppins(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Meetings list
          if (filtered.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_busy_outlined,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No meetings found.',
                          style: GoogleFonts.poppins(
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = Responsive.isDesktop(context);
                final isTablet = Responsive.isTablet(context);
                if (isDesktop || isTablet) {
                  final cols = isDesktop ? 2 : 1;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: filtered.map((meeting) {
                      return SizedBox(
                        width: cols == 2
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth,
                        child: _buildMeetingCard(meeting),
                      );
                    }).toList(),
                  );
                }
                return Column(
                  children:
                      filtered.map((m) => _buildMeetingCard(m)).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDateChip({
    required String label,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMD),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textPrimary)),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onClear,
                child: Icon(Icons.close, size: 14, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats row
  // ---------------------------------------------------------------------------

  Widget _buildStatsRow(int total, int scheduled, int completed, int cancelled,
      {bool compact = false}) {
    final cards = [
      _buildStatCard('Total', total, AppColors.navy, Icons.groups, compact),
      _buildStatCard(
          'Scheduled', scheduled, AppColors.info, Icons.schedule, compact),
      _buildStatCard('Completed', completed, AppColors.success,
          Icons.check_circle_outline, compact),
      _buildStatCard(
          'Cancelled', cancelled, AppColors.error, Icons.cancel_outlined, compact),
    ];

    if (Responsive.isMobile(context)) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: cards
            .map((c) => SizedBox(
                width: (MediaQuery.of(context).size.width -
                        Responsive.contentPadding(context) * 2 -
                        8) /
                    2,
                child: c))
            .toList(),
      );
    }

    return Row(
      children: cards
          .map((c) => Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: c,
              )))
          .toList(),
    );
  }

  Widget _buildStatCard(
      String label, int count, Color color, IconData icon, bool compact) {
    final vPad = compact ? 12.0 : 20.0;
    final fontSize = compact ? 22.0 : 28.0;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: 16, vertical: vPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Text('$count',
                style: GoogleFonts.poppins(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Meeting card
  // ---------------------------------------------------------------------------

  Widget _buildMeetingCard(Map<String, dynamic> meeting) {
    final title = meeting['title'] as String? ?? '';
    final description = meeting['description'] as String? ?? '';
    final status = meeting['status'] as String? ?? '';
    final teacherName = meeting['teacherName'] as String? ?? '';
    final parentName = meeting['parentName'] as String? ?? '';
    final studentName = meeting['studentName'] as String? ?? '';
    final date = meeting['date'] as String? ?? '';
    final startTime = meeting['startTime'] as String? ?? '';
    final endTime = meeting['endTime'] as String? ?? '';
    final venue = meeting['venue'] as String? ?? '';
    final className = meeting['className'] as String? ?? '';
    final notes = meeting['notes'] as String? ?? '';
    final feedback = meeting['feedback'] as String? ?? '';
    final id = meeting['id']?.toString() ?? meeting['_id']?.toString() ?? '';

    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(date);
    } catch (_) {}

    final sColor = _statusColor(status);

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
            // Title + status badge
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: sColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(status,
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: sColor)),
                ),
              ],
            ),
            // Description
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description.length > 120
                    ? '${description.substring(0, 120)}...'
                    : description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 10),
            // People chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (teacherName.isNotEmpty)
                  _buildPersonChip(Icons.school, teacherName, AppColors.navy),
                if (parentName.isNotEmpty)
                  _buildPersonChip(
                      Icons.person, parentName, AppColors.info),
                if (studentName.isNotEmpty)
                  _buildPersonChip(
                      Icons.face, studentName, const Color(0xFF7C3AED)),
              ],
            ),
            const SizedBox(height: 10),
            // Date, time, venue, class
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                if (date.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        parsedDate != null
                            ? DateFormat('dd MMM yyyy').format(parsedDate)
                            : date,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                if (startTime.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        endTime.isNotEmpty
                            ? '$startTime - $endTime'
                            : startTime,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                if (venue.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Text(venue,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                if (className.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(className,
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.navy)),
                  ),
              ],
            ),
            // Notes (for completed)
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  border: Border.all(color: AppColors.success.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notes',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success)),
                    const SizedBox(height: 2),
                    Text(notes,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
            // Feedback
            if (feedback.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  border: Border.all(color: AppColors.info.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Parent Feedback',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.info)),
                    const SizedBox(height: 2),
                    Text(feedback,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showScheduleDialog(meeting: meeting),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label:
                      Text('Edit', style: GoogleFonts.poppins(fontSize: 12)),
                ),
                if (status == 'SCHEDULED') ...[
                  TextButton.icon(
                    onPressed: () => _showCompleteDialog(id),
                    icon: Icon(Icons.check_circle_outline,
                        size: 16, color: AppColors.success),
                    label: Text('Complete',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.success)),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmCancel(id, title),
                    icon: Icon(Icons.cancel_outlined,
                        size: 16, color: AppColors.warning),
                    label: Text('Cancel',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.warning)),
                  ),
                ],
                TextButton.icon(
                  onPressed: () => _confirmDelete(id, title),
                  icon: Icon(Icons.delete_outlined,
                      size: 16, color: AppColors.error),
                  label: Text('Delete',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonChip(IconData icon, String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(name,
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2 — Dashboard
  // ---------------------------------------------------------------------------

  Widget _buildDashboardTab() {
    final total = _meetings.length;
    final scheduled =
        _meetings.where((m) => m['status'] == 'SCHEDULED').length;
    final completed =
        _meetings.where((m) => m['status'] == 'COMPLETED').length;
    final cancelled =
        _meetings.where((m) => m['status'] == 'CANCELLED').length;

    // Meeting type breakdown
    final typeMap = <String, int>{};
    for (final m in _meetings) {
      final t = m['meetingType'] as String? ?? 'GENERAL';
      typeMap[t] = (typeMap[t] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 16),

          // Bigger stats row
          _buildStatsRow(total, scheduled, completed, cancelled),
          const SizedBox(height: 24),

          // Upcoming meetings
          Text('Upcoming Meetings',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 10),
          if (_upcoming.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('No upcoming meetings.',
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecondary)),
                ),
              ),
            )
          else
            ...(_upcoming.take(5).map((item) {
              final m = Map<String, dynamic>.from(item as Map);
              final title = m['title'] as String? ?? '';
              final date = m['date'] as String? ?? '';
              final startTime = m['startTime'] as String? ?? '';
              final teacherName = m['teacherName'] as String? ?? '';
              final venue = m['venue'] as String? ?? '';

              DateTime? parsedDate;
              try {
                parsedDate = DateTime.parse(date);
              } catch (_) {}

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          parsedDate != null
                              ? DateFormat('dd').format(parsedDate)
                              : '--',
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.info),
                        ),
                        Text(
                          parsedDate != null
                              ? DateFormat('MMM').format(parsedDate)
                              : '',
                          style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: AppColors.info),
                        ),
                      ],
                    ),
                  ),
                  title: Text(title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    [
                      if (startTime.isNotEmpty) startTime,
                      if (teacherName.isNotEmpty) teacherName,
                      if (venue.isNotEmpty) venue,
                    ].join(' | '),
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              );
            })),
          const SizedBox(height: 24),

          // Meeting type breakdown
          Text('Meeting Type Breakdown',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 10),
          if (typeMap.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('No data available.',
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecondary)),
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: typeMap.entries.map((entry) {
                    final pct =
                        total > 0 ? (entry.value / total * 100).round() : 0;
                    final color = switch (entry.key) {
                      'PARENT_TEACHER' => AppColors.info,
                      'STAFF' => AppColors.navy,
                      'GENERAL' => AppColors.gold,
                      _ => AppColors.textSecondary,
                    };
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: Text(entry.key,
                                style: GoogleFonts.poppins(fontSize: 13)),
                          ),
                          Expanded(
                            flex: 3,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: total > 0 ? entry.value / total : 0,
                                backgroundColor: color.withOpacity(0.1),
                                color: color,
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('${entry.value} ($pct%)',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Schedule Meeting Dialog
  // ---------------------------------------------------------------------------

  void _showScheduleDialog({Map<String, dynamic>? meeting}) {
    final isEditing = meeting != null;
    final titleCtrl =
        TextEditingController(text: meeting?['title'] as String? ?? '');
    final descCtrl =
        TextEditingController(text: meeting?['description'] as String? ?? '');
    final teacherNameCtrl =
        TextEditingController(text: meeting?['teacherName'] as String? ?? '');
    final teacherIdCtrl =
        TextEditingController(text: meeting?['teacherId'] as String? ?? '');
    final parentNameCtrl =
        TextEditingController(text: meeting?['parentName'] as String? ?? '');
    final parentIdCtrl =
        TextEditingController(text: meeting?['parentId'] as String? ?? '');
    final studentNameCtrl =
        TextEditingController(text: meeting?['studentName'] as String? ?? '');
    final studentIdCtrl =
        TextEditingController(text: meeting?['studentId'] as String? ?? '');
    final venueCtrl =
        TextEditingController(text: meeting?['venue'] as String? ?? '');
    final durationCtrl = TextEditingController(
        text: (meeting?['duration']?.toString()) ?? '30');

    String meetingType =
        (meeting?['meetingType'] as String?) ?? 'PARENT_TEACHER';
    String? selectedClass = meeting?['className'] as String?;

    DateTime? meetingDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    try {
      if (meeting?['date'] != null) {
        meetingDate = DateTime.parse(meeting!['date'] as String);
      }
    } catch (_) {}
    try {
      if (meeting?['startTime'] != null) {
        final parts = (meeting!['startTime'] as String).split(':');
        startTime =
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    try {
      if (meeting?['endTime'] != null) {
        final parts = (meeting!['endTime'] as String).split(':');
        endTime =
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
            title: Text(
                isEditing ? 'Edit Meeting' : 'Schedule Meeting',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Title *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: meetingType,
                      decoration: const InputDecoration(
                          labelText: 'Meeting Type *'),
                      items: ['PARENT_TEACHER', 'STAFF', 'GENERAL']
                          .map((t) =>
                              DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => meetingType = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: teacherNameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Teacher Name *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: teacherIdCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Teacher ID'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: parentNameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Parent Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: parentIdCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Parent ID'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: studentNameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Student Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: studentIdCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Student ID'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedClass,
                      decoration:
                          const InputDecoration(labelText: 'Class'),
                      items: [
                        const DropdownMenuItem<String>(
                            value: null, child: Text('None')),
                        ...SchoolConstants.baseClasses.map((c) =>
                            DropdownMenuItem(value: c, child: Text(c))),
                      ],
                      onChanged: (v) {
                        setDialogState(() => selectedClass = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    // Date
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        meetingDate != null
                            ? 'Date: ${DateFormat('yyyy-MM-dd').format(meetingDate!)}'
                            : 'Date *',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      trailing:
                          const Icon(Icons.calendar_today, size: 20),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: meetingDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => meetingDate = picked);
                        }
                      },
                    ),
                    // Start Time
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        startTime != null
                            ? 'Start Time: ${startTime!.format(ctx)}'
                            : 'Start Time *',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      trailing: const Icon(Icons.access_time, size: 20),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: startTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => startTime = picked);
                        }
                      },
                    ),
                    // End Time
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        endTime != null
                            ? 'End Time: ${endTime!.format(ctx)}'
                            : 'End Time',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      trailing: const Icon(Icons.access_time, size: 20),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: endTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => endTime = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: durationCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Duration (minutes)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: venueCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Venue *'),
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
                  if (titleCtrl.text.trim().isEmpty ||
                      teacherNameCtrl.text.trim().isEmpty ||
                      meetingDate == null ||
                      startTime == null ||
                      venueCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Please fill all required fields (Title, Teacher, Date, Start Time, Venue)',
                            style: GoogleFonts.poppins()),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }

                  final data = <String, dynamic>{
                    'title': titleCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'meetingType': meetingType,
                    'teacherName': teacherNameCtrl.text.trim(),
                    'teacherId': teacherIdCtrl.text.trim(),
                    'parentName': parentNameCtrl.text.trim(),
                    'parentId': parentIdCtrl.text.trim(),
                    'studentName': studentNameCtrl.text.trim(),
                    'studentId': studentIdCtrl.text.trim(),
                    'date':
                        DateFormat('yyyy-MM-dd').format(meetingDate!),
                    'startTime':
                        '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}',
                    'venue': venueCtrl.text.trim(),
                    'duration':
                        int.tryParse(durationCtrl.text.trim()) ?? 30,
                  };

                  if (endTime != null) {
                    data['endTime'] =
                        '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';
                  }
                  if (selectedClass != null) {
                    data['className'] = selectedClass;
                  }

                  try {
                    if (isEditing) {
                      final id = meeting['id']?.toString() ??
                          meeting['_id']?.toString() ??
                          '';
                      await MeetingApiService.update(id, data);
                    } else {
                      await MeetingApiService.create(data);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              isEditing
                                  ? 'Meeting updated'
                                  : 'Meeting scheduled',
                              style: GoogleFonts.poppins()),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                    _loadData();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e',
                              style: GoogleFonts.poppins()),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                child: Text(isEditing ? 'Update' : 'Schedule'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Complete Meeting Dialog
  // ---------------------------------------------------------------------------

  void _showCompleteDialog(String id) {
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
        title: Text('Complete Meeting',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes *',
              hintText: 'Enter post-meeting notes...',
              alignLabelWithHint: true,
            ),
            maxLines: 4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (notesCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Notes are required',
                        style: GoogleFonts.poppins()),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              try {
                await MeetingApiService.complete(
                    id, notesCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Meeting completed',
                          style: GoogleFonts.poppins()),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
                _loadData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e',
                          style: GoogleFonts.poppins()),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cancel confirmation
  // ---------------------------------------------------------------------------

  void _confirmCancel(String id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel Meeting',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to cancel "$title"?',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await MeetingApiService.cancel(id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Meeting cancelled',
                          style: GoogleFonts.poppins()),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
                _loadData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to cancel: $e',
                          style: GoogleFonts.poppins()),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Delete confirmation
  // ---------------------------------------------------------------------------

  void _confirmDelete(String id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Meeting',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete "$title"?',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await MeetingApiService.delete(id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Meeting deleted',
                          style: GoogleFonts.poppins()),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
                _loadData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e',
                          style: GoogleFonts.poppins()),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
