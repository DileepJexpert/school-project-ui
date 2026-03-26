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

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _qualificationCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();

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
    }
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
      setState(() => _error = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingStaff != null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            Text(isEdit ? 'Edit Staff' : 'Add New Staff',
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
            const SizedBox(height: 20),
            _field(_nameCtrl, 'Full Name', Icons.person),
            _field(_emailCtrl, 'Email', Icons.email),
            _field(_phoneCtrl, 'Phone', Icons.phone),
            _field(_deptCtrl, 'Department', Icons.business),
            _field(_designationCtrl, 'Designation', Icons.work),
            _field(_qualificationCtrl, 'Qualification', Icons.school),
            _field(_salaryCtrl, 'Basic Salary', Icons.currency_rupee,
                isNumber: true),
            if (_error != null) ...
              [const SizedBox(height: 12),
              Text(_error!, style: GoogleFonts.poppins(color: Colors.red))],
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(isEdit ? 'Update Staff' : 'Add Staff',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return '$label is required';
          return null;
        },
      ),
    );
  }
}
