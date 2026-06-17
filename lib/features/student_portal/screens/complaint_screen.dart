import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/complaint_api_service.dart';

class StudentComplaintScreen extends StatefulWidget {
  const StudentComplaintScreen({super.key});

  @override
  State<StudentComplaintScreen> createState() => _StudentComplaintScreenState();
}

class _StudentComplaintScreenState extends State<StudentComplaintScreen> {
  bool _loading = true;
  List<dynamic> _complaints = [];
  String? _expandedId;

  static const _categories = [
    'ACADEMIC',
    'FACILITY',
    'TRANSPORT',
    'FEE',
    'DISCIPLINE',
    'STAFF',
    'OTHER',
  ];

  static const _priorities = ['LOW', 'MEDIUM', 'HIGH'];

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
    setState(() => _loading = true);
    try {
      final data = await ComplaintApiService.getStudentComplaints();
      if (mounted) setState(() => _complaints = data);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // ----- Colors -----

  Color _categoryColor(String category) {
    return switch (category) {
      'ACADEMIC' => Colors.blue,
      'FACILITY' => Colors.orange,
      'TRANSPORT' => Colors.purple,
      'FEE' => Colors.green,
      'DISCIPLINE' => Colors.red,
      'STAFF' => Colors.teal,
      _ => Colors.grey,
    };
  }

  Color _priorityColor(String priority) {
    return switch (priority) {
      'LOW' => AppColors.success,
      'MEDIUM' => Colors.orange,
      'HIGH' => AppColors.error,
      _ => AppColors.textSecondary,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'OPEN' => AppColors.error,
      'IN_PROGRESS' => Colors.orange,
      'RESOLVED' => AppColors.success,
      'CLOSED' => Colors.grey,
      'REJECTED' => AppColors.error,
      _ => Colors.grey,
    };
  }

  bool _statusFilled(String status) {
    return status != 'OPEN';
  }

  // ----- Build -----

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File Complaint button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                ),
                elevation: 2,
              ),
              onPressed: _showFileComplaintDialog,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: Text('File a Complaint',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),

          // My Complaints header
          Text('My Complaints',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 12),

          // List
          if (_complaints.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 48, color: AppColors.textLight),
                      const SizedBox(height: 12),
                      Text('No complaints filed',
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          else
            ...(_complaints
                .map((c) => _buildComplaintCard(c as Map<String, dynamic>))),
        ],
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> complaint) {
    final id = complaint['_id'] as String? ?? '';
    final complaintNumber =
        complaint['complaintNumber'] as String? ?? 'CMP-???';
    final title = complaint['title'] as String? ?? 'Untitled';
    final description = complaint['description'] as String? ?? '';
    final category = complaint['category'] as String? ?? 'OTHER';
    final priority = complaint['priority'] as String? ?? 'MEDIUM';
    final status = complaint['status'] as String? ?? 'OPEN';
    final createdAt = complaint['createdAt'] as String? ?? '';
    final comments = (complaint['comments'] as List<dynamic>?) ?? [];
    final isExpanded = _expandedId == id;

    String formattedDate = '';
    if (createdAt.isNotEmpty) {
      try {
        formattedDate =
            DateFormat('dd MMM yyyy').format(DateTime.parse(createdAt));
      } catch (_) {
        formattedDate = createdAt;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        onTap: () {
          setState(() {
            _expandedId = isExpanded ? null : id;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: title + complaint number
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(title,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.goldPale,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSM),
                    ),
                    child: Text(complaintNumber,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Chips row
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  // Category
                  Chip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    label: Text(category,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: _categoryColor(category))),
                    backgroundColor: _categoryColor(category).withOpacity(0.1),
                    side: BorderSide.none,
                  ),
                  // Priority
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    child: Text(priority,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _priorityColor(priority))),
                  ),
                  // Status
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusFilled(status)
                          ? _statusColor(status).withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSM),
                      border: _statusFilled(status)
                          ? null
                          : Border.all(color: _statusColor(status)),
                    ),
                    child: Text(status,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(status))),
                  ),
                ],
              ),

              // Date
              if (formattedDate.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(formattedDate,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textLight)),
                ),

              // Expanded details
              if (isExpanded) ...[
                const Divider(height: 20),
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Description',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(description,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),

                // Comments
                Text('Comments',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                if (comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('No comments yet.',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textLight)),
                  )
                else
                  ...comments.map((c) {
                    final cm = c as Map<String, dynamic>;
                    final author = cm['authorName'] as String? ?? 'Unknown';
                    final text = cm['text'] as String? ?? '';
                    final commentDate = cm['createdAt'] as String? ?? '';
                    String fDate = '';
                    if (commentDate.isNotEmpty) {
                      try {
                        fDate = DateFormat('dd MMM, hh:mm a')
                            .format(DateTime.parse(commentDate));
                      } catch (_) {
                        fDate = commentDate;
                      }
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMD),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person,
                                  size: 14,
                                  color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(author,
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              if (fDate.isNotEmpty)
                                Text(fDate,
                                    style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: AppColors.textLight)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(text,
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }),
              ],

              // Expand/collapse indicator
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----- File Complaint Dialog -----

  void _showFileComplaintDialog() {
    final titleCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    String category = _categories.first;
    String priority = 'MEDIUM';
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLG),
          ),
          title: Text('File a Complaint',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, color: AppColors.navy)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text('Title *',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    hintText: 'Brief title for your complaint',
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textLight),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMD),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                const SizedBox(height: 14),

                // Description
                Text('Description *',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: descriptionCtrl,
                  decoration: InputDecoration(
                    hintText: 'Describe your complaint in detail',
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textLight),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMD),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                  maxLines: 4,
                ),
                const SizedBox(height: 14),

                // Category
                Text('Category *',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMD),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: AppColors.textPrimary),
                  items: _categories
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => category = v);
                  },
                ),
                const SizedBox(height: 14),

                // Priority
                Text('Priority',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMD),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: AppColors.textPrimary),
                  items: _priorities
                      .map((p) =>
                          DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => priority = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
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
              onPressed: submitting
                  ? null
                  : () async {
                      if (titleCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Title is required')),
                        );
                        return;
                      }
                      if (descriptionCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Description is required')),
                        );
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        await ComplaintApiService.fileStudentComplaint({
                          'title': titleCtrl.text.trim(),
                          'description': descriptionCtrl.text.trim(),
                          'category': category,
                          'priority': priority,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Complaint filed successfully!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          _loadComplaints();
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Failed to file complaint: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                        setDialogState(() => submitting = false);
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Submit', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }
}
