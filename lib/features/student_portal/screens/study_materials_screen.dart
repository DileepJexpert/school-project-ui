import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/study_material_api_service.dart';

class StudentStudyMaterialsScreen extends StatefulWidget {
  const StudentStudyMaterialsScreen({super.key});

  @override
  State<StudentStudyMaterialsScreen> createState() =>
      _StudentStudyMaterialsScreenState();
}

class _StudentStudyMaterialsScreenState
    extends State<StudentStudyMaterialsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _allMaterials = [];
  String _selectedSubject = 'All';

  static const List<String> _subjectFilters = [
    'All',
    'English',
    'Hindi',
    'Mathematics',
    'Science',
    'Social Studies',
    'Computer Science',
    'Sanskrit',
    'EVS',
    'General Knowledge',
  ];

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _loading = true);
    try {
      final data = await StudyMaterialApiService.getMyMaterials();
      if (mounted) setState(() => _allMaterials = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load study materials: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredMaterials {
    if (_selectedSubject == 'All') return _allMaterials;
    return _allMaterials
        .where((m) => m['subject'] == _selectedSubject)
        .toList();
  }

  /// Groups materials by subject and returns an ordered list of
  /// (subject, materials) pairs, respecting sortOrder within each group.
  List<(String, List<Map<String, dynamic>>)> get _groupedMaterials {
    final filtered = _filteredMaterials;
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final m in filtered) {
      final subject = m['subject'] as String? ?? 'Other';
      groups.putIfAbsent(subject, () => []).add(m);
    }
    // Sort each group by sortOrder
    for (final list in groups.values) {
      list.sort((a, b) {
        final sa = (a['sortOrder'] as num?)?.toInt() ?? 999;
        final sb = (b['sortOrder'] as num?)?.toInt() ?? 999;
        return sa.compareTo(sb);
      });
    }
    final entries = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => (e.key, e.value)).toList();
  }

  // ---- Material type helpers ----

  static IconData _typeIcon(String? type) {
    return switch (type) {
      'NOTES' => Icons.description,
      'PDF' => Icons.picture_as_pdf,
      'VIDEO_LINK' => Icons.play_circle_outline,
      'PRESENTATION' => Icons.slideshow,
      'REFERENCE' => Icons.link,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  static Color _typeColor(String? type) {
    return switch (type) {
      'NOTES' => const Color(0xFF3B82F6), // blue
      'PDF' => const Color(0xFFDC2626), // red
      'VIDEO_LINK' => const Color(0xFF7C3AED), // purple
      'PRESENTATION' => const Color(0xFFF97316), // orange
      'REFERENCE' => const Color(0xFF6B7280), // grey
      _ => const Color(0xFF6B7280),
    };
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSubjectFilterBar(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  // ---- Subject filter chips ----

  Widget _buildSubjectFilterBar() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingMD,
          vertical: AppSizes.paddingSM,
        ),
        itemCount: _subjectFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final subject = _subjectFilters[index];
          final selected = _selectedSubject == subject;
          return FilterChip(
            label: Text(
              subject,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.white : AppColors.textSecondary,
              ),
            ),
            selected: selected,
            onSelected: (_) {
              setState(() => _selectedSubject = subject);
            },
            selectedColor: AppColors.gold,
            backgroundColor: AppColors.white,
            side: BorderSide(
              color: selected ? AppColors.gold : AppColors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }

  // ---- Body: loading / empty / list ----

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final groups = _groupedMaterials;

    if (groups.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadMaterials,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.paddingMD,
          0,
          AppSizes.paddingMD,
          AppSizes.paddingLG,
        ),
        itemCount: _itemCount(groups),
        itemBuilder: (context, index) => _buildListItem(groups, index),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'No study materials available yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your teachers will upload materials here.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Flat list with interleaved subject headers ----

  int _itemCount(List<(String, List<Map<String, dynamic>>)> groups) {
    // Each group has 1 header + n cards.
    int count = 0;
    for (final (_, items) in groups) {
      count += 1 + items.length;
    }
    return count;
  }

  Widget _buildListItem(
      List<(String, List<Map<String, dynamic>>)> groups, int index) {
    int cursor = 0;
    for (final (subject, items) in groups) {
      if (index == cursor) {
        return _buildSubjectHeader(subject);
      }
      cursor++;
      final localIndex = index - cursor;
      if (localIndex < items.length) {
        return _buildMaterialCard(items[localIndex]);
      }
      cursor += items.length;
    }
    return const SizedBox.shrink();
  }

  Widget _buildSubjectHeader(String subject) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        subject,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
    );
  }

  // ---- Material card ----

  Widget _buildMaterialCard(Map<String, dynamic> material) {
    final title = material['title'] as String? ?? '';
    final description = material['description'] as String? ?? '';
    final materialType = material['materialType'] as String? ?? '';
    final chapter = material['chapter'] as String?;
    final contentUrl = material['contentUrl'] as String?;
    final color = _typeColor(materialType);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        onTap: () => _onMaterialTap(contentUrl, title),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type icon avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(_typeIcon(materialType), size: 22, color: color),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    if (chapter != null && chapter.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildChapterChip(chapter),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textLight,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChapterChip(String chapter) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.goldPale,
        borderRadius: BorderRadius.circular(AppSizes.radiusSM),
      ),
      child: Text(
        chapter,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.gold,
        ),
      ),
    );
  }

  // ---- Tap action ----

  void _onMaterialTap(String? url, String title) {
    if (url != null && url.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening: $url'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No link available for "$title"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
