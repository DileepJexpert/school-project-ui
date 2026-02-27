import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/admission_data.dart';
import '../../../services/admission_api_service.dart';
// SchoolConstants is defined in app_constants.dart

class NewAdmissionScreen extends StatefulWidget {
  final String? studentId;
  const NewAdmissionScreen({super.key, this.studentId});

  @override
  State<NewAdmissionScreen> createState() => _NewAdmissionScreenState();
}

class _NewAdmissionScreenState extends State<NewAdmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;
  bool _loading = false;
  bool get _isEdit => widget.studentId != null;
  final _fmt = DateFormat('dd MMM yyyy');

  // Controllers
  final _nameCtrl = TextEditingController();
  final _bloodCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController(text: 'Indian');
  final _religionCtrl = TextEditingController();
  final _motherTongueCtrl = TextEditingController();
  final _aadharCtrl = TextEditingController();
  final _admNoCtrl = TextEditingController();
  final _fatherNameCtrl = TextEditingController();
  final _fatherOccCtrl = TextEditingController();
  final _fatherMobCtrl = TextEditingController();
  final _fatherEmailCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _motherOccCtrl = TextEditingController();
  final _motherMobCtrl = TextEditingController();
  final _motherEmailCtrl = TextEditingController();
  final _permAddrCtrl = TextEditingController();
  final _corrAddrCtrl = TextEditingController();
  final _primaryCtrl = TextEditingController();
  final _prevSchoolCtrl = TextEditingController();
  final _prevClassCtrl = TextEditingController();
  final _prevBoardCtrl = TextEditingController();

  DateTime? _dob;
  DateTime? _doa;
  String? _gender;
  String? _baseClass;   // e.g. "Class 5" — base class without section
  String _section = SchoolConstants.sections.first; // 'A' default
  String? _year;
  bool _sameAddr = false;

  // The value stored in DB: "Class 5 - A" or "Nursery"
  String? get _classForAdmission => _baseClass == null
      ? null
      : SchoolConstants.buildClassName(_baseClass!, _section);

  final _genders = ['Male', 'Female', 'Other'];
  final _years = ['2024-2025', '2025-2026', '2026-2027'];

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadStudent();
  }

  Future<void> _loadStudent() async {
    setState(() => _loading = true);
    try {
      final s = await AdmissionApiService.getStudentById(widget.studentId!);
      setState(() {
        _nameCtrl.text = s.fullName;
        _dob = s.dateOfBirth;
        _gender = s.gender;
        _bloodCtrl.text = s.bloodGroup;
        _nationalityCtrl.text = s.nationality;
        _religionCtrl.text = s.religion;
        _motherTongueCtrl.text = s.motherTongue;
        _aadharCtrl.text = s.aadharNumber;
        final (base, sec) = SchoolConstants.parseClassName(s.classForAdmission);
        _baseClass = base;
        _section = sec;
        _year = s.academicYear;
        _doa = s.dateOfAdmission;
        _admNoCtrl.text = s.admissionNumber;
        _fatherNameCtrl.text = s.parentDetails.fatherName;
        _fatherOccCtrl.text = s.parentDetails.fatherOccupation;
        _fatherMobCtrl.text = s.parentDetails.fatherMobile;
        _fatherEmailCtrl.text = s.parentDetails.fatherEmail;
        _motherNameCtrl.text = s.parentDetails.motherName;
        _motherOccCtrl.text = s.parentDetails.motherOccupation;
        _motherMobCtrl.text = s.parentDetails.motherMobile;
        _motherEmailCtrl.text = s.parentDetails.motherEmail;
        _permAddrCtrl.text = s.contactDetails.permanentAddress;
        _corrAddrCtrl.text = s.contactDetails.correspondenceAddress;
        _primaryCtrl.text = s.contactDetails.primaryContactNumber;
        _prevSchoolCtrl.text = s.previousSchoolDetails.schoolName;
        _prevClassCtrl.text = s.previousSchoolDetails.lastClass;
        _prevBoardCtrl.text = s.previousSchoolDetails.board;
      });
    } catch (e) {
      if (mounted) _showSnack('Failed to load student: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  Future<void> _pickDate(void Function(DateTime) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _dob == null || _gender == null || _baseClass == null || _year == null || _doa == null) {
      _showSnack('Please fill all required fields.', isError: true);
      return;
    }
    setState(() => _loading = true);
    final student = Student(
      id: widget.studentId,
      fullName: _nameCtrl.text.trim(),
      dateOfBirth: _dob!,
      gender: _gender!,
      bloodGroup: _bloodCtrl.text.trim(),
      nationality: _nationalityCtrl.text.trim(),
      religion: _religionCtrl.text.trim(),
      motherTongue: _motherTongueCtrl.text.trim(),
      aadharNumber: _aadharCtrl.text.trim(),
      classForAdmission: _classForAdmission!,
      academicYear: _year!,
      dateOfAdmission: _doa!,
      admissionNumber: _admNoCtrl.text.trim(),
      status: 'ACTIVE',
      parentDetails: ParentDetails(
        fatherName: _fatherNameCtrl.text.trim(),
        fatherOccupation: _fatherOccCtrl.text.trim(),
        fatherMobile: _fatherMobCtrl.text.trim(),
        fatherEmail: _fatherEmailCtrl.text.trim(),
        motherName: _motherNameCtrl.text.trim(),
        motherOccupation: _motherOccCtrl.text.trim(),
        motherMobile: _motherMobCtrl.text.trim(),
        motherEmail: _motherEmailCtrl.text.trim(),
      ),
      contactDetails: ContactDetails(
        permanentAddress: _permAddrCtrl.text.trim(),
        correspondenceAddress: _sameAddr ? _permAddrCtrl.text.trim() : _corrAddrCtrl.text.trim(),
        primaryContactNumber: _primaryCtrl.text.trim(),
      ),
      previousSchoolDetails: PreviousSchoolDetails(
        schoolName: _prevSchoolCtrl.text.trim(),
        lastClass: _prevClassCtrl.text.trim(),
        board: _prevBoardCtrl.text.trim(),
      ),
    );
    try {
      if (_isEdit) {
        await AdmissionApiService.updateStudent(widget.studentId!, student);
        _showSnack('Student updated successfully!');
      } else {
        await AdmissionApiService.submitAdmission(student);
        _showSnack('Admission submitted successfully!');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            borderSide: const BorderSide(color: AppColors.navy, width: 2)),
        labelStyle: GoogleFonts.nunitoSans(color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _dateRow(String label, DateTime? date, void Function(DateTime) onPicked) {
    return Row(children: [
      Expanded(
        child: Text(
          date == null ? '$label *' : '$label: ${_fmt.format(date)}',
          style: GoogleFonts.nunitoSans(
              color: date == null ? AppColors.textSecondary : AppColors.textPrimary),
        ),
      ),
      TextButton.icon(
        icon: Icon(Icons.calendar_today_outlined, color: AppColors.navy, size: 18),
        label: Text(date == null ? 'Select' : 'Change',
            style: GoogleFonts.nunitoSans(color: AppColors.navy)),
        onPressed: () => _pickDate(onPicked),
      ),
    ]);
  }

  List<Step> get _steps => [
        // Step 0 — Student Details
        Step(
          title: Text('Student Details', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
          isActive: _step >= 0,
          state: _step > 0 ? StepState.complete : StepState.indexed,
          content: Column(children: [
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: _dec('Full Name *'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _dateRow('Date of Birth', _dob, (d) => _dob = d),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: _dec('Gender *'),
              value: _gender,
              items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setState(() => _gender = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _bloodCtrl, decoration: _dec('Blood Group')),
            const SizedBox(height: 12),
            TextFormField(controller: _nationalityCtrl, decoration: _dec('Nationality')),
            const SizedBox(height: 12),
            TextFormField(controller: _religionCtrl, decoration: _dec('Religion')),
            const SizedBox(height: 12),
            TextFormField(controller: _motherTongueCtrl, decoration: _dec('Mother Tongue')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aadharCtrl,
              decoration: _dec('Aadhar Number'),
              keyboardType: TextInputType.number,
            ),
          ]),
        ),
        // Step 1 — Admission Details
        Step(
          title: Text('Admission Details', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
          isActive: _step >= 1,
          state: _step > 1 ? StepState.complete : StepState.indexed,
          content: Column(children: [
            const SizedBox(height: 8),
            // Class + Section row
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  decoration: _dec('Class *'),
                  value: _baseClass,
                  items: SchoolConstants.baseClasses
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _baseClass = v;
                    // Reset to 'A' when switching to pre-primary (no section)
                    if (SchoolConstants.noSectionClasses.contains(v)) {
                      _section = SchoolConstants.sections.first;
                    }
                  }),
                  validator: (v) => v == null ? 'Required' : null,
                ),
              ),
              if (_baseClass != null &&
                  !SchoolConstants.noSectionClasses.contains(_baseClass)) ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    decoration: _dec('Section *'),
                    value: _section,
                    items: SchoolConstants.sections
                        .map((s) => DropdownMenuItem(value: s, child: Text('Section $s')))
                        .toList(),
                    onChanged: (v) => setState(() => _section = v!),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: _dec('Academic Year *'),
              value: _year,
              items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
              onChanged: (v) => setState(() => _year = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _dateRow('Date of Admission', _doa, (d) => _doa = d),
            const SizedBox(height: 12),
            TextFormField(
              controller: _admNoCtrl,
              decoration: _dec('Admission Number', hint: 'Auto-generated if empty'),
            ),
          ]),
        ),
        // Step 2 — Parent/Guardian
        Step(
          title: Text('Parent / Guardian', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
          isActive: _step >= 2,
          state: _step > 2 ? StepState.complete : StepState.indexed,
          content: Column(children: [
            const SizedBox(height: 8),
            Text('Father\'s Details', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, color: AppColors.navy)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _fatherNameCtrl,
              decoration: _dec('Father\'s Name *'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _fatherOccCtrl, decoration: _dec('Father\'s Occupation')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fatherMobCtrl,
              decoration: _dec('Father\'s Mobile *', hint: '+91 XXXXXXXXXX'),
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fatherEmailCtrl,
              decoration: _dec('Father\'s Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            Text('Mother\'s Details', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, color: AppColors.navy)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _motherNameCtrl,
              decoration: _dec('Mother\'s Name *'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _motherOccCtrl, decoration: _dec('Mother\'s Occupation')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _motherMobCtrl,
              decoration: _dec('Mother\'s Mobile'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _motherEmailCtrl,
              decoration: _dec('Mother\'s Email'),
              keyboardType: TextInputType.emailAddress,
            ),
          ]),
        ),
        // Step 3 — Contact
        Step(
          title: Text('Contact Information', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
          isActive: _step >= 3,
          state: _step > 3 ? StepState.complete : StepState.indexed,
          content: Column(children: [
            const SizedBox(height: 8),
            TextFormField(
              controller: _permAddrCtrl,
              decoration: _dec('Permanent Address *'),
              maxLines: 3,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _sameAddr,
              title: Text('Correspondence address same as permanent',
                  style: GoogleFonts.nunitoSans(fontSize: 14)),
              onChanged: (v) {
                setState(() {
                  _sameAddr = v ?? false;
                  if (_sameAddr) _corrAddrCtrl.text = _permAddrCtrl.text;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (!_sameAddr) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _corrAddrCtrl,
                decoration: _dec('Correspondence Address *'),
                maxLines: 3,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _primaryCtrl,
              decoration: _dec('Primary Contact *', hint: '+91 XXXXXXXXXX'),
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'Required' : (v.length < 10 ? 'Invalid' : null),
            ),
          ]),
        ),
        // Step 4 — Previous School
        Step(
          title: Text('Previous School', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
          isActive: _step >= 4,
          state: _step > 4 ? StepState.complete : StepState.indexed,
          content: Column(children: [
            const SizedBox(height: 8),
            TextFormField(controller: _prevSchoolCtrl, decoration: _dec('Previous School Name')),
            const SizedBox(height: 12),
            TextFormField(controller: _prevClassCtrl, decoration: _dec('Last Class Attended')),
            const SizedBox(height: 12),
            TextFormField(controller: _prevBoardCtrl, decoration: _dec('Board (e.g., CBSE, ICSE)')),
            const SizedBox(height: 24),
            Text(
              'Note: Document uploads (TC, Report Card) can be added after the student profile is created.',
              style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12),
            ),
          ]),
        ),
      ];

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _bloodCtrl, _nationalityCtrl, _religionCtrl, _motherTongueCtrl,
      _aadharCtrl, _admNoCtrl, _fatherNameCtrl, _fatherOccCtrl, _fatherMobCtrl,
      _fatherEmailCtrl, _motherNameCtrl, _motherOccCtrl, _motherMobCtrl,
      _motherEmailCtrl, _permAddrCtrl, _corrAddrCtrl, _primaryCtrl,
      _prevSchoolCtrl, _prevClassCtrl, _prevBoardCtrl,
    ]) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(
          _isEdit ? 'Edit Student Profile' : 'New Student Admission',
          style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: _loading && _isEdit
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Stepper(
                currentStep: _step,
                onStepTapped: (s) => setState(() => _step = s),
                onStepContinue: () {
                  if (_step < _steps.length - 1) {
                    setState(() => _step++);
                  } else {
                    _submit();
                  }
                },
                onStepCancel: () {
                  if (_step > 0) setState(() => _step--);
                },
                steps: _steps,
                controlsBuilder: (context, details) => Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(children: [
                    if (_step < _steps.length - 1)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy, foregroundColor: Colors.white),
                        onPressed: details.onStepContinue,
                        child: const Text('Next'),
                      )
                    else
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy, foregroundColor: Colors.white),
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(_isEdit ? Icons.save : Icons.person_add_alt_1),
                        label: Text(_loading ? 'Saving…' : (_isEdit ? 'Update' : 'Submit Admission')),
                        onPressed: _loading ? null : _submit,
                      ),
                    const SizedBox(width: 12),
                    if (_step > 0)
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Back'),
                      ),
                  ]),
                ),
              ),
            ),
    );
  }
}
