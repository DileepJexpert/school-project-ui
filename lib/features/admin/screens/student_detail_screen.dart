import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/admission_data.dart';
import '../../../models/fee_models.dart';
import '../../../services/admission_api_service.dart';
import '../../../services/fee_api_service.dart';
import 'fee_collection_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentId;
  const StudentDetailScreen({super.key, required this.studentId});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen>
    with SingleTickerProviderStateMixin {
  Student? _student;
  StudentFeeProfile? _feeProfile;
  bool _loading = true;
  bool _feeLoading = true;
  String _error = '';
  late final TabController _tabCtrl;

  final _fmt = DateFormat('dd MMM yyyy');
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadProfile();
    _loadFees();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final s = await AdmissionApiService.getStudentById(widget.studentId);
      setState(() { _student = s; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadFees() async {
    try {
      final fp = await FeeApiService.getStudentFeeProfile(widget.studentId);
      setState(() { _feeProfile = fp; _feeLoading = false; });
    } catch (_) {
      setState(() => _feeLoading = false); // fee profile may not exist for enquiries
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(
          _student?.fullName ?? 'Student Profile',
          style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.person_outline, size: 18), text: 'Profile'),
            Tab(icon: Icon(Icons.account_balance_wallet_outlined, size: 18), text: 'Fees'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: GoogleFonts.nunitoSans(color: AppColors.error)))
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildProfileTab(_student!),
                    _buildFeesTab(),
                  ],
                ),
    );
  }

  // ─────────────────────────── PROFILE TAB ───────────────────────────────────

  Widget _buildProfileTab(Student s) {
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
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 36, color: AppColors.navy, fontWeight: FontWeight.w700),
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
                      style: GoogleFonts.nunitoSans(
                          color: AppColors.gold, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Adm No: ${s.admissionNumber}',
                      style:
                          GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (s.status.toUpperCase() == 'ACTIVE'
                              ? AppColors.success
                              : AppColors.error)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(s.status,
                        style: GoogleFonts.nunitoSans(
                            fontWeight: FontWeight.w600,
                            color: s.status.toUpperCase() == 'ACTIVE'
                                ? AppColors.success
                                : AppColors.error)),
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
        _section("Father's Details", [
          _row('Name', s.parentDetails.fatherName),
          _row('Occupation', s.parentDetails.fatherOccupation),
          _row('Mobile', s.parentDetails.fatherMobile),
          _row('Email', s.parentDetails.fatherEmail),
        ]),
        const SizedBox(height: 16),
        _section("Mother's Details", [
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

  // ─────────────────────────── FEES TAB ──────────────────────────────────────

  Widget _buildFeesTab() {
    if (_feeLoading) return const Center(child: CircularProgressIndicator());

    if (_feeProfile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textLight),
            const SizedBox(height: 16),
            Text('No fee profile found.',
                style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'A fee profile is generated automatically when a student is admitted '
              'and a fee structure exists for their class.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(color: AppColors.textLight, fontSize: 13),
            ),
          ]),
        ),
      );
    }

    final fp = _feeProfile!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Summary cards
        Row(children: [
          _feeChip('Total', fp.totalFees, AppColors.textPrimary),
          const SizedBox(width: 8),
          _feeChip('Paid', fp.paidFees, AppColors.success),
          const SizedBox(width: 8),
          _feeChip('Due', fp.dueFees, AppColors.error),
        ]),
        const SizedBox(height: 12),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fp.totalFees > 0 ? fp.paidFees / fp.totalFees : 0.0,
            minHeight: 8,
            backgroundColor: AppColors.error.withOpacity(0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          fp.totalFees > 0
              ? '${((fp.paidFees / fp.totalFees) * 100).toStringAsFixed(1)}% paid'
              : 'No fees assigned',
          style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // Collect Fee button (only if dues exist)
        if (fp.dueFees > 0)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.point_of_sale_outlined),
              label: Text('Collect Fee · ${_currency.format(fp.dueFees)} due',
                  style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FeeCollectionScreen(preSelectedStudentId: widget.studentId),
                ),
              ).then((_) => _loadFees()),
            ),
          ),
        const SizedBox(height: 20),

        // Installments
        Text('Installments',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy)),
        const SizedBox(height: 10),
        ...fp.feeInstallments.map((inst) {
          final isPaid = inst.status.toUpperCase() == 'PAID';
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              side: BorderSide(
                  color: isPaid
                      ? AppColors.success.withOpacity(0.3)
                      : AppColors.warning.withOpacity(0.4)),
            ),
            color: isPaid ? AppColors.success.withOpacity(0.04) : Colors.white,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Icon(
                isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isPaid ? AppColors.success : AppColors.warning,
              ),
              title: Text(inst.installmentName,
                  style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w600,
                      decoration: isPaid ? TextDecoration.lineThrough : null,
                      color: isPaid ? AppColors.textSecondary : AppColors.textPrimary)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_currency.format(inst.amountDue),
                      style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w700,
                          color: isPaid ? AppColors.success : AppColors.error)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          (isPaid ? AppColors.success : AppColors.warning).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(inst.status,
                        style: GoogleFonts.nunitoSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isPaid ? AppColors.success : AppColors.warning)),
                  ),
                ],
              ),
            ),
          );
        }),

        // Last payment info
        if (fp.lastPayment != null) ...[
          const SizedBox(height: 20),
          Text('Last Payment',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy)),
          const SizedBox(height: 10),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _payRow('Receipt No.', fp.lastPayment!.receiptNumber),
                _payRow('Amount', _currency.format(fp.lastPayment!.amountPaid)),
                _payRow('Mode', fp.lastPayment!.paymentMode),
                _payRow('Date', _fmt.format(fp.lastPayment!.paymentDate)),
                if (fp.lastPayment!.discount > 0)
                  _payRow('Discount', _currency.format(fp.lastPayment!.discount)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  // ─────────────────────────── SHARED WIDGETS ────────────────────────────────

  Widget _feeChip(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Text(_currency.format(value),
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _payRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
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
                style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
