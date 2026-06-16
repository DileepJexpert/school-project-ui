import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/responsive.dart';
import '../../services/school_website_service.dart';
import '../../services/tenant_service.dart';

class OnlineAdmissionFormPage extends StatefulWidget {
  const OnlineAdmissionFormPage({super.key});

  @override
  State<OnlineAdmissionFormPage> createState() =>
      _OnlineAdmissionFormPageState();
}

class _OnlineAdmissionFormPageState extends State<OnlineAdmissionFormPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Loading / error state
  bool _isSubmitting = false;
  bool _isLoadingClasses = true;
  List<String> _availableClasses = [];

  // ── Step 1: Student Information ──
  final _fullNameCtrl = TextEditingController();
  DateTime? _dateOfBirth;
  String? _gender;
  String? _bloodGroup;
  String? _classApplyingFor;
  final _academicYearCtrl = TextEditingController();

  // ── Step 2: Parent / Guardian Information ──
  final _fatherNameCtrl = TextEditingController();
  final _fatherOccupationCtrl = TextEditingController();
  final _fatherMobileCtrl = TextEditingController();
  final _fatherEmailCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _motherOccupationCtrl = TextEditingController();
  final _motherMobileCtrl = TextEditingController();
  final _motherEmailCtrl = TextEditingController();

  // ── Step 3: Contact & Previous School ──
  final _addressCtrl = TextEditingController();
  final _primaryContactCtrl = TextEditingController();
  final _previousSchoolCtrl = TextEditingController();
  final _previousClassCtrl = TextEditingController();
  String? _previousBoard;

  static const _genders = ['Male', 'Female', 'Other'];
  static const _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'
  ];
  static const _boards = ['CBSE', 'ICSE', 'State Board', 'Other'];

  @override
  void initState() {
    super.initState();
    // Default academic year based on current date
    final now = DateTime.now();
    final startYear = now.month >= 4 ? now.year : now.year - 1;
    _academicYearCtrl.text = '$startYear-${startYear + 1}';
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final tenantId = await TenantService.getTenantId();
      final classes =
          await SchoolWebsiteService.getAvailableClasses(tenantId);
      if (mounted) {
        setState(() {
          _availableClasses = classes;
          _isLoadingClasses = false;
        });
      }
    } catch (_) {
      // Fallback to SchoolConstants base classes if API fails
      if (mounted) {
        setState(() {
          _availableClasses = SchoolConstants.baseClasses;
          _isLoadingClasses = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _academicYearCtrl.dispose();
    _fatherNameCtrl.dispose();
    _fatherOccupationCtrl.dispose();
    _fatherMobileCtrl.dispose();
    _fatherEmailCtrl.dispose();
    _motherNameCtrl.dispose();
    _motherOccupationCtrl.dispose();
    _motherMobileCtrl.dispose();
    _motherEmailCtrl.dispose();
    _addressCtrl.dispose();
    _primaryContactCtrl.dispose();
    _previousSchoolCtrl.dispose();
    _previousClassCtrl.dispose();
    super.dispose();
  }

  // ── Validation helpers ──

  bool _validateCurrentStep() {
    // Only validate fields relevant to the current step
    switch (_currentStep) {
      case 0:
        return _fullNameCtrl.text.trim().isNotEmpty &&
            _classApplyingFor != null;
      case 1:
        return _fatherMobileCtrl.text.trim().isNotEmpty ||
            _motherMobileCtrl.text.trim().isNotEmpty;
      case 2:
        return true; // All optional
      default:
        return true;
    }
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    if (!_validateCurrentStep()) return;
    setState(() => _currentStep++);
  }

  void _prevStep() {
    setState(() => _currentStep--);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Final check: required fields
    if (_fullNameCtrl.text.trim().isEmpty || _classApplyingFor == null) {
      _showError('Please fill in all required fields (Student Name and Class).');
      return;
    }
    if (_fatherMobileCtrl.text.trim().isEmpty &&
        _motherMobileCtrl.text.trim().isEmpty) {
      _showError(
          'At least one parent/guardian mobile number is required.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final tenantId = await TenantService.getTenantId();
      final data = _buildPayload();
      final response =
          await SchoolWebsiteService.submitPublicAdmission(tenantId, data);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      final enquiryNumber =
          response['admissionNumber'] ?? response['enquiryNumber'] ?? 'N/A';
      _showSuccessDialog(enquiryNumber.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError('Failed to submit application. Please try again later.');
    }
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'fullName': _fullNameCtrl.text.trim(),
      if (_dateOfBirth != null)
        'dateOfBirth': DateFormat('yyyy-MM-dd').format(_dateOfBirth!),
      'gender': _gender ?? '',
      'bloodGroup': _bloodGroup ?? '',
      'classForAdmission': _classApplyingFor ?? '',
      'academicYear': _academicYearCtrl.text.trim(),
      'fatherName': _fatherNameCtrl.text.trim(),
      'fatherOccupation': _fatherOccupationCtrl.text.trim(),
      'fatherMobile': _fatherMobileCtrl.text.trim(),
      'fatherEmail': _fatherEmailCtrl.text.trim(),
      'motherName': _motherNameCtrl.text.trim(),
      'motherOccupation': _motherOccupationCtrl.text.trim(),
      'motherMobile': _motherMobileCtrl.text.trim(),
      'motherEmail': _motherEmailCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'primaryContactNumber': _primaryContactCtrl.text.trim(),
      'previousSchoolName': _previousSchoolCtrl.text.trim(),
      'previousClass': _previousClassCtrl.text.trim(),
      'previousBoard': _previousBoard ?? '',
    };
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog(String enquiryNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Application Submitted!',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.goldPale,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  enquiryNumber,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your application has been submitted successfully. '
                'The school will contact you shortly.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.pushReplacementNamed(
                        context, AppRouter.admissions);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Back to Admissions',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Pick date of birth ──
  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 6, 1, 1),
      firstDate: DateTime(now.year - 25),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.navy,
              onPrimary: Colors.white,
              secondary: AppColors.gold,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: AppRouter.admissions,
      child: Column(
        children: [
          const PageHeader(
            title: 'Online Admission Application',
            subtitle: 'Fill in the details below to apply for admission',
          ),
          SectionWrapper(
            backgroundColor: AppColors.cream,
            child: _buildFormContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step indicators
          _buildStepIndicator(),
          const SizedBox(height: 32),

          // Form card
          Container(
            padding: EdgeInsets.all(isDesktop ? 32 : 20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step title
                Text(
                  _stepTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _stepSubtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Step body
                if (_currentStep == 0) _buildStep1(context),
                if (_currentStep == 1) _buildStep2(context),
                if (_currentStep == 2) _buildStep3(context),

                const SizedBox(height: 32),

                // Navigation buttons
                _buildStepButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _stepTitle {
    switch (_currentStep) {
      case 0:
        return 'Student Information';
      case 1:
        return 'Parent / Guardian Information';
      case 2:
        return 'Contact & Previous School';
      default:
        return '';
    }
  }

  String get _stepSubtitle {
    switch (_currentStep) {
      case 0:
        return 'Fields marked with * are required';
      case 1:
        return 'At least one parent/guardian mobile number is required';
      case 2:
        return 'Previous school details (optional)';
      default:
        return '';
    }
  }

  // ── Step indicator ──

  Widget _buildStepIndicator() {
    final labels = ['Student Info', 'Parent Info', 'Contact & School'];
    final isMobile = Responsive.isMobile(context);

    return Row(
      children: List.generate(labels.length, (i) {
        final isActive = i == _currentStep;
        final isCompleted = i < _currentStep;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isCompleted || isActive
                            ? AppColors.gold
                            : AppColors.border,
                      ),
                    ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? AppColors.navy
                          : isCompleted
                              ? AppColors.gold
                              : AppColors.border,
                    ),
                    alignment: Alignment.center,
                    child: isCompleted
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 16)
                        : Text(
                            '${i + 1}',
                            style: GoogleFonts.poppins(
                              color: isActive
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  if (i < labels.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isCompleted
                            ? AppColors.gold
                            : AppColors.border,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (!isMobile)
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive
                        ? AppColors.navy
                        : AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  // ── Step 1: Student Information ──

  Widget _buildStep1(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    final fields = <Widget>[
      _buildTextField(
        controller: _fullNameCtrl,
        label: 'Full Name',
        required: true,
        icon: Icons.person_outline,
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
      ),
      _buildDateField(
        label: 'Date of Birth',
        value: _dateOfBirth,
        onTap: _pickDateOfBirth,
        icon: Icons.calendar_today_outlined,
      ),
      _buildDropdown(
        label: 'Gender',
        value: _gender,
        items: _genders,
        icon: Icons.wc_outlined,
        onChanged: (v) => setState(() => _gender = v),
      ),
      _buildDropdown(
        label: 'Blood Group',
        value: _bloodGroup,
        items: _bloodGroups,
        icon: Icons.bloodtype_outlined,
        onChanged: (v) => setState(() => _bloodGroup = v),
      ),
      _isLoadingClasses
          ? _buildLoadingField(label: 'Class Applying For *')
          : _buildDropdown(
              label: 'Class Applying For',
              value: _classApplyingFor,
              items: _availableClasses,
              required: true,
              icon: Icons.class_outlined,
              onChanged: (v) => setState(() => _classApplyingFor = v),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Please select a class' : null,
            ),
      _buildTextField(
        controller: _academicYearCtrl,
        label: 'Academic Year',
        icon: Icons.date_range_outlined,
        readOnly: true,
      ),
    ];

    return _buildFieldGrid(fields, isDesktop);
  }

  // ── Step 2: Parent / Guardian Information ──

  Widget _buildStep2(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Father's details
        Text(
          "Father's Details",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        _buildFieldGrid([
          _buildTextField(
            controller: _fatherNameCtrl,
            label: "Father's Name",
            icon: Icons.person_outline,
          ),
          _buildTextField(
            controller: _fatherOccupationCtrl,
            label: "Father's Occupation",
            icon: Icons.work_outline,
          ),
          _buildTextField(
            controller: _fatherMobileCtrl,
            label: "Father's Mobile",
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),
          _buildTextField(
            controller: _fatherEmailCtrl,
            label: "Father's Email",
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
        ], isDesktop),

        const SizedBox(height: 24),
        Container(height: 1, color: AppColors.border),
        const SizedBox(height: 24),

        // Mother's details
        Text(
          "Mother's Details",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        _buildFieldGrid([
          _buildTextField(
            controller: _motherNameCtrl,
            label: "Mother's Name",
            icon: Icons.person_outline,
          ),
          _buildTextField(
            controller: _motherOccupationCtrl,
            label: "Mother's Occupation",
            icon: Icons.work_outline,
          ),
          _buildTextField(
            controller: _motherMobileCtrl,
            label: "Mother's Mobile",
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),
          _buildTextField(
            controller: _motherEmailCtrl,
            label: "Mother's Email",
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
        ], isDesktop),
      ],
    );
  }

  // ── Step 3: Contact & Previous School ──

  Widget _buildStep3(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Details',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _addressCtrl,
          label: 'Address',
          icon: Icons.location_on_outlined,
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        _buildFieldGrid([
          _buildTextField(
            controller: _primaryContactCtrl,
            label: 'Primary Contact Number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),
        ], isDesktop),

        const SizedBox(height: 24),
        Container(height: 1, color: AppColors.border),
        const SizedBox(height: 24),

        Text(
          'Previous School Details',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        _buildFieldGrid([
          _buildTextField(
            controller: _previousSchoolCtrl,
            label: 'Previous School Name',
            icon: Icons.school_outlined,
          ),
          _buildTextField(
            controller: _previousClassCtrl,
            label: 'Previous Class',
            icon: Icons.class_outlined,
          ),
          _buildDropdown(
            label: 'Previous Board',
            value: _previousBoard,
            items: _boards,
            icon: Icons.account_balance_outlined,
            onChanged: (v) => setState(() => _previousBoard = v),
          ),
        ], isDesktop),
      ],
    );
  }

  // ── Reusable field builders ──

  Widget _buildFieldGrid(List<Widget> fields, bool isDesktop) {
    if (!isDesktop) {
      return Column(
        children: fields
            .map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: f,
                ))
            .toList(),
      );
    }

    // Two-column grid on desktop
    final rows = <Widget>[];
    for (int i = 0; i < fields.length; i += 2) {
      final isLast = i + 1 >= fields.length;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: fields[i]),
              const SizedBox(width: 16),
              Expanded(child: isLast ? const SizedBox() : fields[i + 1]),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool required = false,
    IconData? icon,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
      validator: validator,
      decoration: _fieldDecoration(
        label: required ? '$label *' : label,
        icon: icon,
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: _fieldDecoration(label: label, icon: icon),
        child: Text(
          value != null
              ? DateFormat('dd MMM yyyy').format(value)
              : 'Select date',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: value != null
                ? AppColors.textPrimary
                : AppColors.textLight,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    bool required = false,
    IconData? icon,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
      decoration: _fieldDecoration(
        label: required ? '$label *' : label,
        icon: icon,
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      validator: validator,
      dropdownColor: AppColors.white,
    );
  }

  Widget _buildLoadingField({required String label}) {
    return InputDecorator(
      decoration: _fieldDecoration(
        label: label,
        icon: Icons.class_outlined,
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Loading classes...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(
        fontSize: 13,
        color: AppColors.textSecondary,
      ),
      prefixIcon: icon != null
          ? Icon(icon, size: 20, color: AppColors.textSecondary)
          : null,
      filled: true,
      fillColor: AppColors.cream,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      errorStyle: GoogleFonts.poppins(fontSize: 11, color: AppColors.error),
    );
  }

  // ── Step buttons ──

  Widget _buildStepButtons() {
    return Row(
      children: [
        if (_currentStep > 0)
          OutlinedButton.icon(
            onPressed: _prevStep,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text('Previous', style: GoogleFonts.poppins()),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              side: const BorderSide(color: AppColors.navy),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        const Spacer(),
        if (_currentStep < 2)
          ElevatedButton.icon(
            onPressed: _nextStep,
            icon: Text('Next', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            label: const Icon(Icons.arrow_forward, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        if (_currentStep == 2)
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, size: 18),
            label: Text(
              _isSubmitting ? 'Submitting...' : 'Submit Application',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              disabledBackgroundColor: AppColors.gold.withOpacity(0.5),
            ),
          ),
      ],
    );
  }
}
