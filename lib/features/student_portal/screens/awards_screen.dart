import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/award_api_service.dart';

class StudentAwardsScreen extends StatefulWidget {
  const StudentAwardsScreen({super.key});

  @override
  State<StudentAwardsScreen> createState() => _StudentAwardsScreenState();
}

class _StudentAwardsScreenState extends State<StudentAwardsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _awards = [];
  String _filterCategory = 'ALL';

  static const List<String> _categories = [
    'ALL',
    'ACADEMIC',
    'SPORTS',
    'ARTS',
    'SCIENCE',
    'CULTURAL',
    'LEADERSHIP',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    _loadAwards();
  }

  Future<void> _loadAwards() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await AwardApiService.getMyAwards();
      if (mounted) {
        setState(() {
          _awards =
              raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load awards: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredAwards {
    if (_filterCategory == 'ALL') return _awards;
    return _awards.where((a) => a['category'] == _filterCategory).toList();
  }

  // ─── Visual helpers ───

  Color _categoryColor(String? category) {
    switch (category) {
      case 'ACADEMIC':
        return Colors.blue;
      case 'SPORTS':
        return Colors.green;
      case 'ARTS':
        return Colors.purple;
      case 'SCIENCE':
        return Colors.teal;
      case 'CULTURAL':
        return Colors.orange;
      case 'LEADERSHIP':
        return AppColors.navy;
      case 'OTHER':
        return Colors.grey;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _levelColor(String? level) {
    switch (level) {
      case 'SCHOOL':
        return Colors.grey;
      case 'DISTRICT':
        return Colors.blue;
      case 'STATE':
        return Colors.orange;
      case 'NATIONAL':
        return AppColors.gold;
      case 'INTERNATIONAL':
        return Colors.purple;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _trophyIcon(String? position) {
    switch (position) {
      case '1st':
      case '2nd':
      case '3rd':
        return Icons.emoji_events;
      default:
        return Icons.star;
    }
  }

  Color _trophyColor(String? position) {
    switch (position) {
      case '1st':
        return const Color(0xFFFFD700);
      case '2nd':
        return const Color(0xFFC0C0C0);
      case '3rd':
        return const Color(0xFFCD7F32);
      default:
        return AppColors.gold;
    }
  }

  Color _positionBgColor(String? position) {
    switch (position) {
      case '1st':
        return const Color(0xFFFFD700);
      case '2nd':
        return const Color(0xFFC0C0C0);
      case '3rd':
        return const Color(0xFFCD7F32);
      default:
        return AppColors.creamDark;
    }
  }

  Color _positionFgColor(String? position) {
    switch (position) {
      case '1st':
        return const Color(0xFF5C4A00);
      case '2nd':
        return const Color(0xFF3A3A3A);
      case '3rd':
        return Colors.white;
      default:
        return AppColors.textPrimary;
    }
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: Text(_error!, style: GoogleFonts.poppins(color: Colors.red)));
    }

    final filtered = _filteredAwards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.goldPale,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                ),
                child: const Icon(Icons.emoji_events,
                    color: AppColors.gold, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('My Awards & Achievements',
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                ),
                child: Text('${_awards.length}',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold)),
              ),
            ],
          ),
        ),

        // Category filter chips
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _filterCategory == cat;
              return ChoiceChip(
                label: Text(cat == 'ALL' ? 'All' : cat,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary)),
                selected: isSelected,
                selectedColor: cat == 'ALL'
                    ? AppColors.navy
                    : _categoryColor(cat),
                backgroundColor: AppColors.creamDark,
                onSelected: (_) =>
                    setState(() => _filterCategory = cat),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Awards list or empty state
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No awards yet',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text('Keep working hard!',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.textLight)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAwards,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildAwardCard(filtered[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAwardCard(Map<String, dynamic> award) {
    final title = award['title'] as String? ?? '';
    final desc = award['description'] as String? ?? '';
    final category = award['category'] as String? ?? '';
    final level = award['level'] as String? ?? '';
    final position = award['position'] as String?;
    final awardedBy = award['awardedBy'] as String? ?? '';
    final dateStr = award['dateAwarded'] as String?;
    final formattedDate = dateStr != null
        ? DateFormat('dd MMM yyyy')
            .format(DateTime.tryParse(dateStr) ?? DateTime.now())
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large trophy / medal icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _trophyColor(position).withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
              child: Icon(
                _trophyIcon(position),
                color: _trophyColor(position),
                size: 34,
              ),
            ),
            const SizedBox(width: 16),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy)),
                  const SizedBox(height: 8),

                  // Category + Level badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _categoryColor(category)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(
                                AppSizes.radiusSM),
                          ),
                          child: Text(category,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _categoryColor(category))),
                        ),
                      if (level.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _levelColor(level).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(
                                AppSizes.radiusSM),
                            border: (level == 'NATIONAL' ||
                                    level == 'INTERNATIONAL')
                                ? Border.all(
                                    color: _levelColor(level)
                                        .withOpacity(0.4),
                                    width: 1)
                                : null,
                          ),
                          child: Text(level,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: (level == 'NATIONAL' ||
                                          level == 'INTERNATIONAL')
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _levelColor(level))),
                        ),
                    ],
                  ),

                  // Position (prominent)
                  if (position != null && position.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: _positionBgColor(position),
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusSM),
                      ),
                      child: Text(position,
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _positionFgColor(position))),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Date + awarded by
                  Row(
                    children: [
                      if (formattedDate.isNotEmpty) ...[
                        Icon(Icons.calendar_today,
                            size: 12, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Text(formattedDate,
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textLight)),
                      ],
                      if (awardedBy.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.verified_outlined,
                            size: 12, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(awardedBy,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textLight)),
                        ),
                      ],
                    ],
                  ),

                  // Description (if present)
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(desc,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
