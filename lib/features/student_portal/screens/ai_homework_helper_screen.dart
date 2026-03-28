import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import 'ai_chat_screen.dart';

/// Landing page for AI Homework Helper — students pick a mode.
class AiHomeworkHelperScreen extends StatelessWidget {
  final String? homeworkId;
  final String? subject;
  final String? homeworkTitle;

  const AiHomeworkHelperScreen({
    super.key,
    this.homeworkId,
    this.subject,
    this.homeworkTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: Text('AI Homework Helper',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.smart_toy_outlined,
                        size: 48, color: AppColors.navy),
                  ),
                  const SizedBox(height: 12),
                  Text('How can I help you today?',
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy)),
                  const SizedBox(height: 4),
                  Text('Choose a mode to get started',
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),

            if (homeworkTitle != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF0D9488).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_outlined,
                        size: 18, color: Color(0xFF0D9488)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Homework: $homeworkTitle',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF0D9488))),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Mode cards
            _buildModeCard(
              context,
              mode: 'TUTOR',
              icon: Icons.school_outlined,
              color: const Color(0xFF0D9488),
              title: 'Tutor Mode',
              subtitle: 'Learn step by step',
              description:
                  "I'll guide you with questions and hints — without giving the answer directly. Best for understanding concepts!",
            ),
            const SizedBox(height: 12),
            _buildModeCard(
              context,
              mode: 'SOLVE',
              icon: Icons.lightbulb_outlined,
              color: const Color(0xFF2563EB),
              title: 'Solve Mode',
              subtitle: 'Get the full solution',
              description:
                  "I'll solve the problem step by step with clear explanations. Great when you need to understand the complete approach.",
            ),
            const SizedBox(height: 12),
            _buildModeCard(
              context,
              mode: 'PRACTICE',
              icon: Icons.fitness_center_outlined,
              color: const Color(0xFFD97706),
              title: 'Practice Mode',
              subtitle: 'Practice similar problems',
              description:
                  "Share a problem and I'll create similar practice questions. Perfect for exam preparation!",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required String mode,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String description,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AiChatScreen(
                mode: mode,
                homeworkId: homeworkId,
                subject: subject,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: color)),
                    Text(subtitle,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
