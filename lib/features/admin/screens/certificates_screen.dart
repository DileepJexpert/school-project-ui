import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/certificate_api_service.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  bool _loading = true;
  List<dynamic> _certificates = [];

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  Future<void> _loadCertificates() async {
    setState(() => _loading = true);
    try {
      final data = await CertificateApiService.getAllCertificates();
      if (mounted) setState(() => _certificates = data);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Certificate Generation',
                    style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                ),
                onPressed: _showGenerateDialog,
                icon: const Icon(Icons.add, size: 18),
                label: Text('Generate',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Generate transfer, bonafide, character, and study certificates.',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _certTypeCard('Transfer\nCertificate', Icons.swap_horiz,
                  Colors.blue, 'TRANSFER'),
              _certTypeCard('Bonafide\nCertificate', Icons.verified,
                  Colors.green, 'BONAFIDE'),
              _certTypeCard('Character\nCertificate', Icons.star,
                  Colors.orange, 'CHARACTER'),
              _certTypeCard('Study\nCertificate', Icons.school,
                  Colors.purple, 'STUDY'),
            ],
          ),
          const SizedBox(height: 32),
          Text('Recent Certificates',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_certificates.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                    child: Text('No certificates generated yet.',
                        style: GoogleFonts.poppins(
                            color: AppColors.textSecondary))),
              ),
            )
          else
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _certificates.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final cert =
                      _certificates[index] as Map<String, dynamic>;
                  return _buildCertTile(cert);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _certTypeCard(
      String label, IconData icon, Color color, String type) {
    return SizedBox(
      width: 150,
      height: 130,
      child: Card(
        child: InkWell(
          onTap: () => _showGenerateDialog(preselectedType: type),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: color),
                const SizedBox(height: 8),
                Text(label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCertTile(Map<String, dynamic> cert) {
    final studentName = cert['studentName'] as String? ?? '';
    final type = cert['certificateType'] as String? ?? '';
    final serialNumber = cert['serialNumber'] as String? ?? '';
    final generatedAt = cert['generatedAt'] as String? ?? '';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.navy.withOpacity(0.1),
        child: const Icon(Icons.description, color: AppColors.navy, size: 20),
      ),
      title: Text('$type - $studentName',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text('Serial: $serialNumber | $generatedAt',
          style:
              GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
    );
  }

  void _showGenerateDialog({String? preselectedType}) {
    final studentIdCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String certType = preselectedType ?? 'TRANSFER';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Generate Certificate',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: studentIdCtrl,
                decoration:
                    const InputDecoration(labelText: 'Student ID'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: certType,
                decoration:
                    const InputDecoration(labelText: 'Certificate Type'),
                items: ['TRANSFER', 'BONAFIDE', 'CHARACTER', 'STUDY']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => certType = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                    labelText: 'Reason (optional)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await CertificateApiService.generateCertificate({
                    'studentId': studentIdCtrl.text.trim(),
                    'certificateType': certType,
                    'reason': reasonCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadCertificates();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Certificate generated successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }
}
