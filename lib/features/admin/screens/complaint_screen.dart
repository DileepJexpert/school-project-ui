import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/complaint_api_service.dart';

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loading = true;
  List<dynamic> _complaints = [];
  Map<String, dynamic> _stats = {};

  String _statusFilter = 'ALL';
  String _categoryFilter = 'ALL';

  static const _statuses = [
    'ALL',
    'OPEN',
    'IN_PROGRESS',
    'RESOLVED',
    'CLOSED',
    'REJECTED',
  ];
  static const _categories = [
    'ALL',
    'ACADEMIC',
    'FACILITY',
    'TRANSPORT',
    'FEE',
    'DISCIPLINE',
    'STAFF',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      final results = await Future.wait([
        ComplaintApiService.getAllComplaints(),
        ComplaintApiService.getStats(),
      ]);
      if (mounted) {
        setState(() {
          _complaints = results[0] as List<dynamic>;
          _stats = results[1] as Map<String, dynamic>;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<dynamic> get _filteredComplaints {
    return _complaints.where((c) {
      final m = c as Map<String, dynamic>;
      if (_statusFilter != 'ALL' && m['status'] != _statusFilter) return false;
      if (_categoryFilter != 'ALL' && m['category'] != _categoryFilter) {
        return false;
      }
      return true;
    }).toList();
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
      'URGENT' => AppColors.error,
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  // ----- Build -----

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.contentPadding(context),
            Responsive.contentPadding(context),
            Responsive.contentPadding(context),
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Complaint / Grievance Management',
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy)),
                    const SizedBox(height: 4),
                    Text(
                        'Review and manage complaints filed by students, parents and staff.',
                        style: GoogleFonts.poppins(
                            color: AppColors.textSecondary, fontSize: 14)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Tab bar
        TabBar(
          controller: _tabController,
          labelColor: AppColors.navy,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.gold,
          labelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
          tabs: const [
            Tab(text: 'Complaints'),
            Tab(text: 'Dashboard'),
          ],
        ),
        const Divider(height: 1),

        // Tab body
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildComplaintsList(),
              _buildDashboard(),
            ],
          ),
        ),
      ],
    );
  }

  // ===== TAB 1: Complaints List =====

  Widget _buildComplaintsList() {
    final filtered = _filteredComplaints;

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          _buildStatsRow(compact: true),
          const SizedBox(height: 16),

          // Filters
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: _inputDecoration('Status'),
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textPrimary),
                  items: _statuses
                      .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s == 'ALL' ? 'All Statuses' : s)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _statusFilter = v);
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: _categoryFilter,
                  decoration: _inputDecoration('Category'),
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textPrimary),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c == 'ALL' ? 'All Categories' : c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _categoryFilter = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Complaint cards
          if (filtered.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('No complaints found.',
                      style:
                          GoogleFonts.poppins(color: AppColors.textSecondary)),
                ),
              ),
            )
          else
            ...(filtered.map(
                (c) => _buildComplaintCard(c as Map<String, dynamic>))),
        ],
      ),
    );
  }

  Widget _buildStatsRow({bool compact = false}) {
    final open = (_stats['open'] as num?)?.toInt() ?? 0;
    final inProgress = (_stats['inProgress'] as num?)?.toInt() ?? 0;
    final resolved = (_stats['resolved'] as num?)?.toInt() ?? 0;
    final total = (_stats['total'] as num?)?.toInt() ?? 0;

    final double fontSize = compact ? 18.0 : 26.0;
    final double labelSize = compact ? 11.0 : 13.0;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _statsCard('Open', '$open', AppColors.error, fontSize, labelSize),
        _statsCard(
            'In Progress', '$inProgress', Colors.orange, fontSize, labelSize),
        _statsCard(
            'Resolved', '$resolved', AppColors.success, fontSize, labelSize),
        _statsCard('Total', '$total', AppColors.navy, fontSize, labelSize),
      ],
    );
  }

  Widget _statsCard(
      String label, String value, Color color, double fs, double ls) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: fs, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: ls, color: AppColors.textSecondary)),
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
    final filedByName = complaint['filedByName'] as String? ?? '';
    final filedByRole = complaint['filedByRole'] as String? ?? '';
    final studentName = complaint['studentName'] as String? ?? '';
    final studentClass = complaint['studentClass'] as String? ?? '';
    final assignedToName = complaint['assignedToName'] as String? ?? '';
    final createdAt = complaint['createdAt'] as String? ?? '';

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
            const SizedBox(height: 6),

            // Description
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textSecondary)),
              ),

            // Chips row: category, priority, status
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                // Category chip
                Chip(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  label: Text(category,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: _categoryColor(category))),
                  backgroundColor: _categoryColor(category).withOpacity(0.1),
                  side: BorderSide.none,
                ),
                // Priority badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priority == 'URGENT'
                        ? AppColors.error.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSM),
                  ),
                  child: Text(priority,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _priorityColor(priority))),
                ),
                // Status badge
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
            const SizedBox(height: 10),

            // Filed by
            if (filedByName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('Filed by: $filedByName',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textSecondary)),
                    if (filedByRole.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusSM),
                        ),
                        child: Text(filedByRole,
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: AppColors.info)),
                      ),
                    ],
                    if (formattedDate.isNotEmpty) ...[
                      const Spacer(),
                      Text(formattedDate,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.textLight)),
                    ],
                  ],
                ),
              ),

            // Student info
            if (studentName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.school_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                        'Student: $studentName${studentClass.isNotEmpty ? ' ($studentClass)' : ''}',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),

            // Assigned to
            if (assignedToName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_ind_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('Assigned to: $assignedToName',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),

            const Divider(height: 20),

            // Action buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  onPressed: () => _showDetailDialog(complaint),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text('View Details',
                      style: GoogleFonts.poppins(fontSize: 12)),
                ),
                _buildStatusDropdownButton(id, status),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  onPressed: () => _confirmDelete(id),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label:
                      Text('Delete', style: GoogleFonts.poppins(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdownButton(String id, String currentStatus) {
    return PopupMenuButton<String>(
      tooltip: 'Update Status',
      onSelected: (newStatus) => _updateStatus(id, newStatus),
      itemBuilder: (ctx) => _statuses
          .where((s) => s != 'ALL' && s != currentStatus)
          .map((s) => PopupMenuItem(
                value: s,
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: _statusColor(s)),
                    const SizedBox(width: 8),
                    Text(s, style: GoogleFonts.poppins(fontSize: 13)),
                  ],
                ),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 6),
            Text('Update Status',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.orange.shade700)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down,
                size: 16, color: Colors.orange.shade700),
          ],
        ),
      ),
    );
  }

  // ----- Actions -----

  Future<void> _updateStatus(String id, String status) async {
    try {
      await ComplaintApiService.updateStatus(id, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $status'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        ),
        title: Text('Delete Complaint',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete this complaint?',
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
      await ComplaintApiService.delete(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complaint deleted'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ----- Detail Dialog -----

  void _showDetailDialog(Map<String, dynamic> complaint) {
    final id = complaint['_id'] as String? ?? '';
    final complaintNumber =
        complaint['complaintNumber'] as String? ?? 'CMP-???';
    final title = complaint['title'] as String? ?? 'Untitled';
    final description = complaint['description'] as String? ?? '';
    final category = complaint['category'] as String? ?? 'OTHER';
    final priority = complaint['priority'] as String? ?? 'MEDIUM';
    final status = complaint['status'] as String? ?? 'OPEN';
    final filedByName = complaint['filedByName'] as String? ?? '';
    final filedByRole = complaint['filedByRole'] as String? ?? '';
    final studentName = complaint['studentName'] as String? ?? '';
    final studentClass = complaint['studentClass'] as String? ?? '';
    final assignedToName = complaint['assignedToName'] as String? ?? '';
    final createdAt = complaint['createdAt'] as String? ?? '';
    final comments =
        (complaint['comments'] as List<dynamic>?) ?? [];

    String formattedDate = '';
    if (createdAt.isNotEmpty) {
      try {
        formattedDate =
            DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(createdAt));
      } catch (_) {
        formattedDate = createdAt;
      }
    }

    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(AppSizes.radiusLG),
                        topRight: Radius.circular(AppSizes.radiusLG),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(title,
                                  style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.white)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.goldPale,
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radiusSM),
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
                        Wrap(
                          spacing: 8,
                          children: [
                            _dialogChip(category, _categoryColor(category)),
                            _dialogChip(priority, _priorityColor(priority)),
                            _dialogChip(status, _statusColor(status)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Description
                          Text('Description',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text(
                              description.isNotEmpty
                                  ? description
                                  : 'No description provided.',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 16),

                          // Info rows
                          _infoRow('Filed By',
                              '$filedByName${filedByRole.isNotEmpty ? ' ($filedByRole)' : ''}'),
                          if (studentName.isNotEmpty)
                            _infoRow('Student',
                                '$studentName${studentClass.isNotEmpty ? ' - $studentClass' : ''}'),
                          if (assignedToName.isNotEmpty)
                            _infoRow('Assigned To', assignedToName),
                          if (formattedDate.isNotEmpty)
                            _infoRow('Filed On', formattedDate),

                          const Divider(height: 28),

                          // Comments timeline
                          Text('Comments',
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.navy)),
                          const SizedBox(height: 10),
                          if (comments.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Text('No comments yet.',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: AppColors.textLight)),
                            )
                          else
                            ...comments.map((c) {
                              final cm = c as Map<String, dynamic>;
                              final author =
                                  cm['authorName'] as String? ?? 'Unknown';
                              final text = cm['text'] as String? ?? '';
                              final commentDate =
                                  cm['createdAt'] as String? ?? '';
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
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.cream,
                                  borderRadius: BorderRadius.circular(
                                      AppSizes.radiusMD),
                                  border:
                                      Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                                                  color:
                                                      AppColors.textLight)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(text,
                                        style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color:
                                                AppColors.textSecondary)),
                                  ],
                                ),
                              );
                            }),

                          const SizedBox(height: 8),

                          // Add comment form
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: commentCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Add a comment...',
                                    hintStyle: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: AppColors.textLight),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                          AppSizes.radiusMD),
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                  ),
                                  style:
                                      GoogleFonts.poppins(fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.gold,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  final text = commentCtrl.text.trim();
                                  if (text.isEmpty) return;
                                  try {
                                    final result =
                                        await ComplaintApiService.addComment(
                                            id, {'text': text});
                                    commentCtrl.clear();
                                    // Refresh the comments in the dialog
                                    if (ctx.mounted) {
                                      final updatedComments =
                                          (result['comments']
                                                  as List<dynamic>?) ??
                                              [];
                                      setDialogState(() {
                                        comments.clear();
                                        comments.addAll(updatedComments);
                                      });
                                    }
                                    // Also refresh main list
                                    _loadData();
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Failed to add comment: $e'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.send, size: 18),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Close',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dialogChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppSizes.radiusSM),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  // ===== TAB 2: Dashboard =====

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 16),

          // Big stats cards
          _buildStatsRow(compact: false),
          const SizedBox(height: 28),

          // Category breakdown
          Text('By Category',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 12),
          _buildCategoryBreakdown(),
          const SizedBox(height: 28),

          // Priority breakdown
          Text('By Priority',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 12),
          _buildPriorityBreakdown(),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final byCategory =
        (_stats['byCategory'] as Map<String, dynamic>?) ?? {};

    final categoryNames = [
      'ACADEMIC',
      'FACILITY',
      'TRANSPORT',
      'FEE',
      'DISCIPLINE',
      'STAFF',
      'OTHER'
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: categoryNames.map((cat) {
        final count = (byCategory[cat] as num?)?.toInt() ?? 0;
        final color = _categoryColor(cat);
        return Container(
          width: 140,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text('$count',
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: color)),
              const SizedBox(height: 2),
              Text(cat,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriorityBreakdown() {
    final byPriority =
        (_stats['byPriority'] as Map<String, dynamic>?) ?? {};

    final priorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: priorities.map((p) {
        final count = (byPriority[p] as num?)?.toInt() ?? 0;
        final color = _priorityColor(p);
        return Container(
          width: 140,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text('$count',
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: color)),
              const SizedBox(height: 2),
              Text(p,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
