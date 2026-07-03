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
        'MINOR' => AppColors.warning,
        'MAJOR' => const Color(0xFFF97316),
        'CRITICAL' => AppColors.error,
        _ => AppColors.textSecondary,
      };

  int _summaryCount(String key) {
    final bySeverity = (_summary['bySeverity'] as Map<String, dynamic>?) ?? {};
    return (bySeverity[key] as num?)?.toInt() ?? 0;
  }

  int get _openCount =>
      _incidents.where((incident) => incident['resolved'] != true).length;

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdminPageHeader(
          title: 'Discipline',
          subtitle:
              'Track incidents, severity and resolution actions without losing context.',
          icon: Icons.gavel_outlined,
          actions: [
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Refresh'),
            ),
            ElevatedButton.icon(
              onPressed: _showAddIncidentDialog,
              icon: const Icon(Icons.add_rounded, size: 17),
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
          _filterRow(),
          const SizedBox(height: 14),
          if (_incidents.isEmpty)
            _emptyState()
          else
            ..._incidents.map(_incidentCard),
        ],
      ]),
    );
  }

  Widget _summaryCards() {
    final total = (_summary['totalIncidents'] as num?)?.toInt() ?? 0;
    final cards = [
      AdminMetricCard(
        title: 'Total Incidents',
        value: '$total',
        icon: Icons.fact_check_outlined,
        color: context.palette.brand,
        caption: 'All records',
      ),
      AdminMetricCard(
        title: 'Open',
        value: '$_openCount',
        icon: Icons.pending_actions_outlined,
        color: _openCount == 0 ? AppColors.success : AppColors.warning,
        caption: 'Needs closure',
      ),
      AdminMetricCard(
        title: 'Major',
        value: '${_summaryCount('MAJOR')}',
        icon: Icons.priority_high_rounded,
        color: const Color(0xFFF97316),
        caption: 'Escalated',
      ),
      AdminMetricCard(
        title: 'Critical',
        value: '${_summaryCount('CRITICAL')}',
        icon: Icons.report_problem_outlined,
        color: AppColors.error,
        caption: 'Immediate attention',
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

  Widget _filterRow() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.filter_alt_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _severities.map((severity) {
                  final selected = _filterSeverity == severity;
                  final label = severity == null ? 'All' : _title(severity);
                  final color = _severityColor(severity);
                  return Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      selectedColor: color.withValues(alpha: 0.12),
                      labelStyle: GoogleFonts.nunitoSans(
                        color: selected ? color : AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: selected ? color : context.palette.border,
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
            '${_incidents.length} shown',
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _incidentCard(Map<String, dynamic> incident) {
    final severity = incident['severity'] as String? ?? '';
    final color = _severityColor(severity);
    final resolved = incident['resolved'] == true;
    final description = incident['description'] as String? ?? '';
    final id = incident['id'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(Icons.gavel_outlined, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident['studentName'] as String? ?? 'Unknown student',
                      style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        incident['className'] as String? ?? '',
                        _title(incident['category'] as String? ?? ''),
                        incident['date'] as String? ?? '',
                      ].where((item) => item.isNotEmpty).join(' - '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ]),
            ),
            const SizedBox(width: 10),
            _statusPill(resolved ? 'Resolved' : _title(severity),
                resolved ? AppColors.success : color),
          ]),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: GoogleFonts.nunitoSans(
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Icon(
              resolved ? Icons.check_circle_outline : Icons.pending_outlined,
              color: resolved ? AppColors.success : AppColors.warning,
              size: 17,
            ),
            const SizedBox(width: 6),
            Text(
              resolved ? 'Closed' : 'Open for follow-up',
              style: GoogleFonts.nunitoSans(
                color: resolved ? AppColors.success : AppColors.warning,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            if (!resolved && id != null && id.isNotEmpty)
              TextButton.icon(
                onPressed: () => _resolveIncident(id),
                icon: const Icon(Icons.done_rounded, size: 16),
                label: const Text('Resolve'),
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunitoSans(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.verified_outlined,
                size: 52, color: AppColors.success.withValues(alpha: 0.75)),
            const SizedBox(height: 12),
            Text(
              'No incidents found',
              style: GoogleFonts.nunitoSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'No discipline records match the current filter.',
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
    final classNameCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    String severity = 'MINOR';
    String category = 'BEHAVIORAL';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'Report Incident',
            style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: studentIdCtrl,
                  decoration: const InputDecoration(labelText: 'Student ID'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: studentNameCtrl,
                  decoration: const InputDecoration(labelText: 'Student Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: classNameCtrl,
                  decoration: const InputDecoration(labelText: 'Class'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: severity,
                  decoration: const InputDecoration(labelText: 'Severity'),
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
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
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
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
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
            ElevatedButton(
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
                    'className': classNameCtrl.text.trim(),
                    'severity': severity,
                    'category': category,
                    'description': descriptionCtrl.text.trim(),
                  });
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _snack('Incident reported.');
                  _loadData();
                } catch (e) {
                  _snack('Failed to report incident: $e', isError: true);
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolveIncident(String id) async {
    final resolutionCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Incident'),
        content: TextField(
          controller: resolutionCtrl,
          decoration: const InputDecoration(labelText: 'Resolution note'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DisciplineApiService.resolveIncident(
        id,
        resolutionCtrl.text.trim().isEmpty
            ? 'Resolved by admin'
            : resolutionCtrl.text.trim(),
      );
      _snack('Incident resolved.');
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
