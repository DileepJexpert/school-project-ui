import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/public_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/responsive.dart';
import '../../models/school_data.dart';

import '../../core/constants/academic_year.dart';
import '../../models/admission_data.dart';
import '../../services/admission_api_service.dart';
import '../../core/widgets/searchable_dropdown.dart';

class AdmissionsPage extends StatelessWidget {
  const AdmissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: AppRouter.admissions,
      child: Column(
        children: [
          PageHeader(
              title: 'Admissions',
              subtitle: 'Admissions at ${AppStrings.schoolName}'),
          _ProcessSection(),
          _OnlineApplicationSection(),
          _DatesAndFormsSection(),
          _FeeSection(),
        ],
      ),
    );
  }
}

class _ProcessSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      backgroundColor: PublicColors.white,
      child: Column(
        children: [
          const SectionTitle(title: 'Admission Process', centered: true),
          const SizedBox(height: 36),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = Responsive.gridColumns(context);
              return Wrap(
                spacing: 16,
                runSpacing: 24,
                children: SchoolData.admissionSteps
                    .map((s) => SizedBox(
                          width: (constraints.maxWidth - (columns - 1) * 16) /
                              columns,
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: PublicColors.navy),
                                alignment: Alignment.center,
                                child: Text('${s.step}',
                                    style: GoogleFonts.cormorantGaramond(
                                      color: PublicColors.gold,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    )),
                              ),
                              const SizedBox(height: 14),
                              Text(s.title,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.nunitoSans(
                                      color: PublicColors.navy,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              const SizedBox(height: 8),
                              Text(s.description,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.nunitoSans(
                                      color: PublicColors.textSecondary,
                                      fontSize: 13,
                                      height: 1.5)),
                            ],
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                PrimaryScrollController.maybeOf(context)?.animateTo(
                  450,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
              icon: const Icon(Icons.arrow_downward_rounded, size: 18),
              label: const Text('Fill Application Form Below'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PublicColors.navy,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DatesAndFormsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return SectionWrapper(
      backgroundColor: PublicColors.creamDark,
      child: isMobile
          ? Column(children: [
              _dates(context),
              const SizedBox(height: 32),
              _forms(context)
            ])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _dates(context)),
                const SizedBox(width: 36),
                Expanded(child: _forms(context)),
              ],
            ),
    );
  }

  Widget _dates(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Important Dates'),
        const SizedBox(height: 20),
        ...SchoolData.importantDates.map((d) => Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: PublicColors.border))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Text(d.event,
                          style: GoogleFonts.nunitoSans(
                              color: PublicColors.navy,
                              fontWeight: FontWeight.w600,
                              fontSize: 14))),
                  Text(d.date,
                      style: GoogleFonts.nunitoSans(
                          color: PublicColors.gold,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            )),
      ],
    );
  }

  Widget _forms(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Downloadable Forms'),
        const SizedBox(height: 20),
        ...SchoolData.forms.map((f) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: PublicColors.white,
                border: Border.all(color: PublicColors.border),
              ),
              child: ListTile(
                leading: const Icon(Icons.description_outlined,
                    color: PublicColors.gold),
                title: Text(f.name,
                    style: GoogleFonts.nunitoSans(
                        color: PublicColors.navy,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                subtitle: Text('${f.type} • ${f.size}',
                    style: GoogleFonts.nunitoSans(
                        color: PublicColors.textSecondary, fontSize: 12)),
                trailing: f.url.isEmpty
                    ? null
                    : const Icon(Icons.download_outlined,
                        color: PublicColors.textSecondary),
                onTap: f.url.isEmpty
                    ? null
                    : () async {
                        final url = Uri.tryParse(f.url);
                        if (url == null ||
                            (url.scheme != 'https' && url.scheme != 'http') ||
                            !await launchUrl(url,
                                mode: LaunchMode.externalApplication)) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Could not open ${f.name}')),
                            );
                          }
                        }
                      },
              ),
            )),
      ],
    );
  }
}

