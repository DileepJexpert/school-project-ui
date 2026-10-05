import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/searchable_dropdown.dart';
import '../../../services/homework_api_service.dart';

class HomeworkScreen extends StatefulWidget {
  const HomeworkScreen({super.key});

  @override
  State<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends State<HomeworkScreen> {
  bool _loading = true;
  List<dynamic> _homeworkList = [];
  String? _filterClass;
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // ALL, DUE_SOON, OVERDUE, ACTIVE
  String? _error;

  // Remember last used values for quick re-assignment
  String? _lastUsedClass;
  String? _lastUsedSubject;

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await HomeworkApiService.getAllHomework(className: _filterClass);
      if (mounted) setState(() => _homeworkList = data);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Homework could not be loaded right now.');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isOverdue(String value) {
    final date = DateTime.tryParse(value);
    return date != null && date.isBefore(DateTime.now());
  }

  bool _isDueSoon(String value) {
    final date = DateTime.tryParse(value);
    if (date == null || _isOverdue(value)) return false;
    return date.difference(DateTime.now()).inDays <= 7;
  }

  List<Map<String, dynamic>> get _visibleHomework {
    final query = _searchQuery.trim().toLowerCase();
    return _homeworkList.whereType<Map<String, dynamic>>().where((hw) {
      final dueDate = hw['dueDate'] as String? ?? '';
      if (_statusFilter == 'OVERDUE' && !_isOverdue(dueDate)) return false;
      if (_statusFilter == 'DUE_SOON' && !_isDueSoon(dueDate)) return false;
      if (_statusFilter == 'ACTIVE' && _isOverdue(dueDate)) return false;

      if (query.isEmpty) return true;
      final text = [
        hw['title'],
        hw['description'],
        hw['subject'],
        hw['teacherName']
      ].whereType<String>().join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  Color _getSubjectColor(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) return const Color(0xFF4F46E5);
    if (s.contains('sci') ||
        s.contains('phys') ||
        s.contains('chem') ||
        s.contains('bio')) {
      return const Color(0xFF059669);
    }
    if (s.contains('eng')) return const Color(0xFF7C3AED);
    if (s.contains('soc') || s.contains('hist') || s.contains('geog')) {
      return const Color(0xFFD97706);
    }
    if (s.contains('comp') || s.contains('coding') || s.contains('it')) {
      return const Color(0xFF0284C7);
    }
    if (s.contains('hindi') || s.contains('lang') || s.contains('sanskrit')) {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFF0D9488);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final allList = _homeworkList.whereType<Map<String, dynamic>>().toList();
    final overdueCount =
        allList.where((hw) => _isOverdue(hw['dueDate'] as String? ?? '')).length;
    final dueSoonCount =
        allList.where((hw) => _isDueSoon(hw['dueDate'] as String? ?? '')).length;
    final activeCount = allList
        .where((hw) => !_isOverdue(hw['dueDate'] as String? ?? ''))
        .length;
    final visibleList = _visibleHomework;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(Responsive.contentPadding(context), 22,
              Responsive.contentPadding(context), 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Homework & Assignments',
                            style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: palette.brand)),
                        const SizedBox(height: 4),
                        Text(
                            'Assign coursework, monitor student submissions, and manage upcoming academic deadlines.',
                            style: GoogleFonts.nunitoSans(
                                fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.brand,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showFormDialog(null),
                    icon: const Icon(Icons.add_task_rounded, size: 18),
                    label: Text('Assign Homework',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // KPI Summary cards
              LayoutBuilder(builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                final cardWidth = isNarrow
                    ? (constraints.maxWidth - 8) / 2
                    : (constraints.maxWidth - 36) / 4;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _kpiCard(
                      title: 'Total Assignments',
                      value: '${allList.length}',
                      icon: Icons.menu_book_rounded,
                      color: palette.brand,
                      width: cardWidth,
                      isSelected: _statusFilter == 'ALL',
                      onTap: () => setState(() => _statusFilter = 'ALL'),
                    ),
                    _kpiCard(
                      title: 'Active Tasks',
                      value: '$activeCount',
                      icon: Icons.assignment_outlined,
                      color: const Color(0xFF0284C7),
                      width: cardWidth,
                      isSelected: _statusFilter == 'ACTIVE',
                      onTap: () => setState(() => _statusFilter = 'ACTIVE'),
                    ),
                    _kpiCard(
                      title: 'Due This Week',
                      value: '$dueSoonCount',
                      icon: Icons.access_time_filled_rounded,
                      color: const Color(0xFFD97706),
                      width: cardWidth,
                      isSelected: _statusFilter == 'DUE_SOON',
                      onTap: () => setState(() => _statusFilter = 'DUE_SOON'),
                    ),
                    _kpiCard(
                      title: 'Overdue Work',
                      value: '$overdueCount',
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.error,
                      width: cardWidth,
                      isSelected: _statusFilter == 'OVERDUE',
                      onTap: () => setState(() => _statusFilter = 'OVERDUE'),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 16),

              // Filter Controls
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: Responsive.isMobile(context) ? double.infinity : 220,
                    child: SearchableDropdownFormField<String>(
                      initialValue: _filterClass ?? 'All Classes',
                      hintText: 'All Classes',
                      items: ['All Classes', ...SchoolConstants.allClasses],
                      onChanged: (v) {
                        setState(() => _filterClass =
                            (v == null || v == 'All Classes') ? null : v);
                        _loadHomework();
                      },
                    ),
                  ),
                  SizedBox(
                    width: Responsive.isMobile(context) ? double.infinity : 280,
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search title, subject, or teacher...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        filled: true,
                        fillColor: palette.surface,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: palette.border.withValues(alpha: 0.6)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: palette.border.withValues(alpha: 0.6)),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh assignments',
                    onPressed: _loading ? null : _loadHomework,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Homework list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorState(palette)
                  : visibleList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.assignment_turned_in_outlined,
                                  size: 56,
                                  color: palette.brand.withValues(alpha: 0.25)),
                              const SizedBox(height: 14),
                              Text(
                                  _searchQuery.isEmpty
                                      ? 'No homework found for this filter'
                                      : 'No homework matches your search',
                                  style: GoogleFonts.poppins(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(
                                  _searchQuery.isEmpty
                                      ? 'Assign homework for a class to track submissions.'
                                      : 'Try searching by a different title, subject, or teacher.',
                                  style: GoogleFonts.nunitoSans(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () => _showFormDialog(null),
                                  icon: const Icon(Icons.add, size: 17),
                                  label: const Text('Assign Homework'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadHomework,
                          child: ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                                Responsive.contentPadding(context),
                                4,
                                Responsive.contentPadding(context),
                                32),
                            itemCount: visibleList.length,
                            itemBuilder: (context, index) {
                              return _buildHomeworkCard(visibleList[index]);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : palette.border.withValues(alpha: 0.6),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : palette.brand,
                    ),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(AppThemePalette palette) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded,
              size: 42, color: AppColors.error.withValues(alpha: 0.8)),
          const SizedBox(height: 12),
          Text('Could not load homework',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.brand)),
          const SizedBox(height: 5),
          Text('$_error Please retry in a moment.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: _loadHomework,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Retry')),
        ]),
      ),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> hw) {
    final title = hw['title'] as String? ?? '';
    final description = hw['description'] as String? ?? '';
    final className = hw['className'] as String? ?? '';
    final subject = hw['subject'] as String? ?? '';
    final teacherName = hw['teacherName'] as String? ?? 'Class Teacher';
    final dueDate = hw['dueDate'] as String? ?? '';
    final assignedDate = hw['assignedDate'] as String? ?? '';
    final id = hw['id'] as String? ?? '';
    final palette = context.palette;

    final isOverdue = _isOverdue(dueDate);
    final isDueSoon = _isDueSoon(dueDate);
    final subjectColor = _getSubjectColor(subject);

    final statusColor = isOverdue
        ? AppColors.error
        : (isDueSoon ? const Color(0xFFD97706) : const Color(0xFF059669));
    final statusLabel =
        isOverdue ? 'Overdue' : (isDueSoon ? 'Due Soon' : 'Active');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOverdue
              ? AppColors.error.withValues(alpha: 0.3)
              : palette.border.withValues(alpha: 0.6),
        ),
      ),
      color: palette.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Class & Subject pills, Status chip, and Actions
            Row(
              children: [
                // Subject Tag
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: subjectColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: subjectColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_stories_rounded,
                          size: 13, color: subjectColor),
                      const SizedBox(width: 5),
                      Text(
                        subject,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: subjectColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Class Pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.brand.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    className,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: palette.brand,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Status Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOverdue
                            ? Icons.error_outline_rounded
                            : (isDueSoon
                                ? Icons.hourglass_top_rounded
                                : Icons.check_circle_outline_rounded),
                        size: 13,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Submissions button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(
                        color: palette.brand.withValues(alpha: 0.3)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => _showSubmissionsDialog(hw),
                  icon: const Icon(Icons.people_alt_outlined, size: 15),
                  label: Text('Submissions',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 4),

                // Action Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (val) {
                    if (val == 'edit') _showFormDialog(hw);
                    if (val == 'delete') _deleteHomework(id);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Edit Assignment'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Homework Title
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: palette.brand,
              ),
            ),

            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  color: AppColors.textPrimary.withValues(alpha: 0.85),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),

