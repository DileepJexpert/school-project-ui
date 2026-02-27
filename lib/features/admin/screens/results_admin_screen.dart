import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/dio_client.dart';

class ResultsAdminScreen extends StatefulWidget {
  const ResultsAdminScreen({super.key});

  @override
  State<ResultsAdminScreen> createState() => _ResultsAdminScreenState();
}

class _ResultsAdminScreenState extends State<ResultsAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _uploading = false;

  // Upload form state
  String? _examType;
  String? _selectedClass;
  String? _academicYear;
  final _subjectCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _marksCtrl = TextEditingController();
  final _maxMarksCtrl = TextEditingController(text: '100');

  final _examTypes = ['Unit Test 1', 'Unit Test 2', 'Half Yearly', 'Annual', 'Pre-Board'];
  final _classes = ['Class 9', 'Class 10', 'Class 11', 'Class 12'];
  final _years = ['2024-2025', '2025-2026'];

  // Sample data — replace with actual API calls
  final List<Map<String, dynamic>> _recentResults = [
    {'studentName': 'Arjun Sharma', 'class': 'Class 10', 'subject': 'Mathematics', 'exam': 'Half Yearly', 'marks': 87, 'maxMarks': 100, 'grade': 'A'},
    {'studentName': 'Priya Patel', 'class': 'Class 10', 'subject': 'Science', 'exam': 'Half Yearly', 'marks': 92, 'maxMarks': 100, 'grade': 'A+'},
    {'studentName': 'Rohan Kumar', 'class': 'Class 9', 'subject': 'English', 'exam': 'Unit Test 2', 'marks': 75, 'maxMarks': 100, 'grade': 'B+'},
    {'studentName': 'Sneha Mishra', 'class': 'Class 12', 'subject': 'Physics', 'exam': 'Pre-Board', 'marks': 68, 'maxMarks': 100, 'grade': 'B'},
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _subjectCtrl.dispose();
    _studentIdCtrl.dispose();
    _marksCtrl.dispose();
    _maxMarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitResult() async {
    if (_examType == null || _selectedClass == null || _academicYear == null ||
        _subjectCtrl.text.isEmpty || _studentIdCtrl.text.isEmpty || _marksCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all required fields.'), backgroundColor: AppColors.warning),
      );
      return;
    }
    setState(() => _uploading = true);
    try {
      await DioClient.post('/results', data: {
        'studentId': _studentIdCtrl.text.trim(),
        'subject': _subjectCtrl.text.trim(),
        'examType': _examType,
        'className': _selectedClass,
        'academicYear': _academicYear,
        'marksObtained': double.tryParse(_marksCtrl.text) ?? 0,
        'maxMarks': double.tryParse(_maxMarksCtrl.text) ?? 100,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Result submitted!'), backgroundColor: AppColors.success),
        );
        _studentIdCtrl.clear();
        _marksCtrl.clear();
        _subjectCtrl.clear();
        setState(() { _examType = null; _selectedClass = null; _academicYear = null; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text('Results Management',
            style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, fontSize: 20)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Upload Results'),
            Tab(text: 'View Results'),
            Tab(text: 'Report Cards'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildUploadTab(), _buildViewTab(), _buildReportCardsTab()],
      ),
    );
  }

  Widget _buildUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Upload Student Result',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.navy)),
            const SizedBox(height: 4),
            Text('Enter marks for a student. Connect to POST /api/results.',
                style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _examType,
              decoration: _dec('Exam Type *'),
              items: _examTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _examType = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedClass,
              decoration: _dec('Class *'),
              items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedClass = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _academicYear,
              decoration: _dec('Academic Year *'),
              items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
              onChanged: (v) => setState(() => _academicYear = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subjectCtrl,
              decoration: _dec('Subject *'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _studentIdCtrl,
              decoration: _dec('Student ID / Admission No. *'),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _marksCtrl,
                  decoration: _dec('Marks Obtained *'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _maxMarksCtrl,
                  decoration: _dec('Max Marks'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _uploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_uploading ? 'Uploading…' : 'Submit Result',
                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 16)),
                onPressed: _uploading ? null : _submitResult,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildViewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Recent Results',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.navy)),
        const SizedBox(height: 4),
        Text('Sample data — connect GET /api/results to load live data.',
            style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
          clipBehavior: Clip.antiAlias,
          child: DataTable(
            columnSpacing: 20,
            columns: ['Student', 'Class', 'Subject', 'Exam', 'Marks', 'Grade']
                .map((h) => DataColumn(
                    label: Text(h,
                        style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 13))))
                .toList(),
            rows: _recentResults
                .map((r) => DataRow(cells: [
                      DataCell(Text(r['studentName'], style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600))),
                      DataCell(Text(r['class'], style: GoogleFonts.nunitoSans())),
                      DataCell(Text(r['subject'], style: GoogleFonts.nunitoSans())),
                      DataCell(Text(r['exam'], style: GoogleFonts.nunitoSans())),
                      DataCell(Text('${r['marks']}/${r['maxMarks']}', style: GoogleFonts.nunitoSans())),
                      DataCell(_gradeChip(r['grade'])),
                    ]))
                .toList(),
          ),
        ),
      ]),
    );
  }

  Widget _buildReportCardsTab() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.navy.withOpacity(0.06),
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          ),
          child: const Icon(Icons.picture_as_pdf_outlined, size: 64, color: AppColors.navy),
        ),
        const SizedBox(height: 20),
        Text('Report Card Generation',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.navy)),
        const SizedBox(height: 8),
        Text('Generate and download class-wise report cards.',
            style: GoogleFonts.nunitoSans(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy, foregroundColor: Colors.white),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Generate Class 10 Report Cards'),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Connect to GET /api/results/report-cards to download'),
                backgroundColor: AppColors.navy),
          ),
        ),
      ]),
    );
  }

  Widget _gradeChip(String grade) {
    Color color;
    switch (grade) {
      case 'A+': color = AppColors.success; break;
      case 'A': color = const Color(0xFF059669); break;
      case 'B+': color = AppColors.info; break;
      case 'B': color = AppColors.warning; break;
      default: color = AppColors.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(grade,
          style: GoogleFonts.nunitoSans(
              color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}
