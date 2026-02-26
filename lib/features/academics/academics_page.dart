import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/responsive.dart';
import '../../models/school_data.dart';

class AcademicsPage extends StatefulWidget {
  const AcademicsPage({super.key});

  @override
  State<AcademicsPage> createState() => _AcademicsPageState();
}

class _AcademicsPageState extends State<AcademicsPage> {
  int _selectedTab = 0;

  static const _tabIcons = [Icons.menu_book, Icons.school, Icons.emoji_events];

  @override
  Widget build(BuildContext context) {
    final level = SchoolData.academicLevels[_selectedTab];
    final isMobile = Responsive.isMobile(context);

    return AppShell(
      currentRoute: AppRouter.academics,
      child: Column(
        children: [
          const PageHeader(title: 'Academics', subtitle: 'A comprehensive curriculum for every stage of learning'),

          SectionWrapper(
            backgroundColor: AppColors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tabs
                Wrap(
                  spacing: 4,
                  runSpacing: 8,
                  children: List.generate(SchoolData.academicLevels.length, (i) {
                    final l = SchoolData.academicLevels[i];
                    final isActive = i == _selectedTab;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTab = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.navy : AppColors.cream,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_tabIcons[i], size: 18, color: isActive ? Colors.white : AppColors.navy),
                            const SizedBox(width: 8),
                            Text(l.title, style: GoogleFonts.nunitoSans(
                              color: isActive ? Colors.white : AppColors.navy,
                              fontWeight: FontWeight.w600, fontSize: 14,
                            )),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 36),

                // Content
                isMobile
                    ? Column(children: [_levelContent(level), const SizedBox(height: 32), _coCurriculars()])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: _levelContent(level)),
                          const SizedBox(width: 36),
                          Expanded(flex: 4, child: _coCurriculars()),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelContent(AcademicLevel level) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: level.grades),
        const SizedBox(height: 16),
        Text(level.focus, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        Text('Program Highlights', style: GoogleFonts.nunitoSans(
          color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 16,
        )),
        const SizedBox(height: 12),
        ...level.highlights.map((h) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle, color: AppColors.gold, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(h, style: GoogleFonts.nunitoSans(fontSize: 14, height: 1.5))),
            ],
          ),
        )),
      ],
    );
  }

  static const _coIconMap = {
    'science': Icons.science_rounded,
    'music': Icons.music_note_rounded,
    'sports': Icons.fitness_center_rounded,
    'art': Icons.palette_rounded,
    'globe': Icons.public_rounded,
    'book': Icons.menu_book_rounded,
  };

  Widget _coCurriculars() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cream,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Co-Curricular Activities', style: GoogleFonts.cormorantGaramond(
            color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: SchoolData.coCurriculars.map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_coIconMap[c.icon] ?? Icons.star, color: AppColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Text(c.name, style: GoogleFonts.nunitoSans(fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}
