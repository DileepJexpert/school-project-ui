import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/school_image.dart';

import '../../core/constants/public_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/responsive.dart';
import '../../models/school_data.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: AppRouter.events,
      child: Column(
        children: [
          const PageHeader(
              title: 'Events & Notices',
              subtitle: 'Stay updated with the latest happenings'),
          _NoticesSection(),
          _EventsSection(),
        ],
      ),
    );
  }
}

class _NoticesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      backgroundColor: PublicColors.creamDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Notice Board'),
          const SizedBox(height: 20),
          ...SchoolData.notices.map((n) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: PublicColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.circle_notifications_outlined,
                    color: n.isHighPriority
                        ? PublicColors.error
                        : PublicColors.gold,
                    size: 22,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                          child: Text(n.title,
                              style: GoogleFonts.nunitoSans(
                                  color: PublicColors.navy,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14))),
                      if (n.isHighPriority)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: PublicColors.error,
                              borderRadius: BorderRadius.circular(2)),
                          child: Text('NEW',
                              style: GoogleFonts.nunitoSans(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        ),
                    ],
                  ),
                  trailing: Text(n.date,
                      style: GoogleFonts.nunitoSans(
                          color: PublicColors.textSecondary, fontSize: 12)),
                ),
              )),
        ],
      ),
    );
  }
}

class _EventsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return SectionWrapper(
      backgroundColor: PublicColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Upcoming Events'),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = isMobile ? 1 : 2;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: SchoolData.events.map((e) {
                  final dateParts = e.date.split(' ');
                  final month = dateParts.isNotEmpty ? dateParts[0] : '';
                  final day = dateParts.length > 1
                      ? dateParts[1].replaceAll(',', '')
                      : '';

                  return SizedBox(
                    width:
                        (constraints.maxWidth - (columns - 1) * 16) / columns,
                    child: AccentCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Event photo — shown when imagePath file is present
                          if (e.imagePath?.isNotEmpty == true)
                            SizedBox(
                              height: 150,
                              width: double.infinity,
                              child: SchoolImage(
                                path: e.imagePath!,
                                fallback: Container(
                                  color: PublicColors.navy.withValues(alpha: 0.08),
                                  child: const Icon(Icons.event,
                                      color: PublicColors.textLight, size: 40),
                                ),
                              ),
                            ),
                          // Date + details row
                          Row(children: [
                            Container(
                              width: 70,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              color: PublicColors.navy,
                              child: Column(children: [
                                Text(day,
                                    style: GoogleFonts.cormorantGaramond(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        height: 1)),
                                Text(month.toUpperCase(),
                                    style: GoogleFonts.nunitoSans(
                                        color: PublicColors.goldLight,
                                        fontSize: 11,
                                        letterSpacing: 1,
                                        fontWeight: FontWeight.w600)),
                              ]),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 4),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: PublicColors.goldPale, borderRadius: BorderRadius.circular(4)),
                                        child: Text(e.category,
                                            style: GoogleFonts.nunitoSans(
                                                color: PublicColors.navy,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 10)),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(e.title,
                                          style: GoogleFonts.nunitoSans(
                                              color: PublicColors.navy,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15)),
                                      const SizedBox(height: 4),
                                      Text(e.description,
                                          style: GoogleFonts.nunitoSans(
                                              color: PublicColors.textSecondary,
                                              fontSize: 13,
                                              height: 1.4)),
                                    ]),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ]),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
