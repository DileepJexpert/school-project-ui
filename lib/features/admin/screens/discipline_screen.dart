import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/discipline_api_service.dart';

class DisciplineScreen extends StatefulWidget {
  const DisciplineScreen({super.key});

  @override
  State<DisciplineScreen> createState() => _DisciplineScreenState();
}

class _DisciplineScreenState extends State<DisciplineScreen> {
  bool _loading = true;
  List<dynamic> _incidents = [];
  Map<String, dynamic>? _summary;
  String? _filterSeverity;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        DisciplineApiService.getAllIncidents(severity: _filterSeverity),
        DisciplineApiService.getSummary(),
      ]);
      if (mounted) {
        setState(() {
          _incidents = results[0] as List<dynamic>;
          _summary = results[1] as Map<String, dynamic>;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Discipline Management',
                    style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                ),
                onPressed: _showAddIncidentDialog,
                icon: const Icon(Icons.add, size: 18),
                label: Text('Report Incident',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_summary != null) _buildSummaryRow(),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Filter: ', style: GoogleFonts.poppins(fontSize: 13)),
              const SizedBox(width: 8),
              ..._buildFilterChips(),
            ],
          ),
          const SizedBox(height: 16),
          if (_incidents.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                    child: Text('No incidents found.',
                        style: GoogleFonts.poppins(
                            color: AppColors.textSecondary))),
              ),
            )
          else
            ...(_incidents.map((i) => _buildIncidentCard(
                i as Map<String, dynamic>))),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final total = (_summary?['totalIncidents'] as num?)?.toInt() ?? 0;
    final bySeverity =
        (_summary?['bySeverity'] as Map<String, dynamic>?) ?? {};

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _miniCard('Total', '$total', AppColors.navy),
        _miniCard(
            'Warning', '${bySeverity['WARNING'] ?? 0}', Colors.amber),
        _miniCard('Minor', '${bySeverity['MINOR'] ?? 0}', Colors.orange),
        _miniCard('Major', '${bySeverity['MAJOR'] ?? 0}', Colors.deepOrange),
        _miniCard(
            'Critical', '${bySeverity['CRITICAL'] ?? 0}', Colors.red),
      ],
    );
  }

  Widget _miniCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  List<Widget> _buildFilterChips() {
    final severities = [null, 'WARNING', 'MINOR', 'MAJOR', 'CRITICAL'];
    final labels = ['All', 'Warning', 'Minor', 'Major', 'Critical'];
    return List.generate(severities.length, (i) {
      final isSelected = _filterSeverity == severities[i];
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(labels[i], style: GoogleFonts.poppins(fontSize: 12)),
          selected: isSelected,
          selectedColor: AppColors.navy.withOpacity(0.15),
          onSelected: (_) {
            setState(() => _filterSeverity = severities[i]);
            _loadData();
          },
        ),
      );
    });
  }

  Color _severityColor(String severity) {
    return switch (severity) {
      'WARNING' => Colors.amber,
      'MINOR' => Colors.orange,
      'MAJOR' => Colors.deepOrange,
      'CRITICAL' => Colors.red,
      _ => Colors.grey,
    };
  }

  Widget _buildIncidentCard(Map<String, dynamic> incident) {
    final studentName = incident['studentName'] as String? ?? '';
    final className = incident['className'] as String? ?? '';
    final severity = incident['severity'] as String? ?? '';
    final category = incident['category'] as String? ?? '';
    final description = incident['description'] as String? ?? '';
    final resolved = incident['resolved'] as bool? ?? false;
    final date = incident['date'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(studentName,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                Chip(
                  label: Text(severity,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: _severityColor(severity))),
                  backgroundColor: _severityColor(severity).withOpacity(0.1),
                ),
              ],
            ),
            Text('$className | $category | $date',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(description, style: GoogleFonts.poppins(fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  resolved ? Icons.check_circle : Icons.pending,
                  size: 16,
                  color: resolved ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(resolved ? 'Resolved' : 'Open',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: resolved ? Colors.green : Colors.orange)),
              ],
            ),
          ],
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Report Incident',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: studentIdCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Student ID')),
                const SizedBox(height: 8),
                TextField(
                    controller: studentNameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Student Name')),
                const SizedBox(height: 8),
                TextField(
                    controller: classNameCtrl,
                    decoration: const InputDecoration(labelText: 'Class')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: severity,
                  decoration:
                      const InputDecoration(labelText: 'Severity'),
                  items: ['WARNING', 'MINOR', 'MAJOR', 'CRITICAL']
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => severity = v);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration:
                      const InputDecoration(labelText: 'Category'),
                  items: [
                    'BEHAVIORAL',
                    'ACADEMIC',
                    'ATTENDANCE',
                    'BULLYING',
                    'PROPERTY_DAMAGE',
                    'OTHER'
                  ]
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => category = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await DisciplineApiService.createIncident({
                  'studentId': studentIdCtrl.text.trim(),
                  'studentName': studentNameCtrl.text.trim(),
                  'className': classNameCtrl.text.trim(),
                  'severity': severity,
                  'category': category,
                  'description': descriptionCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
