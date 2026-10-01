import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/academic_year.dart';
import '../../../models/admission_data.dart';
import '../../../services/admission_api_service.dart';
import '../../../core/widgets/searchable_dropdown.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/fee_api_service.dart';

class NewAdmissionScreen extends StatefulWidget {
  final String? studentId;
  /// When true: editing an ENQUIRY record and converting it to a full admission.
  /// Status will be set to ACTIVE on save.
  final bool admitMode;
  const NewAdmissionScreen({super.key, this.studentId, this.admitMode = false});

  @override
  State<NewAdmissionScreen> createState() => _NewAdmissionScreenState();
}

class _NewAdmissionScreenState extends State<NewAdmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;
  bool _loading = false;
  bool get _isEdit => widget.studentId != null;
  bool get _isAdmitMode => widget.admitMode;
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
  String? _baseClass;
  String _section = SchoolConstants.sections.first;
  String? _year;
  bool _sameAddr = false;
  String? _rollNumber;
  String? _loadedClass;
  String? _loadedYear;
  String _existingStatus = 'ACTIVE';

  String? get _classForAdmission => _baseClass == null
      ? null
      : SchoolConstants.buildClassName(_baseClass!, _section);

  final _genders = ['Male', 'Female', 'Other'];
  List<String> get _years => AcademicYear.choices(include: _year);

  static const _stepTitles = [
    'Student Details',
    'Admission Details',
    'Parent / Guardian',
    'Contact Information',
    'Previous School',
  ];

  static const _stepIcons = [
    Icons.person_outline_rounded,
    Icons.school_outlined,
    Icons.family_restroom_outlined,
    Icons.location_on_outlined,
    Icons.history_edu_outlined,
  ];

  @override
  void initState() {
    super.initState();
    if (!_isEdit) {
      _year = AcademicYear.currentLong();
      _doa = DateTime.now();
    }
    if (_isEdit) _loadStudent();
  }

  Future<void> _loadStudent() async {
    setState(() => _loading = true);
    try {
      final s = await AdmissionApiService.getStudentById(widget.studentId!);
      setState(() {
        _nameCtrl.text = s.fullName;
        _dob = s.dateOfBirth.year == 2000 && s.dateOfBirth.month == 1 && s.dateOfBirth.day == 1
            ? null
            : s.dateOfBirth;
        _gender = _genders.contains(s.gender) ? s.gender : null;
        _bloodCtrl.text = s.bloodGroup;
        _nationalityCtrl.text = s.nationality;
        _religionCtrl.text = s.religion;
        _motherTongueCtrl.text = s.motherTongue;
        _aadharCtrl.text = s.aadharNumber;
        final (base, sec) = SchoolConstants.parseClassName(s.classForAdmission);
        _baseClass = base;
        _section = sec;
        _year = s.academicYear;
        _loadedClass = s.classForAdmission;
        _loadedYear = s.academicYear;
        _doa = s.dateOfAdmission;
        _admNoCtrl.text = s.admissionNumber;
        _rollNumber = s.rollNumber;
        _existingStatus = s.status;
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

  Future<void> _pickDate(DateTime? current, void Function(DateTime) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  bool _validateCurrentStep() {
    if (_step == 0) {
      if (_nameCtrl.text.trim().isEmpty) {
        _showSnack('Please enter student\'s full name.', isError: true);
        return false;
      }
      if (_dob == null) {
        _showSnack('Please select date of birth.', isError: true);
        return false;
      }
      if (_gender == null) {
        _showSnack('Please select gender.', isError: true);
        return false;
      }
    } else if (_step == 1) {
      if (_baseClass == null) {
        _showSnack('Please select class for admission.', isError: true);
        return false;
      }
      if (_year == null) {
        _showSnack('Please select academic year.', isError: true);
        return false;
      }
      if (_doa == null) {
        _showSnack('Please select admission date.', isError: true);
        return false;
      }
    } else if (_step == 2) {
      if (_fatherNameCtrl.text.trim().isEmpty) {
        _showSnack('Please enter father\'s name.', isError: true);
        return false;
      }
      if (_fatherMobCtrl.text.trim().isEmpty) {
        _showSnack('Please enter father\'s mobile number.', isError: true);
        return false;
      }
    } else if (_step == 3) {
      if (_permAddrCtrl.text.trim().isEmpty) {
        _showSnack('Please enter permanent address.', isError: true);
        return false;
      }
      final corr = _sameAddr ? _permAddrCtrl.text.trim() : _corrAddrCtrl.text.trim();
      if (corr.isEmpty) {
        _showSnack('Please enter correspondence address.', isError: true);
        return false;
      }
      if (_primaryCtrl.text.trim().isEmpty) {
        _showSnack('Please enter primary contact number.', isError: true);
        return false;
      }
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validateCurrentStep()) return;
    if (!_formKey.currentState!.validate() || _dob == null || _gender == null || _baseClass == null || _year == null || _doa == null) {
      _showSnack('Please fill all required fields.', isError: true);
      return;
    }
    if (_isEdit && !_isAdmitMode &&
        (_classForAdmission != _loadedClass || _year != _loadedYear)) {
      _showSnack('Use class promotion to change class or academic year; '
          'a normal edit cannot update the fee profile safely.', isError: true);
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
      rollNumber: _rollNumber,
      status: _isAdmitMode ? 'ACTIVE' : (_isEdit ? _existingStatus : 'ACTIVE'),
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
      if (!_isEdit || _isAdmitMode) {
        final structures = await FeeApiService.getFeeStructures(year: _year!);
        if (!structures.any((s) =>
            s.className == _classForAdmission &&
            s.academicYear == _year &&
            s.components.isNotEmpty)) {
          throw StateError('Set up fees for $_classForAdmission ($_year) before admitting this student.');
        }
      }
      if (_isEdit) {
        await AdmissionApiService.updateStudent(widget.studentId!, student);
        _showSnack(_isAdmitMode
            ? 'Enquiry converted to admission successfully!'
            : 'Student updated successfully!');
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

  InputDecoration _dec(String label, {String? hint, IconData? prefixIcon}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 19, color: AppColors.textSecondary) : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.navy, width: 2)),
        labelStyle: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 13.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _datePickerTile({
    required String label,
    required DateTime? date,
    required IconData icon,
    required void Function(DateTime) onPicked,
  }) {
    return InkWell(
      onTap: () => _pickDate(date, onPicked),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    date == null ? 'Select date' : _fmt.format(date),
                    style: GoogleFonts.nunitoSans(
                      color: date == null ? const Color(0xFF9CA3AF) : AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: date == null ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _bloodCtrl, _nationalityCtrl, _religionCtrl, _motherTongueCtrl,
      _aadharCtrl, _admNoCtrl, _fatherNameCtrl, _fatherOccCtrl, _fatherMobCtrl,
      _fatherEmailCtrl, _motherNameCtrl, _motherOccCtrl, _motherMobCtrl,
      _motherEmailCtrl, _permAddrCtrl, _corrAddrCtrl, _primaryCtrl,
      _prevSchoolCtrl, _prevClassCtrl, _prevBoardCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isAdmitMode
                  ? 'Admit Student'
                  : (_isEdit ? 'Edit Student Profile' : 'New Student Admission'),
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
            ),
            if (_nameCtrl.text.isNotEmpty)
              Text(
                'Candidate: ${_nameCtrl.text.trim()}',
                style: GoogleFonts.nunitoSans(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
              ),
          ],
        ),
      ),
      body: _loading && _isEdit
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    children: [
                      // Top Progress Stepper
                      _buildStepperHeader(isMobile),
                      const SizedBox(height: 20),
                      // Form Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A101828),
                              blurRadius: 20,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Step Header
                              _buildStepTitleBanner(),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              // Step Content
                              Padding(
                                padding: EdgeInsets.all(isMobile ? 20 : 32),
                                child: _buildCurrentStepContent(isMobile),
                              ),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              // Action Buttons
                              _buildBottomActions(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ==========================================
  // TOP STEPPER HEADER
  // ==========================================
  Widget _buildStepperHeader(bool isMobile) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.navy,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${_step + 1}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step ${_step + 1} of 5',
                    style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  Text(
                    _stepTitles[_step],
                    style: GoogleFonts.poppins(color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: List.generate(_stepTitles.length, (i) {
          final isCompleted = _step > i;
          final isActive = _step == i;
          final title = _stepTitles[i];

          return Expanded(
            child: InkWell(
              onTap: () {
                if (i <= _step || _validateCurrentStep()) {
                  setState(() => _step = i);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.success
                            : (isActive ? AppColors.navy : const Color(0xFFF1F5F9)),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive ? AppColors.navy : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isCompleted
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: isActive ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunitoSans(
                          color: isActive
                              ? AppColors.navy
                              : (isCompleted ? AppColors.textPrimary : AppColors.textSecondary),
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==========================================
  // STEP TITLE BANNER
  // ==========================================
  Widget _buildStepTitleBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_stepIcons[_step], color: AppColors.navy, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${_step + 1} of 5: ${_stepTitles[_step]}',
                  style: GoogleFonts.poppins(color: AppColors.navy, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  _getStepSubtitle(_step),
                  style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStepSubtitle(int step) {
    switch (step) {
      case 0:
        return 'Personal information, demographic details, and identification.';
      case 1:
        return 'Class assignment, academic session, and admission date.';
      case 2:
        return 'Father and mother contact details and occupational information.';
      case 3:
        return 'Residential addresses and primary emergency contact numbers.';
      case 4:
        return 'Prior academic history and document upload guidelines.';
      default:
        return '';
    }
  }

  // ==========================================
  // STEP CONTENT BUILDER
  // ==========================================
  Widget _buildCurrentStepContent(bool isMobile) {
    switch (_step) {
      case 0:
        return _buildStep0Student(isMobile);
      case 1:
        return _buildStep1Admission(isMobile);
      case 2:
        return _buildStep2Parent(isMobile);
      case 3:
        return _buildStep3Contact(isMobile);
      case 4:
        return _buildStep4PreviousSchool(isMobile);
      default:
        return const SizedBox.shrink();
    }
  }

  // Step 0: Student Details
  Widget _buildStep0Student(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile) ...[
          TextFormField(
            controller: _nameCtrl,
            decoration: _dec('Student Full Name *', prefixIcon: Icons.badge_outlined),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required' : null,
          ),
          const SizedBox(height: 16),
          SearchableDropdownFormField<String>(
            labelText: 'Gender *',
            hintText: 'Select gender...',
            initialValue: _gender,
            items: _genders,
            onChanged: (v) => setState(() => _gender = v),
            validator: (v) => v == null ? 'Gender is required' : null,
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _nameCtrl,
                  decoration: _dec('Student Full Name *', prefixIcon: Icons.badge_outlined),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: SearchableDropdownFormField<String>(
                  labelText: 'Gender *',
                  hintText: 'Select gender...',
                  initialValue: _gender,
                  items: _genders,
                  onChanged: (v) => setState(() => _gender = v),
                  validator: (v) => v == null ? 'Gender is required' : null,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (isMobile) ...[
          _datePickerTile(
            label: 'Date of Birth *',
            date: _dob,
            icon: Icons.cake_outlined,
            onPicked: (d) => _dob = d,
          ),
          const SizedBox(height: 16),
          TextFormField(controller: _bloodCtrl, decoration: _dec('Blood Group', hint: 'e.g. O+, B+, A+')),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _datePickerTile(
                  label: 'Date of Birth *',
                  date: _dob,
                  icon: Icons.cake_outlined,
                  onPicked: (d) => _dob = d,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(controller: _bloodCtrl, decoration: _dec('Blood Group', hint: 'e.g. O+, B+, A+')),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (isMobile) ...[
          TextFormField(controller: _nationalityCtrl, decoration: _dec('Nationality')),
          const SizedBox(height: 16),
          TextFormField(controller: _religionCtrl, decoration: _dec('Religion', hint: 'e.g. Hindu, Muslim, Christian')),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(controller: _nationalityCtrl, decoration: _dec('Nationality')),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(controller: _religionCtrl, decoration: _dec('Religion', hint: 'e.g. Hindu, Muslim, Christian')),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (isMobile) ...[
          TextFormField(controller: _motherTongueCtrl, decoration: _dec('Mother Tongue', hint: 'e.g. Hindi, English')),
          const SizedBox(height: 16),
          TextFormField(
            controller: _aadharCtrl,
            decoration: _dec('Aadhar Number', hint: '12-digit UIDAI number'),
            keyboardType: TextInputType.number,
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(controller: _motherTongueCtrl, decoration: _dec('Mother Tongue', hint: 'e.g. Hindi, English')),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _aadharCtrl,
                  decoration: _dec('Aadhar Number', hint: '12-digit UIDAI number'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // Step 1: Admission Details
  Widget _buildStep1Admission(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile) ...[
          SearchableDropdownFormField<String>(
            labelText: 'Class for Admission *',
            hintText: 'Select or type class...',
            initialValue: _baseClass,
            items: SchoolConstants.baseClasses,
            onChanged: (v) => setState(() {
              _baseClass = v;
              if (SchoolConstants.noSectionClasses.contains(v)) {
                _section = SchoolConstants.sections.first;
              }
            }),
            validator: (v) => v == null ? 'Required' : null,
          ),
          if (_baseClass != null && !SchoolConstants.noSectionClasses.contains(_baseClass)) ...[
            const SizedBox(height: 16),
            SearchableDropdownFormField<String>(
              labelText: 'Section *',
              initialValue: _section,
              items: SchoolConstants.sections,
              itemLabel: (s) => 'Section $s',
              onChanged: (v) => setState(() => _section = v!),
            ),
          ],
        ] else ...[
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SearchableDropdownFormField<String>(
                  labelText: 'Class for Admission *',
                  hintText: 'Select or type class...',
                  initialValue: _baseClass,
                  items: SchoolConstants.baseClasses,
                  onChanged: (v) => setState(() {
                    _baseClass = v;
                    if (SchoolConstants.noSectionClasses.contains(v)) {
                      _section = SchoolConstants.sections.first;
                    }
                  }),
                  validator: (v) => v == null ? 'Required' : null,
                ),
              ),
              if (_baseClass != null && !SchoolConstants.noSectionClasses.contains(_baseClass)) ...[
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: SearchableDropdownFormField<String>(
                    labelText: 'Section *',
                    initialValue: _section,
                    items: SchoolConstants.sections,
                    itemLabel: (s) => 'Section $s',
                    onChanged: (v) => setState(() => _section = v!),
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (isMobile) ...[
          SearchableDropdownFormField<String>(
            labelText: 'Academic Year *',
            initialValue: _year,
            items: _years,
            onChanged: (v) => setState(() => _year = v),
            validator: (v) => v == null ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          _datePickerTile(
            label: 'Date of Admission *',
            date: _doa,
            icon: Icons.event_available_outlined,
            onPicked: (d) => _doa = d,
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: SearchableDropdownFormField<String>(
                  labelText: 'Academic Year *',
                  initialValue: _year,
                  items: _years,
                  onChanged: (v) => setState(() => _year = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _datePickerTile(
                  label: 'Date of Admission *',
                  date: _doa,
                  icon: Icons.event_available_outlined,
                  onPicked: (d) => _doa = d,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        TextFormField(
          controller: _admNoCtrl,
          decoration: _dec('Admission Number', hint: 'Auto-generated systematically if left blank'),
        ),
      ],
    );
  }

  // Step 2: Parent / Guardian
  Widget _buildStep2Parent(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Father Box
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, color: AppColors.navy, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Father\'s Information',
                    style: GoogleFonts.poppins(color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isMobile) ...[
                TextFormField(
                  controller: _fatherNameCtrl,
                  decoration: _dec('Father\'s Name *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Father\'s Name is required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _fatherOccCtrl,
                  decoration: _dec('Father\'s Occupation', hint: 'e.g. Business, Engineer, Doctor'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _fatherMobCtrl,
                  decoration: _dec('Father\'s Mobile Number *', hint: '+91 98765 43210'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Mobile number is required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _fatherEmailCtrl,
                  decoration: _dec('Father\'s Email Address', hint: 'father@example.com'),
                  keyboardType: TextInputType.emailAddress,
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fatherNameCtrl,
                        decoration: _dec('Father\'s Name *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Father\'s Name is required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _fatherOccCtrl,
                        decoration: _dec('Father\'s Occupation', hint: 'e.g. Business, Engineer, Doctor'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fatherMobCtrl,
                        decoration: _dec('Father\'s Mobile Number *', hint: '+91 98765 43210'),
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Mobile number is required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _fatherEmailCtrl,
                        decoration: _dec('Father\'s Email Address', hint: 'father@example.com'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Mother Box
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.face_3_outlined, color: AppColors.navy, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Mother\'s Information',
                    style: GoogleFonts.poppins(color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isMobile) ...[
                TextFormField(
                  controller: _motherNameCtrl,
                  decoration: _dec('Mother\'s Name *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Mother\'s Name is required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _motherOccCtrl,
                  decoration: _dec('Mother\'s Occupation', hint: 'e.g. Homemaker, Teacher, IT'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _motherMobCtrl,
                  decoration: _dec('Mother\'s Mobile Number', hint: '+91 98765 43210'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _motherEmailCtrl,
                  decoration: _dec('Mother\'s Email Address', hint: 'mother@example.com'),
                  keyboardType: TextInputType.emailAddress,
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _motherNameCtrl,
                        decoration: _dec('Mother\'s Name *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Mother\'s Name is required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _motherOccCtrl,
                        decoration: _dec('Mother\'s Occupation', hint: 'e.g. Homemaker, Teacher, IT'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _motherMobCtrl,
                        decoration: _dec('Mother\'s Mobile Number', hint: '+91 98765 43210'),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _motherEmailCtrl,
                        decoration: _dec('Mother\'s Email Address', hint: 'mother@example.com'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Step 3: Contact Information
  Widget _buildStep3Contact(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _permAddrCtrl,
          decoration: _dec('Permanent Address *', hint: 'House/Street, Locality, City, State, PIN Code'),
          maxLines: 2,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Permanent Address is required' : null,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: CheckboxListTile(
            value: _sameAddr,
            title: Text(
              'Correspondence address is the same as permanent address',
              style: GoogleFonts.nunitoSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.navy),
            ),
            onChanged: (v) {
              setState(() {
                _sameAddr = v ?? false;
                if (_sameAddr) _corrAddrCtrl.text = _permAddrCtrl.text;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (!_sameAddr) ...[
          const SizedBox(height: 14),
          TextFormField(
            controller: _corrAddrCtrl,
            decoration: _dec('Correspondence Address *', hint: 'Local address if different from permanent'),
            maxLines: 2,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Correspondence Address is required' : null,
          ),
        ],
        const SizedBox(height: 16),
        TextFormField(
          controller: _primaryCtrl,
          decoration: _dec('Primary Contact Number *', hint: '+91 98765 43210 (SMS / WhatsApp Alerts)'),
          keyboardType: TextInputType.phone,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Primary Contact Number is required';
            if (v.trim().length < 10) return 'Enter a valid 10-digit phone number';
            return null;
          },
        ),
      ],
    );
  }

  // Step 4: Previous School
  Widget _buildStep4PreviousSchool(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile) ...[
          TextFormField(controller: _prevSchoolCtrl, decoration: _dec('Previous School Name')),
          const SizedBox(height: 16),
          TextFormField(controller: _prevClassCtrl, decoration: _dec('Last Class / Grade Attended')),
        ] else ...[
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(controller: _prevSchoolCtrl, decoration: _dec('Previous School Name')),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextFormField(controller: _prevClassCtrl, decoration: _dec('Last Class / Grade Attended')),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        TextFormField(controller: _prevBoardCtrl, decoration: _dec('Affiliated Board', hint: 'e.g. CBSE, ICSE, State Board')),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.navy.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.navy.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: AppColors.navy, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Document Verification Note',
                      style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Original Transfer Certificate (TC), previous report cards, birth certificate, and student passport photos can be uploaded and verified directly under the student profile after admission confirmation.',
                      style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12.5, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // BOTTOM ACTIONS
  // ==========================================
  Widget _buildBottomActions() {
    final isLastStep = _step == _stepTitles.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      child: Row(
        children: [
          if (_step > 0)
            OutlinedButton.icon(
              onPressed: _loading ? null : () => setState(() => _step--),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          const Spacer(),
          TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 12),
          if (!isLastStep)
            ElevatedButton.icon(
              onPressed: () {
                if (_validateCurrentStep()) {
                  setState(() => _step++);
                }
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Next Step'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(_isEdit ? Icons.save : Icons.check_circle_rounded, size: 18),
              label: Text(_loading
                  ? 'Saving…'
                  : (_isAdmitMode
                      ? 'Confirm Admission'
                      : (_isEdit ? 'Update Profile' : 'Complete Admission'))),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}
