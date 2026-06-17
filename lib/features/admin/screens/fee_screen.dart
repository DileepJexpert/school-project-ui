// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/fee_api_service.dart';
import 'fee_collection_screen.dart';
import 'fee_setup_screen.dart';
import 'fee_reports_screen.dart';
import 'outstanding_dues_screen.dart';
import 'transaction_history_screen.dart';

class FeeScreen extends StatefulWidget {
  const FeeScreen({super.key});

  @override
  State<FeeScreen> createState() => _FeeScreenState();
}

class _FeeScreenState extends State<FeeScreen> {
  @override
  Widget build(BuildContext context) {
    final modules = [
      _FeeModule(
        icon: Icons.point_of_sale_outlined,
        title: 'Collect Fees',
        subtitle: 'Search a student and process fee payments instantly.',
        color: const Color(0xFF059669),
        page: const FeeCollectionScreen(),
      ),
      _FeeModule(
        icon: Icons.settings_applications_outlined,
        title: 'Fee Structure Setup',
        subtitle: 'Define class-wise fee heads and amounts for each academic year.',
        color: AppColors.info,
        page: const FeeSetupScreen(),
      ),
      _FeeModule(
        icon: Icons.summarize_outlined,
        title: 'Fee Reports',
        subtitle: 'View collection summaries, dues, and class-wise breakdowns with charts.',
        color: AppColors.warning,
        page: const FeeReportsScreen(),
      ),
      _FeeModule(
        icon: Icons.pending_actions_outlined,
        title: 'Outstanding Dues',
        subtitle: 'View all students with pending fees, sorted by highest due amount.',
        color: AppColors.error,
        page: const OutstandingDuesScreen(),
      ),
      _FeeModule(
        icon: Icons.receipt_long_outlined,
        title: 'Transaction History',
        subtitle: 'Browse, filter, and export all fee payment transactions.',
        color: const Color(0xFF7C3AED),
        page: const TransactionHistoryScreen(),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Fee Management Hub',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.navy)),
        const SizedBox(height: 4),
        Text('Manage all aspects of school finances from one place.',
            style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, constraints) {
          final cols = constraints.maxWidth > 700 ? 2 : 1;
          final cardW = (constraints.maxWidth - (cols - 1) * 16) / cols;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              ...modules.map((m) => SizedBox(
                    width: cardW,
                    child: _ModuleCard(module: m),
                  )),
              SizedBox(
                width: cardW,
                child: _ActionCard(
                  icon: Icons.download_rounded,
                  title: 'Bulk Download Receipts',
                  subtitle: 'Download fee receipts for an entire class and academic year as a single PDF.',
                  color: const Color(0xFF0284C7),
                  onTap: () => _showBulkReceiptDialog(context),
                ),
              ),
            ],
          );
        }),
      ]),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showBulkReceiptDialog(BuildContext ctx) {
    String? selectedClass;
    String academicYear = '2025-2026';
    bool downloading = false;
    final yearCtrl = TextEditingController(text: academicYear);

    showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setSt) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
            title: Row(children: [
              const Icon(Icons.download_rounded,
                  color: Color(0xFF0284C7), size: 22),
              const SizedBox(width: 10),
              Text('Bulk Download Receipts',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
            ]),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Download all fee receipts for a class and academic year as a combined PDF.',
                      style: GoogleFonts.nunitoSans(
                          fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 20),
                  Text('Class',
                      style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedClass,
                    hint: Text('Select class...',
                        style: GoogleFonts.nunitoSans(
                            color: AppColors.textLight)),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    items: SchoolConstants.allClasses
                        .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c,
                                style: GoogleFonts.nunitoSans())))
                        .toList(),
                    onChanged: downloading
                        ? null
                        : (v) => setSt(() => selectedClass = v),
                  ),
                  const SizedBox(height: 16),
                  Text('Academic Year',
                      style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: yearCtrl,
                    enabled: !downloading,
                    onChanged: (v) => academicYear = v,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD)),
                      hintText: 'e.g. 2025-2026',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    style: GoogleFonts.nunitoSans(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    downloading ? null : () => Navigator.pop(dialogCtx),
                child: Text('Cancel',
                    style: GoogleFonts.nunitoSans(
                        color: AppColors.textSecondary)),
              ),
              ElevatedButton.icon(
                onPressed: selectedClass == null ||
                        yearCtrl.text.trim().isEmpty ||
                        downloading
                    ? null
                    : () async {
                        setSt(() => downloading = true);
                        try {
                          final bytes =
                              await FeeApiService.downloadBulkReceipts(
                                  selectedClass!, yearCtrl.text.trim());
                          final blob = html.Blob(
                              [Uint8List.fromList(bytes)],
                              'application/pdf');
                          final url =
                              html.Url.createObjectUrlFromBlob(blob);
                          html.AnchorElement(href: url)
                            ..setAttribute('download',
                                'receipts_${selectedClass}_${yearCtrl.text.trim()}.pdf')
                            ..click();
                          html.Url.revokeObjectUrl(url);
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                          _showSnack(
                              'Receipts downloaded for $selectedClass (${yearCtrl.text.trim()})');
                        } catch (e) {
                          setSt(() => downloading = false);
                          _showSnack(
                              'Failed to download bulk receipts: $e',
                              isError: true);
                        }
                      },
                icon: downloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(
                    downloading ? 'Downloading...' : 'Download'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final _FeeModule module;
  const _ModuleCard({required this.module});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => module.page)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: module.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              ),
              child: Icon(module.icon, color: module.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(module.title,
                    style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(module.subtitle,
                    style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 13)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textLight),
          ]),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 13)),
              ]),
            ),
            Icon(Icons.chevron_right, color: color),
          ]),
        ),
      ),
    );
  }
}

class _FeeModule {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget page;
  const _FeeModule({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.page,
  });
}
