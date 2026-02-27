import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import 'fee_collection_screen.dart';
import 'fee_setup_screen.dart';
import 'fee_reports_screen.dart';
import 'transaction_history_screen.dart';

class FeeScreen extends StatelessWidget {
  const FeeScreen({super.key});

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
            children: modules
                .map((m) => SizedBox(
                      width: cardW,
                      child: _ModuleCard(module: m),
                    ))
                .toList(),
          );
        }),
      ]),
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
