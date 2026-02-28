import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/responsive.dart';
import '../../models/school_data.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: AppRouter.home,
      child: Column(
        children: [
          _HeroSection(),
          _StatsStrip(),
          _PrincipalSection(),
          _AchievementsSection(),
          _TestimonialsSection(),
          _EventsPreview(),
          CtaBanner(
            title: 'Admissions Open for 2026–27',
            subtitle: 'Join the Springfield family. Limited seats available across all grades.',
            buttonText: 'Start Application',
            onPressed: () => Navigator.pushReplacementNamed(context, AppRouter.admissions),
          ),
        ],
      ),
    );
  }
}

// =============================================
// HERO
// =============================================
class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: isMobile ? 500 : 600),
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Stack(
        children: [
          // ── Real school photo as hero background ──────────────────────────
          // Place your school building / campus photo at:
          //   assets/images/home/hero_bg.jpg
          // It will show behind a dark overlay to keep text readable.
          Positioned.fill(
            child: Image.asset(
              SchoolData.heroBannerImagePath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(), // no photo yet → gradient shows
            ),
          ),
          // Dark overlay so text stays readable over the photo
          Positioned.fill(
            child: Container(color: AppColors.navyDark.withOpacity(0.65)),
          ),
          // Decorative circle
          if (!isMobile)
            Positioned(
              right: -80,
              top: 80,
              child: Container(
                width: 400, height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold.withOpacity(0.08), width: 2),
                ),
              ),
            ),
          // Content
          ContentContainer(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.contentPadding(context),
              vertical: isMobile ? 48 : 80,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.12),
                    border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${AppStrings.accreditation}  •  Est. ${AppStrings.founded}',
                    style: GoogleFonts.nunitoSans(
                      color: AppColors.goldLight,
                      fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                SizedBox(
                  width: isMobile ? double.infinity : 600,
                  child: Text(
                    AppStrings.schoolName,
                    style: GoogleFonts.cormorantGaramond(
                      color: Colors.white,
                      fontSize: isMobile ? 36 : 52,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tagline
                Text(
                  '"${AppStrings.tagline}"',
                  style: GoogleFonts.cormorantGaramond(
                    color: AppColors.goldLight,
                    fontSize: isMobile ? 18 : 22,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                SizedBox(
                  width: isMobile ? double.infinity : 520,
                  child: Text(
                    'Providing world-class K-12 education rooted in values, discipline, and academic excellence for over three decades.',
                    style: GoogleFonts.nunitoSans(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14, height: 1.8,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Buttons
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Apply Now'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.explore_outlined, size: 18),
                      label: const Text('Discover More'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.gold, width: 2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================
// STATS STRIP
// =============================================
class _StatsStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: ContentContainer(
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 16,
          runSpacing: 16,
          children: SchoolData.stats.map((stat) => SizedBox(
            width: isMobile ? 140 : null,
            child: Column(
              children: [
                Text(
                  stat.value,
                  style: GoogleFonts.cormorantGaramond(
                    color: AppColors.gold, fontSize: isMobile ? 22 : 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat.label.toUpperCase(),
                  style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary, fontSize: 11,
                    letterSpacing: 1.0, fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }
}

// =============================================
// PRINCIPAL'S MESSAGE
// =============================================
class _PrincipalSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return SectionWrapper(
      backgroundColor: AppColors.creamDark,
      child: isMobile
          ? Column(children: [_principalPhoto(context), const SizedBox(height: 32), _principalContent(context)])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: _principalPhoto(context)),
                const SizedBox(width: 48),
                Expanded(flex: 6, child: _principalContent(context)),
              ],
            ),
    );
  }

  Widget _principalPhoto(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        children: [
          // Principal photo — place image at: assets/images/home/principal.jpg
          CircleAvatar(
            radius: 54,
            backgroundColor: AppColors.goldPale,
            backgroundImage: AssetImage(SchoolData.principalImagePath),
            onBackgroundImageError: (_, __) {},
            child: null, // icon shown as fallback via onBackgroundImageError
          ),
          const SizedBox(height: 16),
          Text(
            SchoolData.principalName,
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            SchoolData.principalTitle,
            style: GoogleFonts.nunitoSans(color: AppColors.goldLight, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _principalContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.format_quote, color: AppColors.gold.withOpacity(0.4), size: 36),
        const SizedBox(height: 8),
        const SectionTitle(title: "Principal's Message"),
        const SizedBox(height: 20),
        Text(
          SchoolData.principalMessage,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        Text(
          '— ${SchoolData.principalName}',
          style: GoogleFonts.cormorantGaramond(
            color: AppColors.navy, fontWeight: FontWeight.w600, fontSize: 16,
          ),
        ),
      ],
    );
  }
}

// =============================================
// ACHIEVEMENTS
// =============================================
class _AchievementsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      backgroundColor: AppColors.white,
      child: Column(
        children: [
          const SectionTitle(title: 'Achievements & Recognition', centered: true),
          const SizedBox(height: 12),
          Text(
            'Our students and faculty consistently bring home honors across academics, sports, and creative disciplines.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = Responsive.gridColumns(context);
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: SchoolData.achievements.map((a) => SizedBox(
                  width: (constraints.maxWidth - (columns - 1) * 16) / columns,
                  child: AccentCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.emoji_events, color: AppColors.gold, size: 20),
                            const SizedBox(width: 8),
                            Text(a.year, style: GoogleFonts.nunitoSans(
                              color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5,
                            )),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(a.title, style: GoogleFonts.nunitoSans(
                          color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 14,
                        )),
                      ],
                    ),
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// =============================================
// TESTIMONIALS
// =============================================
class _TestimonialsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      padding: EdgeInsets.symmetric(vertical: isMobile ? 48 : 64),
      child: ContentContainer(
        child: Column(
          children: [
            SectionTitle(title: 'What Our Community Says', centered: true, color: Colors.white),
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = isMobile ? 1 : 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: SchoolData.testimonials.map((t) => SizedBox(
                    width: (constraints.maxWidth - (columns - 1) * 16) / columns,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(color: AppColors.gold.withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.format_quote, color: AppColors.gold.withOpacity(0.4), size: 24),
                          const SizedBox(height: 8),
                          Text(
                            '"${t.text}"',
                            style: GoogleFonts.nunitoSans(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13, height: 1.8, fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(t.name, style: GoogleFonts.nunitoSans(
                            color: AppColors.goldLight, fontWeight: FontWeight.w700, fontSize: 14,
                          )),
                          Text(t.relation, style: GoogleFonts.nunitoSans(
                            color: Colors.white.withOpacity(0.5), fontSize: 12,
                          )),
                        ],
                      ),
                    ),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================
// EVENTS PREVIEW
// =============================================
class _EventsPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      backgroundColor: AppColors.creamDark,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: SectionTitle(title: 'Upcoming Events')),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(context, AppRouter.events),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('View All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: GoogleFonts.nunitoSans(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = Responsive.gridColumns(context).clamp(1, 3);
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: SchoolData.events.take(3).map((e) => SizedBox(
                  width: (constraints.maxWidth - (columns - 1) * 16) / columns,
                  child: AccentCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: AppColors.gold),
                            const SizedBox(width: 6),
                            Text(e.date, style: GoogleFonts.nunitoSans(
                              color: AppColors.gold, fontWeight: FontWeight.w600, fontSize: 12,
                            )),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              color: AppColors.goldPale,
                              child: Text(e.category, style: GoogleFonts.nunitoSans(
                                color: AppColors.navy, fontWeight: FontWeight.w600, fontSize: 11,
                              )),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(e.title, style: GoogleFonts.nunitoSans(
                          color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 15,
                        )),
                        const SizedBox(height: 6),
                        Text(e.description, style: GoogleFonts.nunitoSans(
                          color: AppColors.textSecondary, fontSize: 13, height: 1.5,
                        )),
                      ],
                    ),
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
