import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/award_api_service.dart';

class AwardsScreen extends StatefulWidget {
  const AwardsScreen({super.key});

  @override
  State<AwardsScreen> createState() => _AwardsScreenState();
}

class _AwardsScreenState extends State<AwardsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<Map<String, dynamic>> _awards = [];
  Map<String, dynamic>? _stats;

  String? _filterClass;
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

  static const List<String> _levels = [
    'SCHOOL',
    'DISTRICT',
    'STATE',
    'NATIONAL',
    'INTERNATIONAL',
  ];

  static const List<String> _positions = [
    '1st',
    '2nd',
    '3rd',
    'Participation',
    'Merit',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final futures = await Future.wait([
        AwardApiService.getAllAwards(),
        AwardApiService.getStats(),
      ]);
      final rawAwards = futures[0] as List<dynamic>;
      final stats = futures[1] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _awards = rawAwards
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _stats = stats;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load awards: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  // ─── Category colors ───

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

  // ─── Level colors & emphasis ───

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

  double _levelFontSize(String? level) {
    switch (level) {
      case 'NATIONAL':
        return 12;
      case 'INTERNATIONAL':
        return 13;
      default:
        return 11;
    }
  }

  FontWeight _levelFontWeight(String? level) {
    switch (level) {
      case 'NATIONAL':
      case 'INTERNATIONAL':
        return FontWeight.w700;
      case 'STATE':
        return FontWeight.w600;
      default:
        return FontWeight.w500;
    }
  }

  // ─── Position visuals ───

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

  // ─── Filtered awards ───

  List<Map<String, dynamic>> get _filteredAwards {
    var list = _awards;
    if (_filterClass != null && _filterClass!.isNotEmpty) {
      list = list.where((a) => a['className'] == _filterClass).toList();
    }
    if (_filterCategory != 'ALL') {
      list = list.where((a) => a['category'] == _filterCategory).toList();
    }
    return list;
  }

  // ─── Delete ───

  Future<void> _confirmDelete(Map<String, dynamic> award) async {
    final title = award['title'] as String? ?? '';
    final id = award['id'] as String? ?? award['_id'] as String? ?? '';
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Award',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to delete "$title"? This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AwardApiService.delete(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Award deleted successfully')),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete award: $e')),
          );
        }
      }
    }
  }

  // ─── Add / Edit Dialog ───

  void _showFormDialog(Map<String, dynamic>? existing) {
    final isEdit = existing != null;

    final studentIdCtrl = TextEditingController(
        text: existing?['studentId'] as String? ?? '');
    final studentNameCtrl = TextEditingController(
        text: existing?['studentName'] as String? ?? '');
    final titleCtrl = TextEditingController(
        text: existing?['title'] as String? ?? '');
    final descCtrl = TextEditingController(
        text: existing?['description'] as String? ?? '');
    final awardedByCtrl = TextEditingController(
        text: existing?['awardedBy'] as String? ?? '');
    final certUrlCtrl = TextEditingController(
        text: existing?['certificateUrl'] as String? ?? '');
    final academicYearCtrl = TextEditingController(
        text: existing?['academicYear'] as String? ?? '2024-25');

    String? selectedClass = existing?['className'] as String?;
    String selectedCategory =
        existing?['category'] as String? ?? 'ACADEMIC';
    String selectedLevel = existing?['level'] as String? ?? 'SCHOOL';
    String? selectedPosition = existing?['position'] as String?;
    DateTime selectedDate = existing?['dateAwarded'] != null
        ? DateTime.tryParse(existing!['dateAwarded'].toString()) ??
            DateTime.now()
        : DateTime.now();

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setDialogState(() => selectedDate = picked);
              }
            }

            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              if (selectedClass == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please select a class')),
                );
                return;
              }

              final data = <String, dynamic>{
                'studentId': studentIdCtrl.text.trim(),
                'studentName': studentNameCtrl.text.trim(),
                'className': selectedClass,
                'title': titleCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'category': selectedCategory,
                'level': selectedLevel,
                'position': selectedPosition,
                'dateAwarded': selectedDate.toIso8601String(),
                'awardedBy': awardedByCtrl.text.trim(),
                'certificateUrl': certUrlCtrl.text.trim(),
                'academicYear': academicYearCtrl.text.trim(),
              };

              try {
                if (isEdit) {
                  final id = existing['id'] as String? ??
                      existing['_id'] as String? ??
                      '';
                  await AwardApiService.update(id, data);
                } else {
                  await AwardApiService.create(data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit
                          ? 'Award updated successfully'
                          : 'Award created successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            }

            return AlertDialog(
              title: Text(
                isEdit ? 'Edit Award' : 'Add Award',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, color: AppColors.navy),
              ),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Student ID
                        TextFormField(
                          controller: studentIdCtrl,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Student ID *',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Student ID is required'
                              : null,
                        ),
                        const SizedBox(height: 12),

                        // Student Name
                        TextFormField(
                          controller: studentNameCtrl,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Student Name *',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Student name is required'
                              : null,
                        ),
                        const SizedBox(height: 12),

                        // Class dropdown
                        DropdownButtonFormField<String>(
                          value: selectedClass != null &&
                                  SchoolConstants.baseClasses
                                      .contains(selectedClass)
                              ? selectedClass
                              : null,
                          decoration: InputDecoration(
                            labelText: 'Class *',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            border: const OutlineInputBorder(),
                          ),
                          isExpanded: true,
                          items: SchoolConstants.baseClasses
                              .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c,
                                      style: GoogleFonts.poppins(
                                          fontSize: 13))))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedClass = v),
                          validator: (v) =>
                              v == null ? 'Class is required' : null,
                        ),
                        const SizedBox(height: 12),

                        // Title
                        TextFormField(
                          controller: titleCtrl,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Title *',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            hintText: 'e.g. Science Olympiad Winner',
                            hintStyle: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.textLight),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Title is required'
                              : null,
                        ),
                        const SizedBox(height: 12),

                        // Description
                        TextFormField(
                          controller: descCtrl,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Description',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),

                        // Category dropdown
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Category *',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            border: const OutlineInputBorder(),
                          ),
                          isExpanded: true,
                          items: _categories
                              .where((c) => c != 'ALL')
                              .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c,
                                      style: GoogleFonts.poppins(
                                          fontSize: 13))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedCategory = v);
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        // Level dropdown
                        DropdownButtonFormField<String>(
                          value: selectedLevel,
                          decoration: InputDecoration(
                            labelText: 'Level *',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            border: const OutlineInputBorder(),
                          ),
                          isExpanded: true,
                          items: _levels
                              .map((l) => DropdownMenuItem(
                                  value: l,
                                  child: Text(l,
                                      style: GoogleFonts.poppins(
                                          fontSize: 13))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedLevel = v);
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        // Position dropdown
                        DropdownButtonFormField<String>(
                          value: selectedPosition,
                          decoration: InputDecoration(
                            labelText: 'Position',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            border: const OutlineInputBorder(),
                          ),
                          isExpanded: true,
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text('None',
                                  style: GoogleFonts.poppins(fontSize: 13)),
                            ),
                            ..._positions.map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p,
                                    style: GoogleFonts.poppins(
                                        fontSize: 13)))),
                          ],
                          onChanged: (v) =>
                              setDialogState(() => selectedPosition = v),
                        ),
                        const SizedBox(height: 12),

                        // Date Awarded
                        InkWell(
                          onTap: pickDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Date Awarded',
                              labelStyle: GoogleFonts.poppins(fontSize: 13),
                              border: const OutlineInputBorder(),
                              suffixIcon: const Icon(
                                  Icons.calendar_today,
                                  size: 18),
                            ),
                            child: Text(
                              DateFormat('dd MMM yyyy')
                                  .format(selectedDate),
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Awarded By
                        TextFormField(
                          controller: awardedByCtrl,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Awarded By',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            hintText: 'e.g. CBSE Board',
                            hintStyle: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.textLight),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Certificate URL
                        TextFormField(
                          controller: certUrlCtrl,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Certificate URL (optional)',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Academic Year
                        TextFormField(
                          controller: academicYearCtrl,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Academic Year',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.navy,
                  ),
                  onPressed: submit,
                  child: Text(isEdit ? 'Update' : 'Create',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          color: AppColors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.navy,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.gold,
            indicatorWeight: 3,
            labelStyle:
                GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
            tabs: const [
              Tab(text: 'Awards List'),
              Tab(text: 'Dashboard'),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAwardsListTab(),
                    _buildDashboardTab(),
                  ],
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 1: Awards List
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAwardsListTab() {
    final filtered = _filteredAwards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filters + Add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Student Awards & Achievements',
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Class filter
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      value: _filterClass,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: 'All Classes',
                        hintStyle: GoogleFonts.poppins(fontSize: 13),
                        prefixIcon:
                            const Icon(Icons.filter_list, size: 18),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                AppSizes.radiusMD)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Classes',
                              style: GoogleFonts.poppins(fontSize: 13)),
                        ),
                        ...SchoolConstants.baseClasses.map((c) =>
                            DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    style: GoogleFonts.poppins(
                                        fontSize: 13)))),
                      ],
                      onChanged: (v) {
                        setState(() => _filterClass = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Category filter
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      value: _filterCategory,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: 'All Categories',
                        hintStyle: GoogleFonts.poppins(fontSize: 13),
                        prefixIcon:
                            const Icon(Icons.category, size: 18),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                AppSizes.radiusMD)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      items: _categories
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c == 'ALL' ? 'All Categories' : c,
                                  style:
                                      GoogleFonts.poppins(fontSize: 13))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _filterCategory = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Add Award button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    onPressed: () => _showFormDialog(null),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('Add Award',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Awards list
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_outlined,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No awards found.',
                          style: GoogleFonts.poppins(
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "Add Award" to record a student achievement.',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textLight),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
    final studentName = award['studentName'] as String? ?? 'Unknown';
    final className = award['className'] as String? ?? '';
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
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        side: BorderSide(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trophy icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _trophyColor(position).withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
              child: Icon(
                _trophyIcon(position),
                color: _trophyColor(position),
                size: 28,
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy)),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 8),

                  // Student + class
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(studentName,
                          style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: AppColors.textPrimary)),
                      if (className.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.creamDark,
                            borderRadius: BorderRadius.circular(
                                AppSizes.radiusSM),
                          ),
                          child: Text(className,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Category + Level + Position badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Category chip
                      if (category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                _categoryColor(category).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(
                                AppSizes.radiusSM),
                          ),
                          child: Text(category,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _categoryColor(category))),
                        ),

                      // Level badge
                      if (level.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                _levelColor(level).withOpacity(0.15),
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
                                  fontSize: _levelFontSize(level),
                                  fontWeight: _levelFontWeight(level),
                                  color: _levelColor(level))),
                        ),

                      // Position badge
                      if (position != null && position.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _positionBgColor(position),
                            borderRadius: BorderRadius.circular(
                                AppSizes.radiusSM),
                          ),
                          child: Text(position,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _positionFgColor(position))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Date + Awarded by
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
                        Text(awardedBy,
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textLight)),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.navy),
                  tooltip: 'Edit',
                  onPressed: () => _showFormDialog(award),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: AppColors.error),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDelete(award),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 2: Dashboard
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDashboardTab() {
    final totalAwards = _stats?['totalAwards'] as int? ?? _awards.length;
    final categoryBreakdown =
        _stats?['categoryBreakdown'] as Map<String, dynamic>? ?? {};
    final levelBreakdown =
        _stats?['levelBreakdown'] as Map<String, dynamic>? ?? {};
    final topStudents =
        (_stats?['topStudents'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Awards
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events,
                    size: 40, color: Color(0xFFFFD700)),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Awards',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70)),
                    Text('$totalAwards',
                        style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Category Breakdown
          Text('Awards by Category',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: categoryBreakdown.entries.map((e) {
              final cat = e.key;
              final count = e.value as int? ?? 0;
              return _buildStatTile(cat, count, _categoryColor(cat));
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Level Breakdown
          Text('Awards by Level',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: levelBreakdown.entries.map((e) {
              final lvl = e.key;
              final count = e.value as int? ?? 0;
              return _buildStatTile(lvl, count, _levelColor(lvl));
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Top Students
          Text('Top Students',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 12),
          if (topStudents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No data available.',
                  style: GoogleFonts.poppins(
                      color: AppColors.textSecondary)),
            )
          else
            ...topStudents.take(5).map((s) {
              final student = Map<String, dynamic>.from(s as Map);
              final name =
                  student['studentName'] as String? ?? 'Unknown';
              final cls = student['className'] as String? ?? '';
              final count = student['awardCount'] as int? ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusMD),
                  border: Border.all(
                      color: AppColors.border.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events,
                        size: 20, color: AppColors.gold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          if (cls.isNotEmpty)
                            Text(cls,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.goldPale,
                        borderRadius: BorderRadius.circular(
                            AppSizes.radiusSM),
                      ),
                      child: Text('$count',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, int count, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color)),
          const SizedBox(height: 4),
          Text('$count',
              style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}
