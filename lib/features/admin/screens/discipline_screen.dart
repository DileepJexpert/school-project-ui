import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../services/discipline_api_service.dart';

class DisciplineScreen extends StatefulWidget {
  const DisciplineScreen({super.key});

  @override
  State<DisciplineScreen> createState() => _DisciplineScreenState();
}

class _DisciplineScreenState extends State<DisciplineScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _incidents = [];
  Map<String, dynamic> _summary = {};
  String? _filterSeverity;
  String _filterStatus = 'ALL'; // ALL, OPEN, RESOLVED
  String _searchQuery = '';

  static const _severities = [null, 'WARNING', 'MINOR', 'MAJOR', 'CRITICAL'];
  static const _categories = [
    'BEHAVIORAL',
    'ACADEMIC',
    'ATTENDANCE',
    'BULLYING',
    'PROPERTY_DAMAGE',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        DisciplineApiService.getAllIncidents(severity: _filterSeverity),
        DisciplineApiService.getSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _incidents = (results[0] as List<dynamic>)
            .map((item) => item as Map<String, dynamic>)
            .toList();
        _summary = results[1] as Map<String, dynamic>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _severityColor(String? severity) => switch (severity) {
        'WARNING' => AppColors.info,
        'MINOR' => const Color(0xFFD97706),
        'MAJOR' => const Color(0xFFEA580C),
        'CRITICAL' => AppColors.error,
        _ => AppColors.textSecondary,
      };

  IconData _categoryIcon(String? category) => switch (category) {
        'BEHAVIORAL' => Icons.psychology_outlined,
        'ACADEMIC' => Icons.menu_book_outlined,
        'ATTENDANCE' => Icons.event_busy_outlined,
        'BULLYING' => Icons.warning_amber_rounded,
        'PROPERTY_DAMAGE' => Icons.handyman_outlined,
        _ => Icons.gavel_outlined,
      };

  int _summaryCount(String key) {
    final bySeverity = (_summary['bySeverity'] as Map<String, dynamic>?) ?? {};
    return (bySeverity[key] as num?)?.toInt() ?? 0;
  }

  int get _openCount =>
      _incidents.where((incident) => incident['resolved'] != true).length;

  int get _resolvedCount =>
      _incidents.where((incident) => incident['resolved'] == true).length;

  List<Map<String, dynamic>> get _filteredIncidents {
    final query = _searchQuery.trim().toLowerCase();
    return _incidents.where((inc) {
      final isResolved = inc['resolved'] == true;
      if (_filterStatus == 'OPEN' && isResolved) return false;
      if (_filterStatus == 'RESOLVED' && !isResolved) return false;

      if (query.isEmpty) return true;
      final text = [
        inc['studentName'],
        inc['studentId'],
        inc['className'],
        inc['category'],
        inc['severity'],
        inc['description'],
        inc['resolution'],
      ].whereType<String>().join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final filtered = _filteredIncidents;

    return AdminPageScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdminPageHeader(
          title: 'Discipline & Conduct Records',
          subtitle:
              'Record behavioral incidents, coordinate parent follow-ups, and log disciplinary resolutions.',
          icon: Icons.gavel_outlined,
          actions: [
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Refresh'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.brand,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _showAddIncidentDialog,
              icon: const Icon(Icons.add_alert_rounded, size: 17),
              label: const Text('Report Incident'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading)
          const SizedBox(
            height: 260,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _errorState()
        else ...[
          _summaryCards(),
          const SizedBox(height: 14),
          _searchAndFilterRow(),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            _emptyState()
          else
            ...filtered.map(_incidentCard),
        ],
      ]),
    );
  }

  Widget _summaryCards() {
    final total = (_summary['totalIncidents'] as num?)?.toInt() ?? _incidents.length;
    final majorAndCritical =
        _summaryCount('MAJOR') + _summaryCount('CRITICAL');

    final cards = [
      _clickableMetricCard(
        title: 'Total Logged',
        value: '$total',
        icon: Icons.assignment_outlined,
        color: context.palette.brand,
        caption: 'All records',
        isSelected: _filterStatus == 'ALL' && _filterSeverity == null,
        onTap: () => setState(() {
          _filterStatus = 'ALL';
          _filterSeverity = null;
        }),
      ),
      _clickableMetricCard(
        title: 'Open / Pending',
        value: '$_openCount',
        icon: Icons.pending_actions_outlined,
        color: _openCount == 0 ? AppColors.success : const Color(0xFFD97706),
        caption: 'Needs resolution',
        isSelected: _filterStatus == 'OPEN',
        onTap: () => setState(() => _filterStatus = 'OPEN'),
      ),
      _clickableMetricCard(
        title: 'Resolved',
        value: '$_resolvedCount',
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.success,
        caption: 'Action completed',
        isSelected: _filterStatus == 'RESOLVED',
        onTap: () => setState(() => _filterStatus = 'RESOLVED'),
      ),
      _clickableMetricCard(
        title: 'High Severity',
        value: '$majorAndCritical',
        icon: Icons.warning_amber_rounded,
        color: AppColors.error,
        caption: 'Major & Critical',
        isSelected: _filterSeverity == 'MAJOR' || _filterSeverity == 'CRITICAL',
        onTap: () => setState(() {
          _filterSeverity = 'CRITICAL';
          _loadData();
        }),
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 980
          ? 4
          : constraints.maxWidth > 640
              ? 2
              : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children:
            cards.map((card) => SizedBox(width: width, child: card)).toList(),
      );
    });
  }

  Widget _clickableMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String caption,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : palette.border.withValues(alpha: 0.6),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : palette.brand,
                    ),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    caption,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 11,
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

  Widget _searchAndFilterRow() {
    final palette = context.palette;
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Search field
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by student name, ID, class, or keyword...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                filled: true,
                fillColor: palette.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: palette.border.withValues(alpha: 0.6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: palette.border.withValues(alpha: 0.6)),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Chips Row: Status + Severity
            Row(
              children: [
                // Status Filter Chips
                Wrap(
                  spacing: 6,
                  children: [
                    _statusChoiceChip('All Status', 'ALL'),
                    _statusChoiceChip('Open', 'OPEN',
                        color: const Color(0xFFD97706)),
                    _statusChoiceChip('Resolved', 'RESOLVED',
                        color: AppColors.success),
                  ],
                ),
                const SizedBox(width: 8),
                Container(
                    width: 1,
                    height: 24,
                    color: palette.border.withValues(alpha: 0.6)),
                const SizedBox(width: 8),

                // Severity Filter Chips
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _severities.map((severity) {
                        final selected = _filterSeverity == severity;
                        final label =
                            severity == null ? 'All Severity' : _title(severity);
                        final color = _severityColor(severity);
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: selected,
                            selectedColor: color.withValues(alpha: 0.12),
                            labelStyle: GoogleFonts.nunitoSans(
                              color: selected ? color : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? color
                                  : palette.border.withValues(alpha: 0.6),
                            ),
                            onSelected: (_) {
                              setState(() => _filterSeverity = severity);
                              _loadData();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Text(
                  '${_filteredIncidents.length} incidents',
                  style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChoiceChip(String label, String value, {Color? color}) {
    final selected = _filterStatus == value;
    final chipColor = color ?? context.palette.brand;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: chipColor.withValues(alpha: 0.12),
      labelStyle: GoogleFonts.nunitoSans(
        color: selected ? chipColor : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      side: BorderSide(
        color: selected
            ? chipColor
            : context.palette.border.withValues(alpha: 0.6),
      ),
      onSelected: (_) => setState(() => _filterStatus = value),
    );
  }

  Widget _incidentCard(Map<String, dynamic> incident) {
    final severity = incident['severity'] as String? ?? 'MINOR';
    final category = incident['category'] as String? ?? 'BEHAVIORAL';
    final color = _severityColor(severity);
    final resolved = incident['resolved'] == true;
    final description = incident['description'] as String? ?? '';
    final resolution = incident['resolution'] as String? ?? '';
    final studentName = incident['studentName'] as String? ?? 'Student';
    final studentId = incident['studentId'] as String? ?? '';
    final className = incident['className'] as String? ?? '';
    final date = incident['date'] as String? ?? '';
    final id = incident['id'] as String?;
    final palette = context.palette;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: resolved
              ? palette.border.withValues(alpha: 0.6)
              : color.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(_categoryIcon(category), color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            studentName,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: palette.brand,
                              fontSize: 15,
                            ),
                          ),
                          if (studentId.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: palette.border.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                studentId,
                                style: GoogleFonts.nunitoSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (className.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: palette.brand.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(className,
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: palette.brand)),
                            ),
                          Text(
                            _title(category),
                            style: GoogleFonts.nunitoSans(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          if (date.isNotEmpty)
                            Text(
                              '•  $date',
                              style: GoogleFonts.nunitoSans(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Severity chip
                _statusPill(_title(severity), color),
                const SizedBox(width: 6),

                // Resolved status pill
                _statusPill(
                  resolved ? 'Resolved' : 'Pending',
                  resolved ? AppColors.success : const Color(0xFFD97706),
                ),
              ],
            ),

            // Incident Description
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: palette.border.withValues(alpha: 0.5)),
                ),
                child: Text(
                  description,
                  style: GoogleFonts.nunitoSans(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],

            // Resolution Note if resolved
            if (resolved && resolution.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Resolution: $resolution',
                        style: GoogleFonts.nunitoSans(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action footer
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  resolved
                      ? Icons.check_circle_outline_rounded
                      : Icons.pending_actions_outlined,
                  color: resolved ? AppColors.success : const Color(0xFFD97706),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  resolved
                      ? 'Case closed and recorded'
                      : 'Pending administrative action or parent notice',
                  style: GoogleFonts.nunitoSans(
                    color: resolved ? AppColors.success : const Color(0xFFD97706),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),

                // Parent Notify Mockup
                if (!resolved)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: palette.brand,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => _notifyParent(studentName),
                    icon: const Icon(Icons.send_outlined, size: 15),
                    label: const Text('Notify Parent'),
                  ),

                // Resolve Button
                if (!resolved && id != null && id.isNotEmpty)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _resolveIncident(id),
                    icon: const Icon(Icons.done_all_rounded, size: 15),
                    label: const Text('Resolve'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _notifyParent(String studentName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Disciplinary alert notification dispatched to $studentName\'s parents.'),
        backgroundColor: context.palette.brand,
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.verified_user_outlined,
                size: 56, color: AppColors.success.withValues(alpha: 0.75)),
            const SizedBox(height: 14),
            Text(
              'No incidents found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'No behavioral or disciplinary records match your criteria.',
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _errorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              'Could not load discipline data',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
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
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Retry'),
            ),
          ]),
        ),
      ),
    );
  }

  void _showAddIncidentDialog() {
    final studentIdCtrl = TextEditingController();
    final studentNameCtrl = TextEditingController();
    String? selectedClass;
    final descriptionCtrl = TextEditingController();
    String severity = 'MINOR';
    String category = 'BEHAVIORAL';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'Report Disciplinary Incident',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: studentIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Student ID *',
                    hintText: 'e.g. STU-1049',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: studentNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Student Name *',
                    hintText: 'e.g. Aarav Sharma',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedClass,
                  decoration: const InputDecoration(
                    labelText: 'Class *',
                    prefixIcon: Icon(Icons.class_outlined),
                  ),
                  items: SchoolConstants.allClasses
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedClass = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: severity,
                  decoration: const InputDecoration(
                    labelText: 'Severity *',
                    prefixIcon: Icon(Icons.report_problem_outlined),
                  ),
                  items: ['WARNING', 'MINOR', 'MAJOR', 'CRITICAL']
                      .map((item) => DropdownMenuItem(
                          value: item, child: Text(_title(item))))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => severity = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _categories
                      .map((item) => DropdownMenuItem(
                          value: item, child: Text(_title(item))))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => category = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Incident Description *',
                    hintText: 'Describe what occurred, location, and witnesses...',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.palette.brand,
              ),
              onPressed: () async {
                if (studentNameCtrl.text.trim().isEmpty ||
                    descriptionCtrl.text.trim().isEmpty) {
                  _snack('Student name and description are required.',
                      isError: true);
                  return;
                }
                try {
                  await DisciplineApiService.createIncident({
                    'studentId': studentIdCtrl.text.trim(),
                    'studentName': studentNameCtrl.text.trim(),
                    'className': selectedClass ?? '',
                    'severity': severity,
                    'category': category,
                    'description': descriptionCtrl.text.trim(),
                  });
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _snack('Incident reported successfully.');
                  _loadData();
                } catch (e) {
                  _snack('Failed to report incident: $e', isError: true);
                }
              },
              child: const Text('Submit Record'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolveIncident(String id) async {
    final resolutionCtrl = TextEditingController();
    String actionType = 'Parent Notified & Counselled';
    final actionPresets = [
      'Parent Notified & Counselled',
      'Behavioral Contract Signed',
      'Verbal Warning Issued',
      'Detention / Community Service',
      'Matter Resolved - No Further Action',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
            'Resolve Incident',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: actionType,
                  decoration: const InputDecoration(
                    labelText: 'Action / Resolution Type',
                    prefixIcon: Icon(Icons.assignment_turned_in_outlined),
                  ),
                  items: actionPresets
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => actionType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: resolutionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Resolution Remarks',
                    hintText: 'Enter specific corrective action or outcome...',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Mark Resolved'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    try {
      final combined = resolutionCtrl.text.trim().isEmpty
          ? actionType
          : '$actionType: ${resolutionCtrl.text.trim()}';
      await DisciplineApiService.resolveIncident(id, combined);
      _snack('Incident marked as resolved.');
      _loadData();
    } catch (e) {
      _snack('Resolve failed: $e', isError: true);
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

  String _title(String value) {
    return value
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((part) =>
            part.isEmpty ? '' : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
