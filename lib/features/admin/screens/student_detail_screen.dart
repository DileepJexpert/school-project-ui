import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../models/admission_data.dart';
import '../../../models/fee_models.dart';
import '../../../services/admission_api_service.dart';
import '../../../services/admission_print_service.dart';
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
    _tabCtrl = TabController(length: 3, vsync: this);
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
      if (mounted) setState(() { _student = s; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadFees() async {
    try {
      final fp = await FeeApiService.getStudentFeeProfile(widget.studentId);
      if (mounted) setState(() { _feeProfile = fp; _feeLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _feeLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.surface,
      appBar: AppBar(
        backgroundColor: palette.brand,
        foregroundColor: Colors.white,
        title: Text(
          _student?.fullName ?? 'Student 360 Dossier',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          if (_student != null) ...[
            IconButton(
              tooltip: 'Print ID Card',
              onPressed: () =>
                  AdmissionPrintService.printIdCard(student: _student!),
              icon: const Icon(Icons.badge_outlined),
            ),
            IconButton(
              tooltip: 'Print Offer Letter',
              onPressed: () =>
                  AdmissionPrintService.printOfferLetter(student: _student!),
              icon: const Icon(Icons.print_outlined),
            ),
            const SizedBox(width: 8),
          ],
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: palette.accent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.person_outline, size: 18), text: 'Overview & Bio'),
            Tab(icon: Icon(Icons.family_restroom_outlined, size: 18), text: 'Parents & Contact'),
            Tab(icon: Icon(Icons.account_balance_wallet_outlined, size: 18), text: 'Fees & Dues'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    constraints: const BoxConstraints(maxWidth: 480),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_off_outlined,
                            size: 48,
                            color: AppColors.error.withValues(alpha: 0.8)),
                        const SizedBox(height: 12),
                        Text(
                          'Student Profile Unavailable',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: palette.brand),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _error,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunitoSans(
                              color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() => _loading = true);
                            _loadProfile();
                            _loadFees();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 17),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildOverviewTab(_student!),
                    _buildParentsTab(_student!),
                    _buildFeesTab(),
                  ],
                ),
    );
  }

  // ─────────────────────────── OVERVIEW TAB ───────────────────────────────────

  Widget _buildOverviewTab(Student s) {
    final palette = context.palette;
    final isActive = s.status.toUpperCase() == 'ACTIVE';

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Hero Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: palette.brand.withValues(alpha: 0.12),
              child: Text(
                s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : 'S',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: palette.brand,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  children: [
                    Text(
                      s.fullName,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: palette.brand,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isActive ? AppColors.success : AppColors.error)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s.status,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isActive ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.class_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Class: ${s.classForAdmission}',
                          style: GoogleFonts.nunitoSans(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Academic Year: ${s.academicYear}',
                          style: GoogleFonts.nunitoSans(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.badge_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Adm No: ${s.admissionNumber.isNotEmpty ? s.admissionNumber : "PROV"}',
                          style: GoogleFonts.nunitoSans(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Quick Action Buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                            color: palette.brand.withValues(alpha: 0.3)),
                      ),
                      onPressed: () =>
                          AdmissionPrintService.printIdCard(student: s),
                      icon: const Icon(Icons.badge_outlined, size: 15),
                      label: const Text('Print Student ID'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                            color: palette.brand.withValues(alpha: 0.3)),
                      ),
                      onPressed: () =>
                          AdmissionPrintService.printOfferLetter(student: s),
                      icon: const Icon(Icons.description_outlined, size: 15),
                      label: const Text('Admission Offer Letter'),
                    ),
                    if (_feeProfile != null && _feeProfile!.dueFees > 0)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FeeCollectionScreen(
                                preSelectedStudentId: widget.studentId),
                          ),
                        ).then((_) => _loadFees()),
                        icon: const Icon(Icons.payment_outlined, size: 15),
                        label: Text('Collect Fee (₹${_feeProfile!.dueFees.toInt()} due)'),
                      ),
                  ],
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 18),

        // Personal Information
        _section('Personal Information', [
          _row('Date of Birth', _fmt.format(s.dateOfBirth)),
          _row('Gender', s.gender),
          _row('Blood Group', s.bloodGroup.isNotEmpty ? s.bloodGroup : 'Not specified'),
          _row('Nationality', s.nationality),
          _row('Religion', s.religion.isNotEmpty ? s.religion : 'Not specified'),
          _row('Mother Tongue', s.motherTongue.isNotEmpty ? s.motherTongue : 'Not specified'),
          _row('Aadhar Number', s.aadharNumber.isEmpty ? '—' : s.aadharNumber),
          _row('Date of Admission', _fmt.format(s.dateOfAdmission)),
        ]),
        const SizedBox(height: 16),

        if (s.previousSchoolDetails.schoolName.isNotEmpty) ...[
          _section('Previous Schooling History', [
            _row('Previous Institution', s.previousSchoolDetails.schoolName),
            _row('Last Class Attended', s.previousSchoolDetails.lastClass),
            _row('Board / Affiliation', s.previousSchoolDetails.board),
          ]),
        ],
      ]),
    );
  }

  // ─────────────────────────── PARENTS TAB ───────────────────────────────────

  Widget _buildParentsTab(Student s) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section("Father's Details", [
            _row('Father Name', s.parentDetails.fatherName),
            _row('Occupation', s.parentDetails.fatherOccupation.isNotEmpty ? s.parentDetails.fatherOccupation : '—'),
            _row('Mobile Phone', s.parentDetails.fatherMobile.isNotEmpty ? s.parentDetails.fatherMobile : '—'),
            _row('Email Address', s.parentDetails.fatherEmail.isNotEmpty ? s.parentDetails.fatherEmail : '—'),
          ]),
          const SizedBox(height: 16),
          _section("Mother's Details", [
            _row('Mother Name', s.parentDetails.motherName),
            _row('Occupation', s.parentDetails.motherOccupation.isNotEmpty ? s.parentDetails.motherOccupation : '—'),
            _row('Mobile Phone', s.parentDetails.motherMobile.isNotEmpty ? s.parentDetails.motherMobile : '—'),
            _row('Email Address', s.parentDetails.motherEmail.isNotEmpty ? s.parentDetails.motherEmail : '—'),
          ]),
          const SizedBox(height: 16),
          _section('Contact & Residence Addresses', [
            _row('Permanent Address', s.contactDetails.permanentAddress),
            _row('Correspondence Address', s.contactDetails.correspondenceAddress.isNotEmpty ? s.contactDetails.correspondenceAddress : s.contactDetails.permanentAddress),
            _row('Primary Contact Number', s.contactDetails.primaryContactNumber),
          ]),
        ],
      ),
    );
  }

  // ─────────────────────────── FEES TAB ──────────────────────────────────────

  Widget _buildFeesTab() {
    final palette = context.palette;

    if (_feeLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_feeProfile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: palette.brand.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No fee profile found for this student',
                style: GoogleFonts.poppins(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'A fee profile is generated automatically when a student is admitted and a fee structure exists for their class.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ]),
        ),
      );
    }

    final fp = _feeProfile!;
    final feeCleared = fp.dueFees <= 0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Summary Cards
        Row(children: [
          _feeChip('Total Fees', fp.totalFees, palette.brand),
          const SizedBox(width: 10),
          _feeChip('Paid Fees', fp.paidFees, const Color(0xFF059669)),
          const SizedBox(width: 10),
          _feeChip('Pending Dues', fp.dueFees,
              feeCleared ? const Color(0xFF059669) : AppColors.error),
        ]),
        const SizedBox(height: 14),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fp.totalFees > 0 ? (fp.paidFees / fp.totalFees).clamp(0.0, 1.0) : 0.0,
            minHeight: 10,
            backgroundColor: AppColors.error.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          fp.totalFees > 0
              ? '${((fp.paidFees / fp.totalFees) * 100).toStringAsFixed(1)}% collected'
              : 'No fees assigned',
          style: GoogleFonts.nunitoSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // Collect Fee button
        if (fp.dueFees > 0)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.point_of_sale_outlined),
              label: Text('Collect Fee · ${_currency.format(fp.dueFees)} Due',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 14)),
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

        // Installments List
        Text('Fee Installments & Schedule',
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: palette.brand)),
        const SizedBox(height: 10),
        ...fp.feeInstallments.map((inst) {
          final isPaid = inst.status.toUpperCase() == 'PAID';
          return Card(
            elevation: 0.5,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                  color: isPaid
                      ? const Color(0xFF059669).withValues(alpha: 0.3)
                      : const Color(0xFFD97706).withValues(alpha: 0.4)),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Icon(
                isPaid ? Icons.check_circle_rounded : Icons.pending_actions_outlined,
                color: isPaid ? const Color(0xFF059669) : const Color(0xFFD97706),
              ),
              title: Text(inst.installmentName,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      decoration: isPaid ? TextDecoration.lineThrough : null,
                      color: isPaid ? AppColors.textSecondary : AppColors.textPrimary)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_currency.format(inst.amountDue),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isPaid ? const Color(0xFF059669) : AppColors.error)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isPaid
                              ? const Color(0xFF059669)
                              : const Color(0xFFD97706))
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(inst.status,
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isPaid
                                ? const Color(0xFF059669)
                                : const Color(0xFFD97706))),
                  ),
                ],
              ),
            ),
          );
        }),

        // Last payment info
        if (fp.lastPayment != null) ...[
          const SizedBox(height: 20),
          Text('Recent Transaction Receipt',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.brand)),
          const SizedBox(height: 10),
          Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: palette.border.withValues(alpha: 0.6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _payRow('Receipt No.', fp.lastPayment!.receiptNumber),
                _payRow('Amount Paid', _currency.format(fp.lastPayment!.amountPaid)),
                _payRow('Payment Mode', fp.lastPayment!.paymentMode),
                _payRow('Payment Date', _fmt.format(fp.lastPayment!.paymentDate)),
                if (fp.lastPayment!.discount > 0)
                  _payRow('Discount Applied', _currency.format(fp.lastPayment!.discount)),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currency.format(value),
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _payRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 140,
          child: Text(label,
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ),
      ]),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    final palette = context.palette;
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.brand)),
          ),
          Divider(height: 1, color: palette.border.withValues(alpha: 0.6)),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(label,
                style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary, fontSize: 13)),
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
