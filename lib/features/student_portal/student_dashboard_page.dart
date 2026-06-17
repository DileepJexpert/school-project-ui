import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../services/auth_service.dart';
import '../../services/homework_api_service.dart';
import 'screens/ai_homework_helper_screen.dart';
import 'screens/exam_schedule_screen.dart';
import 'screens/my_books_screen.dart';
import 'screens/my_videos_screen.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<dynamic> _homeworkList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadHomework();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHomework() async {
    setState(() => _loading = true);
    try {
      final data = await HomeworkApiService.getMyHomework();
      if (mounted) setState(() => _homeworkList = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load homework: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AppRouter.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final userName = user?.fullName ?? 'Student';

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: Text('Student Portal',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.menu_book_outlined, size: 18), text: 'Homework'),
            Tab(icon: Icon(Icons.video_library_outlined, size: 18), text: 'Videos'),
            Tab(icon: Icon(Icons.local_library_outlined, size: 18), text: 'My Books'),
            Tab(icon: Icon(Icons.quiz_outlined, size: 18), text: 'Exams'),
            Tab(icon: Icon(Icons.smart_toy_outlined, size: 18), text: 'AI Helper'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Welcome header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome, $userName!',
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy)),
                const SizedBox(height: 2),
                Text('Your learning dashboard',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Homework
                _buildHomeworkTab(),
                // Tab 2: Videos
                const MyVideosScreen(),
                // Tab 3: My Books
                const MyBooksScreen(),
                // Tab 4: Exam Schedule
                const StudentExamScheduleScreen(),
                // Tab 5: AI Helper
                _buildAiHelperTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeworkTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_homeworkList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No homework assigned yet!',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('Enjoy your free time.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textLight)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadHomework,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _homeworkList.length,
        itemBuilder: (context, index) {
          final hw = _homeworkList[index] as Map<String, dynamic>;
          return _buildHomeworkCard(hw);
        },
      ),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> hw) {
    final title = hw['title'] as String? ?? '';
    final description = hw['description'] as String? ?? '';
    final subject = hw['subject'] as String? ?? '';
    final teacherName = hw['teacherName'] as String? ?? '';
    final dueDate = hw['dueDate'] as String? ?? '';
    final assignedDate = hw['assignedDate'] as String? ?? '';
    final homeworkId = hw['id'] as String?;

    final isDue = dueDate.isNotEmpty && DateTime.tryParse(dueDate) != null
        ? DateTime.parse(dueDate).isBefore(DateTime.now())
        : false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(subject,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0D9488))),
                ),
                const Spacer(),
                Icon(Icons.flag_outlined,
                    size: 16,
                    color: isDue ? Colors.red : Colors.orange),
                const SizedBox(width: 4),
                Text(isDue ? 'Overdue' : 'Due: $dueDate',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDue ? Colors.red : Colors.orange)),
              ],
            ),
            const SizedBox(height: 10),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(description,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(teacherName,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 16),
                Icon(Icons.calendar_today,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('Assigned: $assignedDate',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary)),
                const Spacer(),
                // Ask AI button
                Material(
                  color: AppColors.navy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AiHomeworkHelperScreen(
                            homeworkId: homeworkId,
                            subject: subject,
                            homeworkTitle: title,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.smart_toy_outlined,
                              size: 14, color: AppColors.navy),
                          const SizedBox(width: 4),
                          Text('Ask AI',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.navy)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiHelperTab() {
    return const AiHomeworkHelperScreen();
  }
}
