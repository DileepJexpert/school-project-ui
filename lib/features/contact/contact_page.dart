import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/public_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/responsive.dart';
import '../../services/dio_client.dart';
import '../../models/school_data.dart';
import '../../core/widgets/searchable_dropdown.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  static const _publicFormsEnabled =
      bool.fromEnvironment('PUBLIC_FORMS_ENABLED', defaultValue: true);
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedGrade = '';
  bool _submitted = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await DioClient.post('/contact/enquiry', data: {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gradeInterested': _selectedGrade,
        'message': _messageController.text.trim(),
      });
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _messageController.clear();
      if (mounted)
        setState(() {
          _submitted = true;
          _selectedGrade = '';
        });
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _submitted = false);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: PublicColors.error));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return AppShell(
      currentRoute: AppRouter.contact,
      child: Column(
        children: [
          const PageHeader(
              title: 'Contact Us', subtitle: "We'd love to hear from you"),
          SectionWrapper(
            backgroundColor: PublicColors.white,
            child: !_publicFormsEnabled
                ? _contactInfo(context)
                : isMobile
                    ? Column(children: [
                        _form(context),
                        const SizedBox(height: 32),
                        _contactInfo(context)
                      ])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: _form(context)),
                          const SizedBox(width: 48),
                          Expanded(flex: 4, child: _contactInfo(context)),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _form(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A101828),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Send an Inquiry'),
          const SizedBox(height: 20),
          if (_submitted)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PublicColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PublicColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: PublicColors.success, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Thank you! Your inquiry has been submitted. We'll respond within 24 hours.",
                      style: GoogleFonts.nunitoSans(
                          color: PublicColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
          Form(
            key: _formKey,
            child: Column(
              children: [
                if (isMobile) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'Required';
                      if (!v!.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email Address *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v?.isEmpty ?? true) return 'Required';
                            if (!v!.contains('@')) return 'Invalid email';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                if (isMobile) ...[
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SearchableDropdownFormField<String>(
                    labelText: 'Grade / Class of Interest',
                    hintText: 'Select or type class...',
                    initialValue: _selectedGrade.isEmpty ? null : _selectedGrade,
                    items: const [
                      'Kindergarten',
                      'Grade 1–5',
                      'Grade 6–8',
                      'Grade 9–10',
                      'Grade 11–12'
                    ],
                    onChanged: (v) => setState(() => _selectedGrade = v ?? ''),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SearchableDropdownFormField<String>(
                          labelText: 'Grade / Class of Interest',
                          hintText: 'Select or type class...',
                          initialValue: _selectedGrade.isEmpty ? null : _selectedGrade,
                          items: const [
                            'Kindergarten',
                            'Grade 1–5',
                            'Grade 6–8',
                            'Grade 9–10',
                            'Grade 11–12'
                          ],
                          onChanged: (v) => setState(() => _selectedGrade = v ?? ''),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _messageController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Your Message *',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PublicColors.navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _submitting ? 'Submitting…' : 'Submit Inquiry',
                      style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Get in Touch'),
        const SizedBox(height: 20),
        ...[
          _ContactRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: AppStrings.address),
          _ContactRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: AppStrings.phone),
          _ContactRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: AppStrings.email),
          _ContactRow(
              icon: Icons.access_time_outlined,
              label: 'Office Hours',
              value: AppStrings.officeHours),
          if (SchoolData.facebookUrl.isNotEmpty)
            _ContactRow(
                icon: Icons.facebook,
                label: 'Facebook',
                value: SchoolData.facebookUrl),
        ].where((row) => row.value.isNotEmpty),
        if (SchoolData.mapUrl.isNotEmpty) ...[
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              final url = Uri.tryParse(SchoolData.mapUrl);
              if (url != null &&
                  (url.scheme == 'https' || url.scheme == 'http')) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.map_outlined),
            label: const Text('Open school map'),
          ),
        ],
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ContactRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PublicColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: PublicColors.gold, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.nunitoSans(
                        color: PublicColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.nunitoSans(
                        color: PublicColors.textPrimary,
                        fontSize: 13,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
