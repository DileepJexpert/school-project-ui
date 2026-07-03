import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../services/dio_client.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  String? _selectedSession;
  String? _selectedClass;
  final _rollController = TextEditingController();
  bool _searched = false;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _resultItems = [];
  String _studentName = '';

  final sessions = ['2025-26', '2024-25', '2023-24'];
  final classes = ['Grade 10', 'Grade 12'];

  @override
  void dispose() {
    _rollController.dispose();
    super.dispose();
  }

  Future<void> _handleSearch() async {
    if (_selectedSession == null ||
        _selectedClass == null ||
        _rollController.text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _resultItems = [];
      _searched = false;
    });
    try {
      final response = await DioClient.get('/results', queryParams: {
        'rollNumber': _rollController.text.trim(),
        'className': _selectedClass,
        'academicYear': _selectedSession,
      });
      final list = (response.data as List).cast<Map<String, dynamic>>();
      setState(() {
        _resultItems = list;
        _studentName = list.isNotEmpty
            ? (list.first['studentName'] ?? 'Student').toString()
            : '';
        _searched = true;
      });
    } catch (e) {
      setState(() => _error = 'Could not load results: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: AppRouter.results,
      child: Column(
        children: [
          const PageHeader(
              title: 'Student Results',
              subtitle: 'View board examination results'),
          SectionWrapper(
            backgroundColor: AppColors.white,
            child: Column(
              children: [
                const SectionTitle(title: 'Search Results', centered: true),
                const SizedBox(height: 8),
                Text(
                  'Enter your details to view your board examination results.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 32),

                // Search form
                Container(
                  constraints: const BoxConstraints(maxWidth: 700),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedSession,
                              decoration: const InputDecoration(
                                  hintText: 'Academic Session'),
                              items: sessions
                                  .map((s) => DropdownMenuItem(
                                      value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedSession = v),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedClass,
                              decoration:
                                  const InputDecoration(hintText: 'Class'),
                              items: classes
                                  .map((c) => DropdownMenuItem(
                                      value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedClass = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _rollController,
                              decoration: const InputDecoration(
                                  hintText: 'Roll Number'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _handleSearch,
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('Search'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Results display
                if (_loading) ...[
                  const SizedBox(height: 36),
                  const CircularProgressIndicator(),
                ] else if (_error != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.07),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(_error!,
                              style: GoogleFonts.nunitoSans(
                                  color: AppColors.error))),
                    ]),
                  ),
                ] else if (_searched) ...[
                  const SizedBox(height: 36),
                  _buildResultCard(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context) {
    if (_resultItems.isEmpty) {
      return Text('No results found for this roll number.',
          style: GoogleFonts.nunitoSans(color: AppColors.textSecondary));
    }

    double total = 0, maxTotal = 0;
    for (final r in _resultItems) {
      total += (r['marksObtained'] ?? 0) is num
          ? (r['marksObtained'] as num).toDouble()
          : 0;
      maxTotal += (r['maxMarks'] ?? 100) is num
          ? (r['maxMarks'] as num).toDouble()
          : 100;
    }
    final pct =
        maxTotal > 0 ? (total / maxTotal * 100).toStringAsFixed(1) : '0';
    final pass = maxTotal > 0 && (total / maxTotal) >= 0.33;

    return Container(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Column(children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: AppColors.navy,
          child: Column(children: [
            Text('Result Card',
                style: GoogleFonts.cormorantGaramond(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Student: $_studentName  |  Roll: ${_rollController.text}  |  Class: $_selectedClass',
              style: GoogleFonts.nunitoSans(
                  color: AppColors.goldLight, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ]),
        ),

        // Marks table
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.creamDark),
            headingTextStyle: GoogleFonts.nunitoSans(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 13),
            dataTextStyle: GoogleFonts.nunitoSans(fontSize: 13),
            border: TableBorder.all(color: AppColors.border, width: 0.5),
            columnSpacing: 40,
            columns: const [
              DataColumn(label: Text('Subject')),
              DataColumn(label: Text('Exam')),
              DataColumn(label: Text('Marks'), numeric: true),
              DataColumn(label: Text('Max'), numeric: true),
              DataColumn(label: Text('Grade')),
            ],
            rows: _resultItems
                .map((r) => DataRow(cells: [
                      DataCell(Text(r['subject']?.toString() ?? '—')),
                      DataCell(Text(r['examType']?.toString() ?? '—')),
                      DataCell(Text('${r['marksObtained'] ?? '—'}',
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text('${r['maxMarks'] ?? 100}')),
                      DataCell(Text(r['grade']?.toString() ?? '—',
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w700))),
                    ]))
                .toList(),
          ),
        ),

        // Summary row
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppColors.goldPale,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total: ${total.toInt()} / ${maxTotal.toInt()}',
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              Text('Percentage: $pct%',
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                color: pass ? AppColors.success : AppColors.error,
                child: Text(pass ? 'PASS' : 'FAIL',
                    style: GoogleFonts.nunitoSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
