import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../services/staff_api_service.dart';

class StaffFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existingStaff;
  final VoidCallback onSaved;

  const StaffFormScreen({super.key, this.existingStaff, required this.onSaved});

  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  String _selectedCategory = 'TEACHER';
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _qualificationCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();

  final List<Map<String, dynamic>> _categories = [
    {
      'code': 'TEACHER',
      'label': 'Teacher / Teaching Faculty',
      'icon': Icons.school_outlined,
      'defaultDept': 'Teaching',
      'suggestions': ['PRT Teacher', 'TGT Teacher', 'PGT Teacher', 'Subject Specialist'],
    },
    {
      'code': 'DRIVER',
      'label': 'Driver / Transport Staff',
      'icon': Icons.directions_bus_filled_outlined,
      'defaultDept': 'Transport',
      'suggestions': ['Head Bus Driver', 'School Van Driver', 'Transport Conductor'],
    },
    {
      'code': 'PEON',
      'label': 'Peon / Support Staff / Helper',
      'icon': Icons.cleaning_services_outlined,
      'defaultDept': 'Support Staff',
      'suggestions': ['Office Peon', 'Classroom Attendant', 'Helper & Cleaner', 'Ayah'],
    },
    {
      'code': 'ADMIN',
      'label': 'Administration / Management',
      'icon': Icons.admin_panel_settings_outlined,
      'defaultDept': 'Administration',
      'suggestions': ['Administrative Officer', 'Clerk', 'Office Executive', 'Receptionist'],
    },
    {
      'code': 'ACCOUNTANT',
      'label': 'Accounts & Finance',
      'icon': Icons.account_balance_outlined,
      'defaultDept': 'Accounts',
      'suggestions': ['Accountant', 'Fee Cashier', 'Billing Executive'],
    },
    {
      'code': 'SECURITY',
      'label': 'Security Staff',
      'icon': Icons.shield_outlined,
      'defaultDept': 'Security',
      'suggestions': ['Security Guard', 'Gate Watchman', 'Head Security Officer'],
    },
    {
      'code': 'OTHER',
      'label': 'Other Staff Member',
      'icon': Icons.badge_outlined,
      'defaultDept': 'General',
      'suggestions': ['Staff Member', 'Technician', 'Librarian'],
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingStaff != null) {
      final s = widget.existingStaff!;
      _nameCtrl.text = s['fullName'] ?? '';
      _emailCtrl.text = s['email'] ?? '';
      _phoneCtrl.text = s['phone'] ?? '';
      _deptCtrl.text = s['department'] ?? '';
      _designationCtrl.text = s['designation'] ?? '';
      _qualificationCtrl.text = s['qualification'] ?? '';
      _salaryCtrl.text = (s['basicSalary'] ?? '').toString();
      final cat = (s['category'] as String? ?? '').toUpperCase();
      if (_categories.any((c) => c['code'] == cat)) {
        _selectedCategory = cat;
      }
    } else {
      _deptCtrl.text = 'Teaching';
    }
  }

  void _onCategoryChanged(String newCat) {
    setState(() {
      _selectedCategory = newCat;
      final meta = _categories.firstWhere((c) => c['code'] == newCat);
      if (_deptCtrl.text.isEmpty ||
          _categories.any((c) => c['defaultDept'] == _deptCtrl.text)) {
        _deptCtrl.text = meta['defaultDept'] as String;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _deptCtrl.dispose();
    _designationCtrl.dispose();
    _qualificationCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final data = {
      'fullName': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'category': _selectedCategory,
      'department': _deptCtrl.text.trim(),
      'designation': _designationCtrl.text.trim(),
      'qualification': _qualificationCtrl.text.trim(),
      'basicSalary': double.tryParse(_salaryCtrl.text.trim()) ?? 0,
    };

    try {
      if (widget.existingStaff != null) {
        await StaffApiService.updateStaff(widget.existingStaff!['id'], data);
      } else {
        await StaffApiService.createStaff(data);
      }
      widget.onSaved();
    } catch (e) {
      setState(() => _error = 'Failed to save staff member: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingStaff != null;
    final currentCatMeta = _categories.firstWhere((c) => c['code'] == _selectedCategory);
    final suggestions = currentCatMeta['suggestions'] as List<String>;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            Row(
              children: [
                Icon(isEdit ? Icons.edit_note_rounded : Icons.person_add_rounded,
                    color: AppColors.navy, size: 28),
                const SizedBox(width: 10),
                Text(
                  isEdit ? 'Edit Staff Member' : 'Register New Staff Member',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Staff Category Dropdown
            Text(
              'Staff Category *',
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down_circle_outlined,
                      color: Color(0xFF2563EB)),
                  onChanged: (v) {
                    if (v != null) _onCategoryChanged(v);
                  },
                  items: _categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat['code'] as String,
                      child: Row(
                        children: [
                          Icon(cat['icon'] as IconData,
                              size: 18, color: AppColors.navy),
                          const SizedBox(width: 10),
                          Text(
                            cat['label'] as String,
                            style: GoogleFonts.nunitoSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),

            _field(_nameCtrl, 'Full Name *', Icons.person),
            _field(_emailCtrl, 'Email Address *', Icons.email, isEmail: true),
            _field(_phoneCtrl, 'Contact Phone Number', Icons.phone),

            Row(
              children: [
                Expanded(
                  child: _field(_deptCtrl, 'Department *', Icons.business),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(_designationCtrl, 'Designation / Role *', Icons.work),
                ),
              ],
            ),

            // Quick designation suggestions chips
            if (suggestions.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: suggestions.map((s) {
                  return ActionChip(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    label: Text(s, style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      setState(() => _designationCtrl.text = s);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
            ],

            _field(_qualificationCtrl, 'Qualification / Experience', Icons.school),

            _field(
              _salaryCtrl,
              'Monthly Basic Salary (₹) *',
              Icons.currency_rupee,
              isNumber: true,
              helperText: 'Base monthly payout before allowances and deductions',
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style: GoogleFonts.nunitoSans(
                        color: AppColors.error, fontWeight: FontWeight.w600)),
              ),
            ],
            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(
                      isEdit ? 'Update Staff Member' : 'Register Staff Member',
                      style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isNumber = false,
    bool isEmail = false,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isNumber
            ? TextInputType.number
            : (isEmail ? TextInputType.emailAddress : TextInputType.text),
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        validator: (v) {
          if (label.contains('*') && (v == null || v.trim().isEmpty)) {
            return '$label is required';
          }
          return null;
        },
      ),
    );
  }
}