class _FeeSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (SchoolData.feeStructure.isEmpty) return const SizedBox.shrink();
    return SectionWrapper(
      backgroundColor: PublicColors.white,
      child: Column(
        children: [
          SectionTitle(
              title: SchoolData.feeStructureTitle.isEmpty
                  ? 'Fee Structure'
                  : SchoolData.feeStructureTitle,
              centered: true),
          const SizedBox(height: 8),
          Text(
            'All amounts in INR (₹).',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
                color: PublicColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 28),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(PublicColors.navy),
              headingTextStyle: GoogleFonts.nunitoSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              dataTextStyle: GoogleFonts.nunitoSans(
                  fontSize: 13, color: PublicColors.textPrimary),
              columnSpacing: 32,
              border: TableBorder.all(color: PublicColors.border, width: 0.5),
              columns: const [
                DataColumn(label: Text('Grade Level')),
                DataColumn(label: Text('Admission Fee')),
                DataColumn(label: Text('Monthly Tuition')),
                DataColumn(label: Text('Annual Total')),
              ],
              rows: SchoolData.feeStructure
                  .map((f) => DataRow(cells: [
                        DataCell(Text(f.grade,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: PublicColors.navy))),
                        DataCell(Text('₹ ${f.admission}')),
                        DataCell(Text('₹ ${f.tuition}')),
                        DataCell(Text('₹ ${f.annual}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: PublicColors.gold))),
                      ]))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (SchoolData.feeStructureNote.isNotEmpty)
            Text(
              SchoolData.feeStructureNote,
              style: GoogleFonts.nunitoSans(
                  color: PublicColors.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
}

class _OnlineApplicationSection extends StatefulWidget {
  @override
  State<_OnlineApplicationSection> createState() =>
      _OnlineApplicationSectionState();
}

class _OnlineApplicationSectionState extends State<_OnlineApplicationSection> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _parentCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _selectedClass;
  String _selectedYear = AcademicYear.currentLong();
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _parentCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final student = Student(
        fullName: _nameCtrl.text.trim(),
        dateOfBirth: DateTime(2015, 1, 1),
        gender: '',
        bloodGroup: '',
        nationality: 'Indian',
        religion: '',
        motherTongue: '',
        aadharNumber: '',
        classForAdmission: _selectedClass!,
        academicYear: _selectedYear,
        dateOfAdmission: DateTime.now(),
        admissionNumber: '',
        status: 'ENQUIRY',
        parentDetails: ParentDetails(
          fatherName: _parentCtrl.text.trim(),
          fatherOccupation: '',
          fatherMobile: _phoneCtrl.text.trim(),
          fatherEmail: _emailCtrl.text.trim(),
          motherName: '',
          motherOccupation: '',
          motherMobile: '',
          motherEmail: '',
        ),
        contactDetails: ContactDetails(
          permanentAddress: '',
          correspondenceAddress: _notesCtrl.text.trim(),
          primaryContactNumber: _phoneCtrl.text.trim(),
        ),
        previousSchoolDetails: PreviousSchoolDetails(
          schoolName: '',
          lastClass: '',
          board: '',
        ),
      );

      await AdmissionApiService.submitEnquiry(student);
      setState(() => _submitted = true);
    } catch (e) {
      setState(() => _error = 'Failed to submit enquiry: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _reset() {
    _formKey.currentState?.reset();
    _nameCtrl.clear();
    _parentCtrl.clear();
    _phoneCtrl.clear();
    _emailCtrl.clear();
    _notesCtrl.clear();
    setState(() {
      _selectedClass = null;
      _submitted = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return SectionWrapper(
      backgroundColor: PublicColors.white,
      child: Column(
        children: [
          const SectionTitle(
            title: 'Online Application & Enquiry',
            centered: true,
          ),
          const SizedBox(height: 12),
          Text(
            'Begin your child\'s admission process online. Fill the form below and our admissions team will get in touch.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              color: PublicColors.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 760),
              padding: EdgeInsets.all(isMobile ? 24 : 36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A101828),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: _submitted
                  ? _buildSuccessCard()
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: PublicColors.error.withValues(alpha: 0.08),
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radiusMD),
                                border: Border.all(
                                    color: PublicColors.error.withValues(alpha: 0.3)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.error_outline,
                                    color: PublicColors.error, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(_error!,
                                        style: const TextStyle(
                                            color: PublicColors.error,
                                            fontSize: 13))),
                              ]),
                            ),
                          ],
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: _dec('Student Full Name *',
                                'e.g. Aarav Sharma', Icons.person_outline),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Student name is required'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          if (isMobile) ...[
                            SearchableDropdownFormField<String>(
                              labelText: 'Grade / Class Applying For *',
                              hintText: 'Select or type class...',
                              initialValue: _selectedClass,
                              items: SchoolConstants.allClasses,
                              onChanged: (v) =>
                                  setState(() => _selectedClass = v),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Please select a class'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            SearchableDropdownFormField<String>(
                              labelText: 'Academic Year *',
                              initialValue: _selectedYear,
                              items: AcademicYear.choices(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedYear = v);
                                }
                              },
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: SearchableDropdownFormField<String>(
                                    labelText: 'Grade / Class Applying For *',
                                    hintText: 'Select or type class...',
                                    initialValue: _selectedClass,
                                    items: SchoolConstants.allClasses,
                                    onChanged: (v) =>
                                        setState(() => _selectedClass = v),
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'Please select a class'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: SearchableDropdownFormField<String>(
                                    labelText: 'Academic Year *',
                                    initialValue: _selectedYear,
                                    items: AcademicYear.choices(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _selectedYear = v);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _parentCtrl,
                            decoration: _dec(
                                'Parent / Guardian Name *',
                                'e.g. Vikram Sharma',
                                Icons.family_restroom_outlined),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Parent name is required'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: _dec('Contact Number *',
                                      '+91 98765 43210', Icons.phone_outlined),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty)
                                      return 'Phone number is required';
                                    if (v.trim().length < 10)
                                      return 'Enter a valid 10-digit phone number';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _dec(
                                      'Email Address',
                                      'parent@example.com',
                                      Icons.email_outlined),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _notesCtrl,
                            maxLines: 2,
                            decoration: _dec(
                                'Additional Notes / Questions (Optional)',
                                'Any specific queries or details...',
                                Icons.edit_note_outlined),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _submitting ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PublicColors.navy,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppSizes.radiusMD)),
                              ),
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.send_rounded, size: 18),
                              label: Text(
                                _submitting
                                    ? 'Submitting Application…'
                                    : 'Submit Admission Enquiry',
                                style: GoogleFonts.nunitoSans(
                                    fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Column(
      children: [
        const Icon(Icons.check_circle_rounded,
            color: PublicColors.success, size: 56),
        const SizedBox(height: 16),
        Text('Application Enquiry Received!',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: PublicColors.navy)),
        const SizedBox(height: 8),
        Text(
          'Thank you for your interest in ${AppStrings.schoolName}. '
          'Our admissions office has received your enquiry for ${_nameCtrl.text.trim()} '
          'and will reach out via phone (${_phoneCtrl.text.trim()}) within 24–48 hours.',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunitoSans(
              color: PublicColors.textSecondary, fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Submit Another Enquiry'),
        ),
      ],
    );
  }

  InputDecoration _dec(String label, String hint, IconData icon) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: PublicColors.navyLight),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          borderSide: const BorderSide(color: PublicColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          borderSide: const BorderSide(color: PublicColors.navy, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}
