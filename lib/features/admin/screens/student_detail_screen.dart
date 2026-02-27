import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/admission_data.dart';
import '../../../services/admission_api_service.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentId;
  const StudentDetailScreen({super.key, required this.studentId});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  Student? _student;
  bool _loading = true;
  String _error = '';
  final _fmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await AdmissionApiService.getStudentById(widget.studentId);
      setState(() { _student = s; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text('Student Profile',
            style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: GoogleFonts.nunitoSans(color: AppColors.error)))
              : _buildProfile(_student!),
    );
  }

  Widget _buildProfile(Student s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.navy.withOpacity(0.1),
                child: Text(
                  s.fullName.substring(0, 1).toUpperCase(),
                  style: GoogleFonts.cormorantGaramond(fontSize: 36, color: AppColors.navy, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.fullName,
                      style: GoogleFonts.cormorantGaramond(
                          fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.navy)),
                  const SizedBox(height: 4),
                  Text('${s.classForAdmission} · ${s.academicYear}',
                      style: GoogleFonts.nunitoSans(color: AppColors.gold, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Adm No: ${s.admissionNumber}',
                      style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (s.status.toUpperCase() == 'ACTIVE' ? AppColors.success : AppColors.error)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(s.status,
                        style: GoogleFonts.nunitoSans(
                            fontWeight: FontWeight.w600,
                            color: s.status.toUpperCase() == 'ACTIVE' ? AppColors.success : AppColors.error)),
                  ),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        _section('Personal Information', [
          _row('Date of Birth', _fmt.format(s.dateOfBirth)),
          _row('Gender', s.gender),
          _row('Blood Group', s.bloodGroup),
          _row('Nationality', s.nationality),
          _row('Religion', s.religion),
          _row('Mother Tongue', s.motherTongue),
          _row('Aadhar Number', s.aadharNumber.isEmpty ? '—' : s.aadharNumber),
          _row('Date of Admission', _fmt.format(s.dateOfAdmission)),
        ]),
        const SizedBox(height: 16),
        _section('Father\'s Details', [
          _row('Name', s.parentDetails.fatherName),
          _row('Occupation', s.parentDetails.fatherOccupation),
          _row('Mobile', s.parentDetails.fatherMobile),
          _row('Email', s.parentDetails.fatherEmail),
        ]),
        const SizedBox(height: 16),
        _section('Mother\'s Details', [
          _row('Name', s.parentDetails.motherName),
          _row('Occupation', s.parentDetails.motherOccupation),
          _row('Mobile', s.parentDetails.motherMobile),
          _row('Email', s.parentDetails.motherEmail),
        ]),
        const SizedBox(height: 16),
        _section('Contact Information', [
          _row('Permanent Address', s.contactDetails.permanentAddress),
          _row('Correspondence Address', s.contactDetails.correspondenceAddress),
          _row('Primary Contact', s.contactDetails.primaryContactNumber),
        ]),
        if (s.previousSchoolDetails.schoolName.isNotEmpty) ...[
          const SizedBox(height: 16),
          _section('Previous School', [
            _row('School Name', s.previousSchoolDetails.schoolName),
            _row('Last Class', s.previousSchoolDetails.lastClass),
            _row('Board', s.previousSchoolDetails.board),
          ]),
        ],
      ]),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(title,
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy)),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label,
                style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '—' : value,
                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
