import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/public_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/responsive.dart';
import '../../models/school_data.dart';

class TransportPage extends StatelessWidget {
  const TransportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return AppShell(
      currentRoute: AppRouter.transport,
      child: Column(
        children: [
          const PageHeader(
              title: 'Transport Services',
              subtitle: 'School transport routes and information'),
          SectionWrapper(
            backgroundColor: PublicColors.white,
            child: isMobile
                ? Column(children: [
                    _zonesTable(context),
                    const SizedBox(height: 32),
                    _safetyFeatures(context)
                  ])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: _zonesTable(context)),
                      const SizedBox(width: 36),
                      Expanded(flex: 4, child: _safetyFeatures(context)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _zonesTable(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Zone-wise Routes & Fees'),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(PublicColors.navy),
            headingTextStyle: GoogleFonts.nunitoSans(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            dataTextStyle: GoogleFonts.nunitoSans(
                fontSize: 13, color: PublicColors.textPrimary),
            border: TableBorder.all(color: PublicColors.border, width: 0.5),
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('Zone')),
              DataColumn(label: Text('Areas Covered')),
              DataColumn(label: Text('Distance')),
              DataColumn(label: Text('Monthly Fee')),
            ],
            rows: SchoolData.transportZones
                .map((z) => DataRow(cells: [
                      DataCell(Text(z.zone,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: PublicColors.navy))),
                      DataCell(Text(z.area)),
                      DataCell(Text(z.distance)),
                      DataCell(Text('₹ ${z.fee}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: PublicColors.gold))),
                    ]))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _safetyFeatures(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Safety Features'),
        const SizedBox(height: 20),
        ...SchoolData.transportFeatures.map((f) => Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: PublicColors.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_user,
                      color: PublicColors.gold, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(f,
                          style: GoogleFonts.nunitoSans(
                              fontSize: 14, height: 1.4))),
                ],
              ),
            )),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PublicColors.goldPale,
            border: Border.all(color: PublicColors.gold),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.directions_bus,
                  color: PublicColors.navy, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fleet Size',
                        style: GoogleFonts.nunitoSans(
                            color: PublicColors.navy,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      '32 buses covering 120+ routes across all four zones, serving 1,800+ students daily.',
                      style: GoogleFonts.nunitoSans(
                          color: PublicColors.textPrimary,
                          fontSize: 13,
                          height: 1.5),
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
}
