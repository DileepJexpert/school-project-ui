import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/public_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/responsive.dart';
import '../../models/school_data.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _iconMap = {
    'book': Icons.menu_book_rounded,
    'shield': Icons.shield_rounded,
    'globe': Icons.public_rounded,
    'heart': Icons.favorite_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: AppRouter.about,
      child: Column(
        children: [
          PageHeader(
              title: 'About Us', subtitle: 'About ${AppStrings.schoolName}'),
          if (SchoolData.mission.isNotEmpty ||
              SchoolData.vision.isNotEmpty ||
              SchoolData.timeline.isNotEmpty)
            _MissionVisionSection()
          else if (AppStrings.address.isNotEmpty)
            SectionWrapper(
              backgroundColor: PublicColors.white,
              child: Text(
                '${AppStrings.schoolName} is located at ${AppStrings.address}.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          if (SchoolData.coreValues.isNotEmpty) _ValuesSection(),
        ],
      ),
    );
  }
}

class _MissionVisionSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return SectionWrapper(
      backgroundColor: PublicColors.white,
      child: isMobile
          ? Column(children: [
              _missionVision(context),
              const SizedBox(height: 32),
              _timeline(context)
            ])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _missionVision(context)),
                const SizedBox(width: 48),
                Expanded(flex: 5, child: _timeline(context)),
              ],
            ),
    );
  }

  Widget _missionVision(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Our Mission'),
        const SizedBox(height: 16),
        Text(SchoolData.mission, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 32),
        const SectionTitle(title: 'Our Vision'),
        const SizedBox(height: 16),
        Text(SchoolData.vision, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }

  Widget _timeline(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: PublicColors.heroGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Our History',
            style: GoogleFonts.cormorantGaramond(
                color: PublicColors.gold,
                fontSize: 22,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          ...SchoolData.timeline.map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: PublicColors.gold,
                            border: Border.all(
                                color: PublicColors.navyDark, width: 3),
                          ),
                        ),
                        if (event != SchoolData.timeline.last)
                          Container(
                              width: 2,
                              height: 40,
                              color: PublicColors.gold.withValues(alpha: 0.2)),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.year,
                              style: GoogleFonts.nunitoSans(
                                color: PublicColors.goldLight,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              )),
                          const SizedBox(height: 2),
                          Text(event.text,
                              style: GoogleFonts.nunitoSans(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _ValuesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      backgroundColor: PublicColors.creamDark,
      child: Column(
        children: [
          const SectionTitle(title: 'Core Values', centered: true),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = Responsive.gridColumns(context);
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: SchoolData.coreValues
                    .map((v) => SizedBox(
                          width: (constraints.maxWidth - (columns - 1) * 16) /
                              columns,
                          child: AccentCard(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              children: [
                                Icon(
                                  AboutPage._iconMap[v.icon] ?? Icons.star,
                                  color: PublicColors.gold,
                                  size: 36,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  v.title,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cormorantGaramond(
                                    color: PublicColors.navy,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  v.description,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.nunitoSans(
                                      color: PublicColors.textSecondary,
                                      fontSize: 13,
                                      height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
