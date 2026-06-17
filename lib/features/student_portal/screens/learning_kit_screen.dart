import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import 'study_materials_screen.dart';
import 'quiz_screen.dart';
import 'learning_progress_screen.dart';

/// Wrapper screen with 3 sub-tabs: Materials, Quizzes, Progress.
/// Used as a single tab inside the student dashboard.
class LearningKitScreen extends StatefulWidget {
  const LearningKitScreen({super.key});

  @override
  State<LearningKitScreen> createState() => _LearningKitScreenState();
}

class _LearningKitScreenState extends State<LearningKitScreen>
    with SingleTickerProviderStateMixin {
  late TabController _subTabController;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-tab bar
        Container(
          color: AppColors.white,
          child: TabBar(
            controller: _subTabController,
            indicatorColor: AppColors.gold,
            indicatorWeight: 3,
            labelColor: AppColors.navy,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.auto_stories_outlined, size: 18),
                text: 'Materials',
              ),
              Tab(
                icon: Icon(Icons.quiz_outlined, size: 18),
                text: 'Quizzes',
              ),
              Tab(
                icon: Icon(Icons.insights_outlined, size: 18),
                text: 'Progress',
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        // Sub-tab content
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: const [
              StudentStudyMaterialsScreen(),
              StudentQuizScreen(),
              LearningProgressScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
