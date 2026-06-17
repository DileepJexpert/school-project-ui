import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/notice_api_service.dart';

class StudentNoticeScreen extends StatefulWidget {
  const StudentNoticeScreen({super.key});

  @override
  State<StudentNoticeScreen> createState() => _StudentNoticeScreenState();
}

class _StudentNoticeScreenState extends State<StudentNoticeScreen> {
  bool _loading = true;
  List<dynamic> _notices = [];
  String _selectedCategory = 'ALL';

  static const _categories = [
    'ALL',
    'GENERAL',
    'ACADEMIC',
    'EXAM',
    'FEE',
    'EVENT',
    'HOLIDAY',
    'URGENT',
  ];

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() => _loading = true);
    try {
      final data = await NoticeApiService.getStudentNotices();
      if (mounted) setState(() => _notices = data);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<dynamic> get _filteredNotices {
    if (_selectedCategory == 'ALL') return _notices;
    return _notices
        .where((n) =>
            (n as Map<String, dynamic>)['category'] == _selectedCategory)
        .toList();
  }

  Color _categoryColor(String category) {
    return switch (category) {
      'GENERAL' => Colors.blue,
      'ACADEMIC' => Colors.teal,
      'EXAM' => Colors.purple,
      'FEE' => Colors.green,
      'EVENT' => Colors.orange,
      'HOLIDAY' => Colors.red,
      'URGENT' => Colors.red,
      _ => Colors.grey,
    };
  }

  Color _priorityColor(String priority) {
    return switch (priority) {
      'HIGH' => Colors.orange,
      'URGENT' => Colors.red,
      _ => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final filtered = _filteredNotices;

    return RefreshIndicator(
      onRefresh: _loadNotices,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.paddingMD),
        children: [
          // Category filter chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary)),
                  selected: selected,
                  selectedColor: AppColors.navy,
                  backgroundColor: AppColors.creamDark,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Notice cards or empty state
          if (filtered.isEmpty)
            _buildEmptyState()
          else
            ...filtered
                .map((n) => _buildNoticeCard(n as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.campaign_outlined,
                size: 56, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text('No notices available',
                style: GoogleFonts.poppins(
                    fontSize: 16, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('Check back later for updates.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> notice) {
    final title = notice['title'] as String? ?? 'Untitled';
    final content = notice['content'] as String? ?? '';
    final category = notice['category'] as String? ?? 'GENERAL';
    final priority = notice['priority'] as String? ?? 'MEDIUM';
    final isPinned = notice['isPinned'] as bool? ?? false;
    final createdAt = notice['createdAt'] as String? ?? '';
    final isNew = notice['isNew'] as bool? ?? false;

    String formattedDate = '';
    if (createdAt.isNotEmpty) {
      try {
        formattedDate =
            DateFormat('dd MMM yyyy').format(DateTime.parse(createdAt));
      } catch (_) {
        formattedDate = createdAt;
      }
    }

    final showPriority = priority == 'HIGH' || priority == 'URGENT';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
          border: isPinned
              ? Border(
                  left: BorderSide(color: AppColors.gold, width: 4),
                )
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with badges
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy)),
                ),
                if (isNew) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusSM),
                    ),
                    child: Text('New',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Full content
            Text(content,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5)),
            const SizedBox(height: 12),

            // Bottom info row
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Category chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _categoryColor(category).withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusSM),
                    border: Border.all(
                        color: _categoryColor(category).withOpacity(0.4)),
                  ),
                  child: Text(category,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _categoryColor(category))),
                ),

                // Priority badge (HIGH/URGENT only)
                if (showPriority)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _priorityColor(priority),
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusSM),
                    ),
                    child: Text(priority,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),

                // Date
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_outlined,
                        size: 14, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Text(formattedDate,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
