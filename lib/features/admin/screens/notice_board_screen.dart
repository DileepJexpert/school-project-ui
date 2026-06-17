import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/notice_api_service.dart';

class NoticeBoardScreen extends StatefulWidget {
  const NoticeBoardScreen({super.key});

  @override
  State<NoticeBoardScreen> createState() => _NoticeBoardScreenState();
}

class _NoticeBoardScreenState extends State<NoticeBoardScreen> {
  bool _loading = true;
  List<dynamic> _notices = [];
  Map<String, dynamic> _stats = {};
  String _categoryFilter = 'ALL';
  String _statusFilter = 'All';

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

  static const _statusFilters = ['All', 'Published', 'Drafts', 'Pinned'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final futures = await Future.wait([
        NoticeApiService.getAllNotices(),
        NoticeApiService.getStats(),
      ]);
      if (mounted) {
        setState(() {
          _notices = futures[0] as List<dynamic>;
          _stats = futures[1] as Map<String, dynamic>;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // ----- Filtering -----

  List<dynamic> get _filteredNotices {
    var list = List<dynamic>.from(_notices);

    // Category filter
    if (_categoryFilter != 'ALL') {
      list = list
          .where((n) =>
              (n as Map<String, dynamic>)['category'] == _categoryFilter)
          .toList();
    }

    // Status filter
    switch (_statusFilter) {
      case 'Published':
        list = list
            .where(
                (n) => (n as Map<String, dynamic>)['published'] == true)
            .toList();
        break;
      case 'Drafts':
        list = list
            .where(
                (n) => (n as Map<String, dynamic>)['published'] != true)
            .toList();
        break;
      case 'Pinned':
        list = list
            .where(
                (n) => (n as Map<String, dynamic>)['isPinned'] == true)
            .toList();
        break;
    }

    return list;
  }

  // ----- Colors -----

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
      'LOW' => Colors.grey,
      'MEDIUM' => Colors.blue,
      'HIGH' => Colors.orange,
      'URGENT' => Colors.red,
      _ => Colors.grey,
    };
  }

  Color _audienceColor(String audience) {
    return switch (audience) {
      'ALL' => AppColors.navy,
      'STUDENTS' => Colors.blue,
      'PARENTS' => Colors.purple,
      'TEACHERS' => Colors.teal,
      'STAFF' => Colors.orange,
      'SPECIFIC_CLASS' => Colors.green,
      _ => Colors.grey,
    };
  }

  // ----- Actions -----

  Future<void> _deleteNotice(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        ),
        title: Text('Delete Notice',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete this notice?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await NoticeApiService.delete(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notice deleted'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete notice: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _publishNotice(String id) async {
    try {
      await NoticeApiService.publish(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notice published'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _togglePin(String id) async {
    try {
      await NoticeApiService.togglePin(id);
      if (mounted) _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle pin: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ----- Create / Edit Dialog -----

  Future<void> _showCreateEditDialog(
      [Map<String, dynamic>? existing]) async {
    final isEdit = existing != null;
    final titleCtrl =
        TextEditingController(text: existing?['title'] as String? ?? '');
    final contentCtrl =
        TextEditingController(text: existing?['content'] as String? ?? '');
    final attachUrlCtrl = TextEditingController(
        text: existing?['attachmentUrl'] as String? ?? '');
    final attachNameCtrl = TextEditingController(
        text: existing?['attachmentName'] as String? ?? '');

    String category =
        existing?['category'] as String? ?? 'GENERAL';
    String priority =
        existing?['priority'] as String? ?? 'MEDIUM';
    String targetAudience =
        existing?['targetAudience'] as String? ?? 'ALL';
    String? targetClass = existing?['targetClass'] as String?;
    bool published = existing?['published'] as bool? ?? true;
    DateTime? expiryDate;
    if (existing?['expiryDate'] != null) {
      try {
        expiryDate = DateTime.parse(existing!['expiryDate'] as String);
      } catch (_) {}
    }

    bool saving = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            ),
            title: Text(
              isEdit ? 'Edit Notice' : 'Create Notice',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, color: AppColors.navy),
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Title *',
                        labelStyle: GoogleFonts.poppins(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 14),

                    // Content
                    TextField(
                      controller: contentCtrl,
                      maxLines: 6,
                      decoration: InputDecoration(
                        labelText: 'Content *',
                        alignLabelWithHint: true,
                        labelStyle: GoogleFonts.poppins(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 14),

                    // Category
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: InputDecoration(
                        labelText: 'Category *',
                        labelStyle: GoogleFonts.poppins(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD),
                        ),
                      ),
                      items: _categories
                          .where((c) => c != 'ALL')
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    style: GoogleFonts.poppins(fontSize: 14)),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => category = v!),
                    ),
                    const SizedBox(height: 14),

                    // Priority
                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        labelStyle: GoogleFonts.poppins(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD),
                        ),
                      ),
                      items: ['LOW', 'MEDIUM', 'HIGH', 'URGENT']
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p,
                                    style: GoogleFonts.poppins(fontSize: 14)),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => priority = v!),
                    ),
                    const SizedBox(height: 14),

