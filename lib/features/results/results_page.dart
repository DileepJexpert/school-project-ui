import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/public_colors.dart';
import '../../core/constants/academic_year.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/searchable_dropdown.dart';

import '../../services/dio_client.dart';
import '../../services/auth_service.dart';

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

  final sessions = AcademicYear.choices(short: true).reversed.toList();
  final classes = SchoolConstants.allClasses
      .where(
        (name) =>
            name.startsWith('Class 10 -') || name.startsWith('Class 12 -'),
      )
      .toList();

  @override
  void dispose() {
    _rollController.dispose();
    super.dispose();
  }

  Future<void> _handleSearch() async {
    if (!AuthService.instance
        .hasAnyRole(const ['SUPER_ADMIN', 'SCHOOL_ADMIN', 'TEACHER'])) {
      setState(() => _error =
          'Sign in as school staff to search published results. Students and parents can view their own results in their portals.');
      return;
    }
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
            backgroundColor: PublicColors.white,
            child: Column(
              children: [
                const SectionTitle(title: 'Search Results', centered: true),
                const SizedBox(height: 8),
                Text(
                  'Enter your details to view your board examination results.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunitoSans(
                      color: PublicColors.textSecondary, fontSize: 14),
                ),
                if (!AuthService.instance.isLoggedIn)
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRouter.login),
                    child: const Text('Sign in to view results'),
                  ),
                const SizedBox(height: 32),

                // Search form
                Container(
                  constraints: const BoxConstraints(maxWidth: 720),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A101828),
                        blurRadius: 18,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SearchableDropdownFormField<String>(
                              labelText: 'Academic Session',
                              hintText: 'Select or type session...',
                              initialValue: _selectedSession,
                              items: sessions,
                              onChanged: (v) => setState(() => _selectedSession = v),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SearchableDropdownFormField<String>(
                              labelText: 'Class',
                              hintText: 'Select or type class...',
                              initialValue: _selectedClass,
                              items: classes,
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
                              decoration: const InputDecoration(
                                labelText: 'Roll Number',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _handleSearch,
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('Search'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PublicColors.navy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      color: PublicColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: PublicColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline,
                          color: PublicColors.error),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(_error!,
                              style: GoogleFonts.nunitoSans(
                                  color: PublicColors.error))),
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
          style: GoogleFonts.nunitoSans(color: PublicColors.textSecondary));
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
    final pass = _resultItems.every((row) => row['isPassed'] == true);

    return Container(
      constraints: const BoxConstraints(maxWidth: 720),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A101828),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: PublicColors.navy,
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
                  color: PublicColors.goldLight, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ]),
        ),

        // Marks table
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(PublicColors.creamDark),
            headingTextStyle: GoogleFonts.nunitoSans(
                color: PublicColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 13),
            dataTextStyle: GoogleFonts.nunitoSans(fontSize: 13),
            border: TableBorder.all(color: PublicColors.border, width: 0.5),
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
                              color: PublicColors.gold,
                              fontWeight: FontWeight.w700))),
                    ]))
                .toList(),
          ),
        ),

        // Summary row
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: PublicColors.goldPale,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total: ${total.toInt()} / ${maxTotal.toInt()}',
                  style: GoogleFonts.nunitoSans(
                      color: PublicColors.navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              Text('Percentage: $pct%',
                  style: GoogleFonts.nunitoSans(
                      color: PublicColors.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: pass ? PublicColors.success : PublicColors.error,
                  borderRadius: BorderRadius.circular(6),
                ),
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
