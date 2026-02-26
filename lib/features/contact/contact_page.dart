import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/responsive.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedGrade = '';
  bool _submitted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      // TODO: Replace with DioClient.post('/contact/enquiry', data: {...})
      setState(() => _submitted = true);
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _messageController.clear();
      _selectedGrade = '';
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _submitted = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return AppShell(
      currentRoute: AppRouter.contact,
      child: Column(
        children: [
          const PageHeader(title: 'Contact Us', subtitle: "We'd love to hear from you"),
          SectionWrapper(
            backgroundColor: AppColors.white,
            child: isMobile
                ? Column(children: [_form(context), const SizedBox(height: 32), _contactInfo(context)])
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Send an Inquiry'),
        const SizedBox(height: 20),

        if (_submitted)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Thank you! Your inquiry has been submitted. We'll respond within 24 hours.",
                    style: GoogleFonts.nunitoSans(color: AppColors.success, fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(hintText: 'Full Name *'),
                    validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(hintText: 'Email Address *'),
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'Required';
                      if (!v!.contains('@')) return 'Invalid email';
                      return null;
                    },
                  )),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(hintText: 'Phone Number'),
                  )),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedGrade.isEmpty ? null : _selectedGrade,
                      decoration: const InputDecoration(hintText: 'Select Grade'),
                      items: ['Kindergarten', 'Grade 1–5', 'Grade 6–8', 'Grade 9–10', 'Grade 11–12']
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedGrade = v ?? ''),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                maxLines: 5,
                decoration: const InputDecoration(hintText: 'Your Message *'),
                validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _handleSubmit,
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Submit Inquiry'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contactInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Get in Touch'),
        const SizedBox(height: 20),
        ...[
          _ContactRow(icon: Icons.location_on_outlined, label: 'Address', value: AppStrings.address),
          _ContactRow(icon: Icons.phone_outlined, label: 'Phone', value: AppStrings.phone),
          _ContactRow(icon: Icons.email_outlined, label: 'Email', value: AppStrings.email),
          _ContactRow(icon: Icons.access_time_outlined, label: 'Office Hours', value: AppStrings.officeHours),
        ],
        const SizedBox(height: 24),
        // Map placeholder
        Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.creamDark,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 32, color: AppColors.textLight.withOpacity(0.4)),
              const SizedBox(height: 8),
              Text('Interactive Map — Embed Google Maps here',
                style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ContactRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.nunitoSans(
                  color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.nunitoSans(
                  color: AppColors.textPrimary, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