            // Metadata footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: palette.border.withValues(alpha: 0.4)),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: palette.brand.withValues(alpha: 0.12),
                        child: Text(
                          teacherName.isNotEmpty ? teacherName[0].toUpperCase() : 'T',
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: palette.brand),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(teacherName,
                          style: GoogleFonts.nunitoSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                  if (assignedDate.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_available_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 5),
                        Text('Assigned: $assignedDate',
                            style: GoogleFonts.nunitoSans(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_outlined, size: 14, color: statusColor),
                      const SizedBox(width: 5),
                      Text('Due: $dueDate',
                          style: GoogleFonts.nunitoSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusColor)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Submissions Modal Dialog ───
  void _showSubmissionsDialog(Map<String, dynamic> hw) {
    final title = hw['title'] as String? ?? 'Homework';
    final className = hw['className'] as String? ?? 'Class';
    final subject = hw['subject'] as String? ?? 'Subject';
    final palette = context.palette;

    // Simulated roster for this class
    final mockRoster = [
      {'name': 'Aarav Sharma', 'roll': '101', 'status': 'Submitted', 'date': 'Yesterday', 'score': 'A'},
      {'name': 'Ananya Verma', 'roll': '102', 'status': 'Submitted', 'date': '2 days ago', 'score': 'A+'},
      {'name': 'Devansh Patel', 'roll': '103', 'status': 'Pending', 'date': '-', 'score': '-'},
      {'name': 'Diya Nair', 'roll': '104', 'status': 'Submitted', 'date': 'Today', 'score': 'B+'},
      {'name': 'Ishaan Gupta', 'roll': '105', 'status': 'Submitted', 'date': 'Yesterday', 'score': 'A'},
      {'name': 'Meera Joshi', 'roll': '106', 'status': 'Pending', 'date': '-', 'score': '-'},
      {'name': 'Rohan Rao', 'roll': '107', 'status': 'Submitted', 'date': 'Today', 'score': 'A'},
      {'name': 'Saanvi Iyer', 'roll': '108', 'status': 'Submitted', 'date': '2 days ago', 'score': 'A+'},
    ];

    final submittedCount =
        mockRoster.where((r) => r['status'] == 'Submitted').length;
    final totalCount = mockRoster.length;
    final pct = (submittedCount / totalCount * 100).toInt();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: palette.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.assignment_turned_in,
                  color: palette.brand, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Class Submissions',
                      style: GoogleFonts.poppins(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  Text('$className • $subject • $title',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress Bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: palette.border.withValues(alpha: 0.6)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Submission Rate',
                            style: GoogleFonts.poppins(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('$submittedCount of $totalCount turned in ($pct%)',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF059669))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: submittedCount / totalCount,
                        minHeight: 7,
                        backgroundColor:
                            palette.border.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF059669)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Student List
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: mockRoster.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final item = mockRoster[idx];
                    final isSubmitted = item['status'] == 'Submitted';
                    return ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: isSubmitted
                            ? const Color(0xFF059669).withValues(alpha: 0.12)
                            : Colors.orange.withValues(alpha: 0.12),
                        child: Text(
                          item['roll']!,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSubmitted
                                ? const Color(0xFF059669)
                                : Colors.orange,
                          ),
                        ),
                      ),
                      title: Text(item['name']!,
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          isSubmitted
                              ? 'Turned in ${item['date']}'
                              : 'Awaiting submission',
                          style: GoogleFonts.nunitoSans(
                              fontSize: 11, color: AppColors.textSecondary)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSubmitted
                              ? const Color(0xFF059669).withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item['status']!,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSubmitted
                                ? const Color(0xFF059669)
                                : Colors.orange,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: palette.brand,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ─── Form Dialog (Add / Edit) ───

  void _showFormDialog(Map<String, dynamic>? existing) {
    final isEdit = existing != null;

    String? selectedClass =
        isEdit ? existing['className'] as String? : _lastUsedClass;
    String? selectedSubject =
        isEdit ? existing['subject'] as String? : _lastUsedSubject;
    bool isOtherSubject = false;

    if (selectedSubject != null &&
        !SchoolConstants.commonSubjects.contains(selectedSubject)) {
      isOtherSubject = true;
    }

    final titleCtrl =
        TextEditingController(text: existing?['title'] as String? ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description'] as String? ?? '');
    final otherSubjectCtrl = TextEditingController(
        text: isOtherSubject ? selectedSubject ?? '' : '');

    DateTime? dueDate;
    final dueDateStr = existing?['dueDate'] as String? ?? '';
    if (dueDateStr.isNotEmpty) {
      dueDate = DateTime.tryParse(dueDateStr);
    }

    final now = DateTime.now();
    final quickDates = <String, DateTime>{
      'Tomorrow': now.add(const Duration(days: 1)),
      'In 2 Days': now.add(const Duration(days: 2)),
      'Next Week': now.add(const Duration(days: 7)),
    };

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> submit({bool addAnother = false}) async {
              final actualSubject = isOtherSubject
                  ? otherSubjectCtrl.text.trim()
                  : selectedSubject;
              final currentDueDate = dueDate;

              if (selectedClass == null ||
                  actualSubject == null ||
                  actualSubject.isEmpty ||
                  titleCtrl.text.trim().isEmpty ||
                  currentDueDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please fill all required fields')),
                );
                return;
              }

              final data = {
                'className': selectedClass,
                'subject': actualSubject,
                'title': titleCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'dueDate': _formatDate(currentDueDate),
              };

              _lastUsedClass = selectedClass;
              _lastUsedSubject = actualSubject;

              try {
                if (existing != null) {
                  await HomeworkApiService.updateHomework(
                      existing['id'] as String, data);
                } else {
                  await HomeworkApiService.createHomework(data);
                }
                if (!addAnother && ctx.mounted) Navigator.pop(ctx);
                _loadHomework();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(isEdit
                            ? 'Homework updated'
                            : 'Homework assigned successfully')),
                  );
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Homework could not be saved. Please retry.')),
                  );
                }
              }

              if (addAnother) {
                setDialogState(() {
                  titleCtrl.clear();
                  descCtrl.clear();
                  dueDate = null;
                });
              }
            }

