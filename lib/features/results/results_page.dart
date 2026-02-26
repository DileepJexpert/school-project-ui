import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/responsive.dart';

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

  // TODO: Replace with DioClient.get('/results/sessions') etc.
  final sessions = ['2025-26', '2024-25', '2023-24'];
  final classes = ['Grade 10', 'Grade 12'];

  @override
  void dispose() {
    _rollController.dispose();
    super.dispose();
  }

  void _handleSearch() {
    if (_selectedSession != null && _selectedClass != null && _rollController.text.isNotEmpty) {
      // TODO: Replace with API call: DioClient.get('/results', queryParams: {...})
      setState(() => _searched = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: AppRouter.results,
      child: Column(
        children: [
          const PageHeader(title: 'Student Results', subtitle: 'View board examination results'),
          SectionWrapper(
            backgroundColor: AppColors.white,
            child: Column(
              children: [
                const SectionTitle(title: 'Search Results', centered: true),
                const SizedBox(height: 8),
                Text(
                  'Enter your details to view your board examination results.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 14),
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
                              value: _selectedSession,
                              decoration: const InputDecoration(hintText: 'Academic Session'),
                              items: sessions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => setState(() => _selectedSession = v),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedClass,
                              decoration: const InputDecoration(hintText: 'Class'),
                              items: classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) => setState(() => _selectedClass = v),
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
                              decoration: const InputDecoration(hintText: 'Roll Number'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _handleSearch,
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('Search'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Results display
                if (_searched) ...[
                  const SizedBox(height: 36),
                  _buildSampleResult(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleResult(BuildContext context) {
    // Sample data — replace with API response
    final subjects = [
      {'name': 'English', 'marks': '88', 'grade': 'A'},
      {'name': 'Mathematics', 'marks': '92', 'grade': 'A+'},
      {'name': 'Science', 'marks': '85', 'grade': 'A'},
      {'name': 'Social Studies', 'marks': '78', 'grade': 'B+'},
      {'name': 'Hindi', 'marks': '82', 'grade': 'A'},
    ];

    return Container(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Column(
        children: [
          // Student info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: AppColors.navy,
            child: Column(
              children: [
                Text('Result Card', style: GoogleFonts.cormorantGaramond(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Student: Sample Student  |  Roll: ${_rollController.text}  |  Class: $_selectedClass',
                  style: GoogleFonts.nunitoSans(color: AppColors.goldLight, fontSize: 13),
                ),
              ],
            ),
          ),

          // Marks table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.creamDark),
              headingTextStyle: GoogleFonts.nunitoSans(
                color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 13),
              dataTextStyle: GoogleFonts.nunitoSans(fontSize: 13),
              border: TableBorder.all(color: AppColors.border, width: 0.5),
              columnSpacing: 48,
              columns: const [
                DataColumn(label: Text('Subject')),
                DataColumn(label: Text('Marks (100)'), numeric: true),
                DataColumn(label: Text('Grade')),
              ],
              rows: subjects.map((s) => DataRow(cells: [
                DataCell(Text(s['name']!)),
                DataCell(Text(s['marks']!, style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(s['grade']!, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700))),
              ])).toList(),
            ),
          ),

          // Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.goldPale,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total: 425 / 500', style: GoogleFonts.nunitoSans(
                  color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 15)),
                Text('Percentage: 85%', style: GoogleFonts.nunitoSans(
                  color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  color: AppColors.success,
                  child: Text('PASS', style: GoogleFonts.nunitoSans(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