                    // Target Audience
                    DropdownButtonFormField<String>(
                      value: targetAudience,
                      decoration: InputDecoration(
                        labelText: 'Target Audience *',
                        labelStyle: GoogleFonts.poppins(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD),
                        ),
                      ),
                      items: [
                        'ALL',
                        'STUDENTS',
                        'PARENTS',
                        'TEACHERS',
                        'STAFF',
                        'SPECIFIC_CLASS'
                      ]
                          .map((a) => DropdownMenuItem(
                                value: a,
                                child: Text(a,
                                    style: GoogleFonts.poppins(fontSize: 14)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setDialogState(() {
                          targetAudience = v!;
                          if (v != 'SPECIFIC_CLASS') targetClass = null;
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    // Target Class (conditional)
                    if (targetAudience == 'SPECIFIC_CLASS') ...[
                      DropdownButtonFormField<String>(
                        value: targetClass,
                        decoration: InputDecoration(
                          labelText: 'Target Class',
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMD),
                          ),
                        ),
                        items: SchoolConstants.baseClasses
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c,
                                      style:
                                          GoogleFonts.poppins(fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => targetClass = v),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Attachment URL
                    TextField(
                      controller: attachUrlCtrl,
                      decoration: InputDecoration(
                        labelText: 'Attachment URL (optional)',
                        labelStyle: GoogleFonts.poppins(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 14),

                    // Attachment Name
                    TextField(
                      controller: attachNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Attachment Name (optional)',
                        labelStyle: GoogleFonts.poppins(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 14),

                    // Expiry Date
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate:
                              expiryDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() => expiryDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Expiry Date (optional)',
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMD),
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (expiryDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () =>
                                      setDialogState(() => expiryDate = null),
                                ),
                              const Icon(Icons.calendar_today, size: 18),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                        child: Text(
                          expiryDate != null
                              ? DateFormat('dd MMM yyyy')
                                  .format(expiryDate!)
                              : 'No expiry',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Published switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Published',
                          style: GoogleFonts.poppins(fontSize: 14)),
                      subtitle: Text(
                        published
                            ? 'Visible to target audience'
                            : 'Saved as draft',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                      ),
                      value: published,
                      activeColor: AppColors.gold,
                      onChanged: (v) =>
                          setDialogState(() => published = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  ),
                ),
                onPressed: saving
                    ? null
                    : () async {
                        if (titleCtrl.text.trim().isEmpty ||
                            contentCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Title and Content are required')),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        final data = <String, dynamic>{
                          'title': titleCtrl.text.trim(),
                          'content': contentCtrl.text.trim(),
                          'category': category,
                          'priority': priority,
                          'targetAudience': targetAudience,
                          'published': published,
                        };
                        if (targetClass != null) {
                          data['targetClass'] = targetClass;
                        }
                        if (attachUrlCtrl.text.trim().isNotEmpty) {
                          data['attachmentUrl'] = attachUrlCtrl.text.trim();
                        }
                        if (attachNameCtrl.text.trim().isNotEmpty) {
                          data['attachmentName'] =
                              attachNameCtrl.text.trim();
                        }
                        if (expiryDate != null) {
                          data['expiryDate'] =
                              expiryDate!.toIso8601String();
                        }
                        try {
                          if (isEdit) {
                            await NoticeApiService.update(
                                existing['_id'] as String, data);
                          } else {
                            await NoticeApiService.create(data);
                          }
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                        setDialogState(() => saving = false);
                      },
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isEdit ? 'Update' : 'Create',
                        style: GoogleFonts.poppins()),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Notice updated' : 'Notice created'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadData();
    }
  }

  // ----- Build -----

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final filtered = _filteredNotices;

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          _buildHeaderRow(),
          const SizedBox(height: 20),

          // Stats row
          _buildStatsRow(),
          const SizedBox(height: 20),

          // Filter chips
          _buildFilterChips(),
          const SizedBox(height: 20),

          // Notice list
          if (filtered.isEmpty)
            _buildEmptyState()
          else
            ...filtered
                .map((n) => _buildNoticeCard(n as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Notice Board',
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.navy)),
        // Category dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _categoryFilter,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textPrimary),
              items: _categories
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: GoogleFonts.poppins(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _categoryFilter = v ?? 'ALL'),
            ),
          ),
        ),
        // Create button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            ),
            elevation: 2,
          ),
          onPressed: () => _showCreateEditDialog(),
          icon: const Icon(Icons.add, size: 20),
          label: Text('Create Notice',
              style:
                  GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    final total = _stats['totalNotices'] ?? _notices.length;
    final published = _stats['publishedCount'] ?? 0;
    final pinned = _stats['pinnedCount'] ?? 0;

    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Notices', '$total', Icons.article_outlined, AppColors.navy)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Published', '$published', Icons.publish_outlined, AppColors.success)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Pinned', '$pinned', Icons.push_pin_outlined, AppColors.gold)),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _statusFilters.map((f) {
        final selected = _statusFilter == f;
        return ChoiceChip(
          label: Text(f,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : AppColors.textPrimary)),
          selected: selected,
          selectedColor: AppColors.navy,
          backgroundColor: AppColors.creamDark,
          onSelected: (_) => setState(() => _statusFilter = f),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.campaign_outlined,
                  size: 56, color: AppColors.textLight),
              const SizedBox(height: 12),
              Text('No notices yet',
                  style: GoogleFonts.poppins(
                      fontSize: 16, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text('Create your first notice to get started.',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textLight)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> notice) {
    final id = notice['_id'] as String? ?? '';
    final title = notice['title'] as String? ?? 'Untitled';
    final content = notice['content'] as String? ?? '';
    final category = notice['category'] as String? ?? 'GENERAL';
    final priority = notice['priority'] as String? ?? 'MEDIUM';
    final targetAudience = notice['targetAudience'] as String? ?? 'ALL';
    final targetClass = notice['targetClass'] as String?;
    final published = notice['published'] as bool? ?? false;
    final isPinned = notice['isPinned'] as bool? ?? false;
    final readCount = notice['readCount'] as int? ?? 0;
    final createdAt = notice['createdAt'] as String? ?? '';
    final expiryDate = notice['expiryDate'] as String?;
    final publishedBy = notice['publishedBy'] as Map<String, dynamic>?;

    String formattedDate = '';
    if (createdAt.isNotEmpty) {
      try {
        formattedDate =
            DateFormat('dd MMM yyyy').format(DateTime.parse(createdAt));
      } catch (_) {
        formattedDate = createdAt;
      }
    }

    String? formattedExpiry;
    if (expiryDate != null) {
      try {
        formattedExpiry =
            DateFormat('dd MMM yyyy').format(DateTime.parse(expiryDate));
      } catch (_) {}
    }

    final publisherName = publishedBy != null
        ? '${publishedBy['firstName'] ?? ''} ${publishedBy['lastName'] ?? ''}'
            .trim()
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pinned indicator + title row
            Row(
              children: [
                if (isPinned) ...[
                  Icon(Icons.push_pin, size: 18, color: AppColors.gold),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Content preview
            Text(content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 12),

            // Chips row
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                // Category chip
                _chip(category, _categoryColor(category),
                    filled: category == 'URGENT'),

                // Priority badge
                _chip(priority, _priorityColor(priority)),

                // Target audience chip
                _chip(
                  targetAudience == 'SPECIFIC_CLASS' && targetClass != null
                      ? '$targetAudience ($targetClass)'
                      : targetAudience,
                  _audienceColor(targetAudience),
                ),

                // Published / Draft badge
                _chip(
                  published ? 'Published' : 'Draft',
                  published ? AppColors.success : Colors.grey,
                  filled: true,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Meta row
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (formattedExpiry != null)
                  _metaText(Icons.event_outlined, 'Expires: $formattedExpiry'),
                _metaText(Icons.visibility_outlined, 'Read by $readCount users'),
                if (publisherName != null && publisherName.isNotEmpty)
                  _metaText(Icons.person_outline, '$publisherName  $formattedDate'),
                if (publisherName == null || publisherName.isEmpty)
                  _metaText(Icons.schedule_outlined, formattedDate),
              ],
            ),
            const SizedBox(height: 12),

            // Actions row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _actionButton(
                    Icons.edit_outlined, 'Edit', AppColors.info, () {
                  _showCreateEditDialog(notice);
                }),
                if (!published)
                  _actionButton(Icons.publish_outlined, 'Publish',
                      AppColors.success, () => _publishNotice(id)),
                _actionButton(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  isPinned ? 'Unpin' : 'Pin',
                  AppColors.gold,
                  () => _togglePin(id),
                ),
                _actionButton(Icons.delete_outline, 'Delete',
                    AppColors.error, () => _deleteNotice(id)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusSM),
        border: filled ? null : Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: filled ? Colors.white : color,
        ),
      ),
    );
  }

  Widget _metaText(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textLight),
        const SizedBox(width: 4),
        Text(text,
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _actionButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        ),
        textStyle:
            GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}
