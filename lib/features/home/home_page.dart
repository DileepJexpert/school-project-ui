import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/public_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/school_image.dart';
import '../../models/school_data.dart';
import '../../core/constants/academic_year.dart';
import '../../models/admission_data.dart';
import '../../services/admission_api_service.dart';
import '../../core/widgets/searchable_dropdown.dart';

void _showQuickApplyDialog(BuildContext context) {
  final nameCtrl = TextEditingController();
  final parentCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  String? selectedClass = SchoolConstants.allClasses.contains('Class 1 - A')
      ? 'Class 1 - A'
      : SchoolConstants.allClasses.first;
  final formKey = GlobalKey<FormState>();
  bool submitting = false;
  bool submitted = false;
  String? error;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) {
        if (submitted) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Application Received!',
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.navy),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Thank you for applying to ${AppStrings.schoolName}. Our admissions team will review your application and reach out within 24 hours.',
                    style: GoogleFonts.nunitoSans(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          );
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.school_outlined, color: AppColors.gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Apply for Admission', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy)),
                    Text('Academic Year 2026–2027', style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
                      ),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: "Child's Full Name *", border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: parentCtrl,
                      decoration: const InputDecoration(labelText: 'Parent / Guardian Name *', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: phoneCtrl,
                            decoration: const InputDecoration(labelText: 'Phone Number *', border: OutlineInputBorder()),
                            keyboardType: TextInputType.phone,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: emailCtrl,
                            decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownFormField<String>(
                      labelText: 'Class of Interest *',
                      initialValue: selectedClass,
                      items: SchoolConstants.allClasses,
                      onChanged: (v) => setSt(() => selectedClass = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setSt(() {
                        submitting = true;
                        error = null;
                      });
                      try {
                        final student = Student(
                          fullName: nameCtrl.text.trim(),
                          dateOfBirth: DateTime(2018, 1, 1),
                          gender: 'OTHER',
                          bloodGroup: '',
                          nationality: 'Indian',
                          religion: '',
                          motherTongue: '',
                          aadharNumber: '',
                          classForAdmission: selectedClass ?? 'Class 1 - A',
                          academicYear: AcademicYear.currentLong(),
                          dateOfAdmission: DateTime.now(),
                          admissionNumber: '',
                          rollNumber: '',
                          status: 'ENQUIRY',
                          parentDetails: ParentDetails(
                            fatherName: parentCtrl.text.trim(),
                            fatherOccupation: '',
                            fatherMobile: phoneCtrl.text.trim(),
                            fatherEmail: emailCtrl.text.trim(),
                            motherName: '',
                            motherOccupation: '',
                            motherMobile: '',
                            motherEmail: '',
                          ),
                          contactDetails: ContactDetails(
                            permanentAddress: '',
                            correspondenceAddress: '',
                            primaryContactNumber: phoneCtrl.text.trim(),
                          ),
                          previousSchoolDetails: PreviousSchoolDetails(
                            schoolName: '',
                            lastClass: '',
                            board: '',
                          ),
                        );
                        await AdmissionApiService.submitEnquiry(student);
                        setSt(() {
                          submitting = false;
                          submitted = true;
                        });
                      } catch (e) {
                        setSt(() {
                          submitting = false;
                          error = 'Failed to submit application: $e';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Application'),
            ),
          ],
        );
      },
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: AppRouter.home,
      child: Column(
        children: [
          if (SchoolData.loadError != null)
            Container(
              width: double.infinity,
              color: PublicColors.goldPale,
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: Text(SchoolData.loadError!)),
                TextButton(
                  onPressed: () async {
                    await SchoolData.load();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, AppRouter.home);
                    }
                  },
                  child: const Text('Retry'),
                ),
              ]),
            ),
          _HeroSection(),
          if (SchoolData.stats.isNotEmpty) _StatsStrip(),
          if (SchoolData.principalMessage.isNotEmpty) _PrincipalSection(),
          if (SchoolData.achievements.isNotEmpty) _AchievementsSection(),
          if (SchoolData.testimonials.isNotEmpty) _TestimonialsSection(),
          if (SchoolData.events.isNotEmpty) _EventsPreview(),
          if (SchoolData.admissionCtaTitle.isNotEmpty)
            CtaBanner(
              title: SchoolData.admissionCtaTitle,
              subtitle: SchoolData.admissionCtaSubtitle,
              buttonText: 'Admissions',
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, AppRouter.admissions),
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
      decoration: const BoxDecoration(gradient: PublicColors.heroGradient),
      child: Stack(
        children: [
          // ── Real school photo as hero background ──────────────────────────
          // Place your school building / campus photo at:
          //   assets/images/home/hero_bg.jpg
          // It remains visible behind a light panel with readable text.
          if (SchoolData.heroBannerImagePath.isNotEmpty)
            Positioned.fill(
              child: SchoolImage(
                path: SchoolData.heroBannerImagePath,
                fallback: const SizedBox(),
              ),
            ),
          // A light wash lifts the campus photo without hiding it.
          Positioned.fill(
            child: Container(color: Colors.white.withValues(alpha: 0.18)),
          ),
          // Decorative circle
          if (!isMobile)
            Positioned(
              right: -80,
              top: 80,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: PublicColors.gold.withOpacity(0.08), width: 2),
                ),
              ),
            ),
          // Content
          ContentContainer(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.contentPadding(context),
              vertical: isMobile ? 48 : 80,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 660),
                padding: EdgeInsets.all(isMobile ? 26 : 42),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x330F3449),
                      blurRadius: 28,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Badge
                    if (AppStrings.accreditation.isNotEmpty ||
                        AppStrings.founded.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: PublicColors.goldPale,
                          border: Border.all(
                              color: PublicColors.gold.withOpacity(0.3)),
                        ),
                        child: Text(
                          [
                            AppStrings.accreditation,
                            if (AppStrings.founded.isNotEmpty)
                              'Est. ${AppStrings.founded}'
                          ].where((part) => part.isNotEmpty).join('  •  '),
                          style: GoogleFonts.nunitoSans(
                            color: PublicColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
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
                          color: PublicColors.navyDark,
                          fontSize: isMobile ? 36 : 52,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tagline
                    if (AppStrings.tagline.isNotEmpty)
                      SizedBox(
                        width: isMobile ? double.infinity : 520,
                        child: Text(
                          AppStrings.tagline,
                          style: GoogleFonts.nunitoSans(
                            color: PublicColors.textSecondary,
                            fontSize: 14,
                            height: 1.8,
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
                          onPressed: () => _showQuickApplyDialog(context),
                          icon: const Icon(Icons.edit_note_rounded, size: 20),
                          label: const Text('Apply Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PublicColors.navyDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: GoogleFonts.nunitoSans(fontSize: 15, fontWeight: FontWeight.w700),
                            elevation: 4,
                            shadowColor: const Color(0x33000000),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushReplacementNamed(
                              context, AppRouter.about),
                          icon: const Icon(Icons.explore_outlined, size: 18),
                          label: const Text('Discover More'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PublicColors.navyDark,
                            side: const BorderSide(
                                color: PublicColors.navy, width: 2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: ContentContainer(
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 24,
          runSpacing: 20,
          children: SchoolData.stats
              .map((stat) => Container(
                    width: isMobile ? 150 : 200,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06000000),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          stat.value,
                          style: GoogleFonts.poppins(
                            color: PublicColors.navyDark,
                            fontSize: isMobile ? 22 : 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stat.label.toUpperCase(),
                          style: GoogleFonts.nunitoSans(
                            color: PublicColors.gold,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
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
      backgroundColor: PublicColors.creamDark,
      child: isMobile
          ? Column(children: [
              _principalPhoto(context),
              const SizedBox(height: 32),
              _principalContent(context)
            ])
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
      decoration: const BoxDecoration(gradient: PublicColors.heroGradient),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        children: [
          // Principal photo — place image at: assets/images/home/principal.jpg
          CircleAvatar(
            radius: 54,
            backgroundColor: PublicColors.goldPale,
            backgroundImage:
                SchoolImage.provider(SchoolData.principalImagePath),
            onBackgroundImageError:
                SchoolData.principalImagePath.isEmpty ? null : (_, __) {},
            child: SchoolData.principalImagePath.isEmpty
                ? const Icon(Icons.person_outline, size: 52)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            SchoolData.principalName,
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            SchoolData.principalTitle,
            style: GoogleFonts.nunitoSans(
                color: PublicColors.goldLight, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _principalContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.format_quote,
            color: PublicColors.gold.withOpacity(0.4), size: 36),
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
            color: PublicColors.navy,
            fontWeight: FontWeight.w600,
            fontSize: 16,
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
      backgroundColor: PublicColors.white,
      child: Column(
        children: [
          const SectionTitle(
              title: 'Achievements & Recognition', centered: true),
          const SizedBox(height: 12),
          Text(
            'Our students and faculty consistently bring home honors across academics, sports, and creative disciplines.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
                color: PublicColors.textSecondary, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = Responsive.gridColumns(context);
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: SchoolData.achievements
                    .map((a) => SizedBox(
                          width: (constraints.maxWidth - (columns - 1) * 16) /
                              columns,
                          child: AccentCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.emoji_events,
                                        color: PublicColors.gold, size: 20),
                                    const SizedBox(width: 8),
                                    Text(a.year,
                                        style: GoogleFonts.nunitoSans(
                                          color: PublicColors.gold,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          letterSpacing: 0.5,
                                        )),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(a.title,
                                    style: GoogleFonts.nunitoSans(
                                      color: PublicColors.navy,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    )),
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

// =============================================
// TESTIMONIALS
// =============================================
class _TestimonialsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: PublicColors.heroGradient),
      padding: EdgeInsets.symmetric(vertical: isMobile ? 48 : 64),
      child: ContentContainer(
        child: Column(
          children: [
            SectionTitle(
                title: 'What Our Community Says',
                centered: true,
                color: Colors.white),
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = isMobile ? 1 : 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: SchoolData.testimonials
                      .map((t) => SizedBox(
                            width: (constraints.maxWidth - (columns - 1) * 16) /
                                columns,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                border: Border.all(
                                    color: PublicColors.gold.withOpacity(0.15)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.format_quote,
                                      color: PublicColors.gold.withOpacity(0.4),
                                      size: 24),
                                  const SizedBox(height: 8),
                                  Text(
                                    '"${t.text}"',
                                    style: GoogleFonts.nunitoSans(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 13,
                                      height: 1.8,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(t.name,
                                      style: GoogleFonts.nunitoSans(
                                        color: PublicColors.goldLight,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      )),
                                  Text(t.relation,
                                      style: GoogleFonts.nunitoSans(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 12,
                                      )),
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
      backgroundColor: PublicColors.creamDark,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: SectionTitle(title: 'Upcoming Events')),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, AppRouter.events),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('View All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PublicColors.navy,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: GoogleFonts.nunitoSans(
                      fontSize: 13, fontWeight: FontWeight.w600),
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
                children: SchoolData.events
                    .take(3)
                    .map((e) => SizedBox(
                          width: (constraints.maxWidth - (columns - 1) * 16) /
                              columns,
                          child: AccentCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        size: 14, color: PublicColors.gold),
                                    const SizedBox(width: 6),
                                    Text(e.date,
                                        style: GoogleFonts.nunitoSans(
                                          color: PublicColors.gold,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        )),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      color: PublicColors.goldPale,
                                      child: Text(e.category,
                                          style: GoogleFonts.nunitoSans(
                                            color: PublicColors.navy,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                          )),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(e.title,
                                    style: GoogleFonts.nunitoSans(
                                      color: PublicColors.navy,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    )),
                                const SizedBox(height: 6),
                                Text(e.description,
                                    style: GoogleFonts.nunitoSans(
                                      color: PublicColors.textSecondary,
                                      fontSize: 13,
                                      height: 1.5,
                                    )),
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
