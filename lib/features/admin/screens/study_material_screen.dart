import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/study_material_api_service.dart';

class StudyMaterialScreen extends StatefulWidget {
  const StudyMaterialScreen({super.key});

  @override
  State<StudyMaterialScreen> createState() => _StudyMaterialScreenState();
}

class _StudyMaterialScreenState extends State<StudyMaterialScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _materials = [];
  String? _filterClass;
  String? _filterSubject;

  static const List<String> _allSubjects = [
    ...SchoolConstants.commonSubjects,
    'Physics',
    'Chemistry',
    'Biology',
    'History',
    'Geography',
    'Economics',
  ];

  static const List<String> _materialTypes = [
    'NOTES',
    'PDF',
    'VIDEO_LINK',
    'PRESENTATION',
    'REFERENCE',
  ];

  static const Map<String, String> _materialTypeLabels = {
    'NOTES': 'Notes',
    'PDF': 'PDF',
    'VIDEO_LINK': 'Video Link',
    'PRESENTATION': 'Presentation',
    'REFERENCE': 'Reference',
  };

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _loading = true);
    try {
      List<Map<String, dynamic>> data;
      if (_filterClass != null && _filterClass!.isNotEmpty) {
        data = await StudyMaterialApiService.getMaterialsByClass(_filterClass!);
      } else {
        data = await StudyMaterialApiService.getAllMaterials();
      }
      // Apply subject filter locally if set
      if (_filterSubject != null && _filterSubject!.isNotEmpty) {
        data = data
            .where((m) =>
                (m['subject'] as String?)?.toLowerCase() ==
                _filterSubject!.toLowerCase())
            .toList();
      }
      if (mounted) setState(() => _materials = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load study materials: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  // ─── Material type visuals ───

  IconData _materialTypeIcon(String? type) {
    switch (type) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'NOTES':
        return Icons.note_alt_outlined;
      case 'VIDEO_LINK':
        return Icons.play_circle_outline;
      case 'PRESENTATION':
        return Icons.slideshow;
      case 'REFERENCE':
        return Icons.link;
      default:
        return Icons.description_outlined;
    }
  }

  Color _materialTypeColor(String? type) {
    switch (type) {
      case 'PDF':
        return Colors.red;
      case 'NOTES':
        return Colors.blue;
      case 'VIDEO_LINK':
        return Colors.purple;
      case 'PRESENTATION':
        return Colors.orange;
      case 'REFERENCE':
        return Colors.grey;
      default:
        return AppColors.textSecondary;
    }
  }

  // ─── Group materials by subject ───

  Map<String, List<Map<String, dynamic>>> _groupBySubject() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final m in _materials) {
      final subject = m['subject'] as String? ?? 'Unknown';
      grouped.putIfAbsent(subject, () => []).add(m);
    }
    // Sort subjects alphabetically
    final sorted = Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return sorted;
  }

  // ─── Delete ───

  Future<void> _confirmDelete(Map<String, dynamic> material) async {
    final title = material['title'] as String? ?? '';
    final id = material['id'] as String? ?? '';
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Material',
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
        await StudyMaterialApiService.deleteMaterial(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Material deleted successfully')),
          );
        }
        _loadMaterials();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete material: $e')),
          );
        }
      }
    }
  }

  // ─── Add / Edit Dialog ───

  void _showFormDialog(Map<String, dynamic>? existing) {
    final isEdit = existing != null;

    final titleCtrl = TextEditingController(
        text: existing?['title'] as String? ?? '');
    final chapterCtrl = TextEditingController(
        text: existing?['chapter'] as String? ?? '');
    final contentUrlCtrl = TextEditingController(
        text: existing?['contentUrl'] as String? ?? '');
    final descCtrl = TextEditingController(
        text: existing?['description'] as String? ?? '');
    final sortOrderCtrl = TextEditingController(
        text: '${existing?['sortOrder'] ?? 0}');

    String? selectedSubject = existing?['subject'] as String?;
    String? selectedClass = existing?['className'] as String?;
    String selectedType =
        existing?['materialType'] as String? ?? 'NOTES';
    bool published = existing?['published'] as bool? ?? true;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              if (selectedSubject == null || selectedClass == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please fill all required fields')),
                );
                return;
              }

              final data = <String, dynamic>{
                'title': titleCtrl.text.trim(),
                'subject': selectedSubject,
                'className': selectedClass,
                'materialType': selectedType,
                'chapter': chapterCtrl.text.trim(),
                'contentUrl': contentUrlCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'published': published,
                'sortOrder':
                    int.tryParse(sortOrderCtrl.text.trim()) ?? 0,
              };

              try {
                if (isEdit) {
                  final id = existing['id'] as String? ?? '';
                  await StudyMaterialApiService.updateMaterial(id, data);
                } else {
                  await StudyMaterialApiService.createMaterial(data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadMaterials();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit
                          ? 'Material updated successfully'
                          : 'Material created successfully'),
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
                isEdit ? 'Edit Study Material' : 'Add Study Material',
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
                        // Title
                        TextFormField(
                          controller: titleCtrl,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Title *',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Title is required'
                                  : null,
                        ),
                        const SizedBox(height: 12),

                        // Subject dropdown
                        DropdownButtonFormField<String>(
                          value: selectedSubject != null &&
                                  _allSubjects.contains(selectedSubject)
                              ? selectedSubject
                              : null,
                          decoration: InputDecoration(
                            labelText: 'Subject *',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            border: const OutlineInputBorder(),
                          ),
                          isExpanded: true,
                          items: _allSubjects
                              .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s,
                                      style: GoogleFonts.poppins(
                                          fontSize: 13))))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedSubject = v),
                          validator: (v) =>
                              v == null ? 'Subject is required' : null,
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

                        // Material Type dropdown
                        DropdownButtonFormField<String>(
                          value: selectedType,
                          decoration: InputDecoration(
                            labelText: 'Material Type',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            border: const OutlineInputBorder(),
                          ),
                          isExpanded: true,
                          items: _materialTypes
                              .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                      _materialTypeLabels[t] ?? t,
                                      style: GoogleFonts.poppins(
                                          fontSize: 13))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedType = v);
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        // Chapter (optional)
                        TextFormField(
                          controller: chapterCtrl,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Chapter (optional)',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Content URL
                        TextFormField(
                          controller: contentUrlCtrl,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Content URL',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            hintText:
                                'Link to video, PDF, or external resource',
                            hintStyle: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textLight),
                            border: const OutlineInputBorder(),
                          ),
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

                        // Published toggle
                        Row(
                          children: [
                            Text('Published',
                                style: GoogleFonts.poppins(fontSize: 14)),
                            const Spacer(),
                            Switch(
                              value: published,
                              activeColor: AppColors.success,
                              onChanged: (v) =>
                                  setDialogState(() => published = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Sort Order
                        TextFormField(
                          controller: sortOrderCtrl,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Sort Order',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Header: Title + Filters + Add Button ---
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Study Materials',
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
                        _loadMaterials();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Subject filter
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      value: _filterSubject,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: 'All Subjects',
                        hintStyle: GoogleFonts.poppins(fontSize: 13),
                        prefixIcon:
                            const Icon(Icons.subject, size: 18),
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
                          child: Text('All Subjects',
                              style: GoogleFonts.poppins(fontSize: 13)),
                        ),
                        ..._allSubjects.map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s,
                                style:
                                    GoogleFonts.poppins(fontSize: 13)))),
                      ],
                      onChanged: (v) {
                        setState(() => _filterSubject = v);
                        _loadMaterials();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Add Material button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    onPressed: () => _showFormDialog(null),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('Add Material',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // --- Material list ---
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _materials.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('No study materials found.',
                              style: GoogleFonts.poppins(
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Add Material" to upload your first study resource.',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textLight),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadMaterials,
                      child: _buildGroupedList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildGroupedList() {
    final grouped = _groupBySubject();
    final subjectKeys = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: subjectKeys.length,
      itemBuilder: (context, sIndex) {
        final subject = subjectKeys[sIndex];
        final items = grouped[subject]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sIndex > 0) const SizedBox(height: 8),
            // Subject group header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusSM),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(subject,
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.goldPale,
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusSM),
                    ),
                    child: Text('${items.length}',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gold)),
                  ),
                ],
              ),
            ),
            // Material cards for this subject
            ...items.map((m) => _buildMaterialCard(m)),
          ],
        );
      },
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> m) {
    final title = m['title'] as String? ?? '';
    final subject = m['subject'] as String? ?? '';
    final className = m['className'] as String? ?? '';
    final materialType = m['materialType'] as String? ?? 'NOTES';
    final chapter = m['chapter'] as String? ?? '';
    final description = m['description'] as String? ?? '';
    final published = m['published'] as bool? ?? true;

    final typeColor = _materialTypeColor(materialType);
    final typeIcon = _materialTypeIcon(materialType);
    final typeLabel = _materialTypeLabels[materialType] ?? materialType;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        side: BorderSide(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: type icon + title + actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Material type icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusMD),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 22),
                ),
                const SizedBox(width: 12),

                // Title + chips
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(title,
                                style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                          ),
                          if (!published)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(
                                    AppSizes.radiusSM),
                              ),
                              child: Text('Draft',
                                  style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.warning)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Chips row
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          // Subject chip (teal)
                          _chip(
                            label: subject,
                            color: const Color(0xFF0D9488),
                          ),
                          // Class chip
                          _chip(
                            label: className,
                            color: AppColors.navy,
                          ),
                          // Material type chip
                          _chip(
                            label: typeLabel,
                            color: typeColor,
                            icon: typeIcon,
                          ),
                          // Chapter badge
                          if (chapter.isNotEmpty)
                            _chip(
                              label: 'Ch: $chapter',
                              color: AppColors.gold,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      color: AppColors.navy,
                      onPressed: () => _showFormDialog(m),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: AppColors.error,
                      onPressed: () => _confirmDelete(m),
                    ),
                  ],
                ),
              ],
            ),

            // Description preview
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: Text(description,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusSM + 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}