            return AlertDialog(
              title: Text(isEdit ? 'Edit Homework' : 'Assign Homework',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SearchableDropdownFormField<String>(
                        initialValue: selectedClass,
                        labelText: 'Class *',
                        hintText: 'Select or type class…',
                        items: SchoolConstants.allClasses,
                        onChanged: (v) =>
                            setDialogState(() => selectedClass = v),
                      ),
                      const SizedBox(height: 12),
                      SearchableDropdownFormField<String>(
                        initialValue: isOtherSubject
                            ? 'Other'
                            : (SchoolConstants.commonSubjects
                                    .contains(selectedSubject)
                                ? selectedSubject
                                : null),
                        labelText: 'Subject *',
                        hintText: 'Select or type subject…',
                        items: [
                          ...SchoolConstants.commonSubjects,
                          'Other',
                        ],
                        onChanged: (v) {
                          setDialogState(() {
                            if (v == 'Other') {
                              isOtherSubject = true;
                              selectedSubject = null;
                            } else {
                              isOtherSubject = false;
                              selectedSubject = v;
                            }
                          });
                        },
                      ),
                      if (isOtherSubject) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: otherSubjectCtrl,
                          decoration: InputDecoration(
                            hintText: 'Type subject name',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Title *',
                          hintText: 'e.g. Chapter 5 Exercise',
                          prefixIcon: const Icon(Icons.title, size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Description (optional)',
                          hintText: 'Instructions for students...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('Due Date *',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...quickDates.entries.map((e) {
                            final isSelected = dueDate != null &&
                                _formatDate(dueDate!) == _formatDate(e.value);
                            return ChoiceChip(
                              label: Text(e.key),
                              selected: isSelected,
                              selectedColor:
                                  AppColors.navy.withValues(alpha: 0.15),
                              labelStyle: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppColors.navy
                                    : AppColors.textSecondary,
                              ),
                              onSelected: (_) =>
                                  setDialogState(() => dueDate = e.value),
                            );
                          }),
                          ActionChip(
                            avatar: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              dueDate != null &&
                                      !quickDates.values.any((qd) =>
                                          _formatDate(qd) ==
                                          _formatDate(dueDate!))
                                  ? _formatDate(dueDate!)
                                  : 'Custom...',
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate:
                                    dueDate ?? now.add(const Duration(days: 1)),
                                firstDate: now,
                                lastDate: now.add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setDialogState(() => dueDate = picked);
                              }
                            },
                          ),
                        ],
                      ),
                      if (dueDate != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Due: ${_formatDate(dueDate!)}',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                if (!isEdit)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: AppColors.navy),
                    ),
                    onPressed: () => submit(addAnother: true),
                    child: Text('Assign & Add Another',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => submit(),
                  child: Text(isEdit ? 'Update' : 'Assign',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteHomework(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Homework'),
        content: const Text('Are you sure you want to delete this homework?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await HomeworkApiService.deleteHomework(id);
        _loadHomework();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Homework could not be deleted. Please retry.')),
          );
        }
      }
    }
  }
}
