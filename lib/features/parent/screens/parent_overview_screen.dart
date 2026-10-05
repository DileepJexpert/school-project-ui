import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/parent_api_service.dart';

class ParentOverviewScreen extends StatefulWidget {
  final void Function(String childId, String childName) onSelectChild;
  final void Function(int index) onNavigate;

  const ParentOverviewScreen({
    super.key,
    required this.onSelectChild,
    required this.onNavigate,
  });

  @override
  State<ParentOverviewScreen> createState() => _ParentOverviewScreenState();
}

class _ParentOverviewScreenState extends State<ParentOverviewScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _dashboard;
  String? _activeChildId;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ParentApiService.getDashboard();
      if (mounted) {
        setState(() {
          _dashboard = data;
          final children = (data['children'] as List<dynamic>?) ?? [];
          if (children.isNotEmpty && _activeChildId == null) {
            final first = children.first as Map<String, dynamic>;
            _activeChildId = first['studentId'] as String?;
            final name = first['studentName'] as String? ?? 'Child';
            if (_activeChildId != null) {
              widget.onSelectChild(_activeChildId!, name);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load dashboard: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppColors.error.withValues(alpha: 0.8)),
              const SizedBox(height: 12),
              Text(
                'Could not load student overview',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.brand),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: palette.brand),
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final parentName = _dashboard?['parentName'] as String? ?? 'Parent';
    final children = (_dashboard?['children'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  palette.brand,
                  palette.brand.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: palette.brand.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.family_restroom,
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  'Parent Portal',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Welcome, $parentName!',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Monitor daily attendance, term academic scores, fee dues, and teacher notes for your enrolled children.',
                        style: GoogleFonts.nunitoSans(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: 'Refresh details',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _loadDashboard,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Child Selector Pills if multiple
          if (children.length > 1) ...[
            Text(
              'Select Child',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: palette.brand,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: children.map((c) {
                  final child = c as Map<String, dynamic>;
                  final id = child['studentId'] as String? ?? '';
                  final name = child['studentName'] as String? ?? 'Child';
                  final className = child['className'] as String? ?? '';
                  final isSelected = _activeChildId == id;

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: isSelected
                                ? Colors.white
                                : palette.brand.withValues(alpha: 0.15),
                            child: Text(
                              name.isNotEmpty ? name[0] : 'S',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? palette.brand : palette.brand,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('$name ($className)'),
                        ],
                      ),
                      selectedColor: palette.brand,
                      labelStyle: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (val) {
                        setState(() => _activeChildId = id);
                        widget.onSelectChild(id, name);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Children Cards
          if (children.isEmpty)
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: palette.border.withValues(alpha: 0.6)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.child_care_rounded,
                          size: 56,
                          color: palette.brand.withValues(alpha: 0.3)),
                      const SizedBox(height: 14),
                      Text(
                        'No children linked to your account yet.',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Please contact the school administrative office to link your student admission records.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunitoSans(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...children.map((child) => _buildChildCard(child as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    final palette = context.palette;
    final studentId = child['studentId'] as String? ?? '';
    final name = child['studentName'] as String? ?? 'Student';
    final className = child['className'] as String? ?? 'Class';
    final attendance = (child['attendancePercentage'] as num?)?.toDouble() ?? 0;
    final overallPct = (child['overallPercentage'] as num?)?.toDouble() ?? 0;
    final totalFees = (child['totalFees'] as num?)?.toDouble() ?? 0;
    final paidFees = (child['paidFees'] as num?)?.toDouble() ?? 0;
    final pendingFees = (child['pendingFees'] as num?)?.toDouble() ?? 0;
    final isSelected = _activeChildId == studentId;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? palette.brand : palette.border.withValues(alpha: 0.6),
          width: isSelected ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Header Row
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: palette.brand.withValues(alpha: 0.12),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: palette.brand,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: palette.brand,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: palette.brand.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Active View',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: palette.brand,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              className,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0D9488),
                              ),
                            ),
                          ),
                          if (studentId.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              'ID: $studentId',
                              style: GoogleFonts.nunitoSans(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.brand,
                    side: BorderSide(
                        color: palette.brand.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() => _activeChildId = studentId);
                    widget.onSelectChild(studentId, name);
                  },
                  icon: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    size: 16,
                    color: isSelected ? palette.brand : AppColors.textSecondary,
                  ),
                  label: Text(
                    isSelected ? 'Selected' : 'Select',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Performance KPI Cards
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 620;
              final width = isNarrow
                  ? (constraints.maxWidth - 8) / 2
                  : (constraints.maxWidth - 24) / 3;

              final attGood = attendance >= 75.0;
              final feeCleared = pendingFees <= 0;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _statCard(
                    title: 'Attendance',
                    value: '${attendance.toStringAsFixed(1)}%',
                    subtext: attGood ? 'Regular (Above 75%)' : 'Shortage Warning',
                    icon: Icons.fact_check_outlined,
                    color: attGood ? const Color(0xFF059669) : AppColors.error,
                    width: width,
                    onTap: () {
                      widget.onSelectChild(studentId, name);
                      widget.onNavigate(1);
                    },
                  ),
                  _statCard(
                    title: 'Academic Results',
                    value: '${overallPct.toStringAsFixed(1)}%',
                    subtext: overallPct >= 80 ? 'Grade A (Excellent)' : 'Term Average',
                    icon: Icons.emoji_events_outlined,
                    color: const Color(0xFF4F46E5),
                    width: width,
                    onTap: () {
                      widget.onSelectChild(studentId, name);
                      widget.onNavigate(2);
                    },
                  ),
                  _statCard(
                    title: 'Fee Status',
                    value: feeCleared ? 'Cleared' : '₹${pendingFees.toStringAsFixed(0)} Due',
                    subtext: 'Paid: ₹${paidFees.toStringAsFixed(0)} / ₹${totalFees.toStringAsFixed(0)}',
                    icon: Icons.receipt_long_outlined,
                    color: feeCleared ? const Color(0xFF059669) : AppColors.error,
                    width: width,
                    onTap: () {
                      widget.onSelectChild(studentId, name);
                      widget.onNavigate(3);
                    },
                  ),
                ],
              );
            }),
            const SizedBox(height: 18),

            // Quick Action Shortcuts Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: palette.border.withValues(alpha: 0.4)),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Quick Links:',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  _actionChip('Attendance Register', Icons.calendar_today_outlined, () {
                    widget.onSelectChild(studentId, name);
                    widget.onNavigate(1);
                  }),
                  _actionChip('Report Card & Marks', Icons.assessment_outlined, () {
                    widget.onSelectChild(studentId, name);
                    widget.onNavigate(2);
                  }),
                  _actionChip('Pay / View Fees', Icons.credit_card_outlined, () {
                    widget.onSelectChild(studentId, name);
                    widget.onNavigate(3);
                  }),
                  _actionChip('Weekly Timetable', Icons.schedule_outlined, () {
                    widget.onSelectChild(studentId, name);
                    widget.onNavigate(4);
                  }),
                  _actionChip('Message Teachers', Icons.chat_bubble_outline_rounded, () {
                    widget.onNavigate(5);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required double width,
    required VoidCallback onTap,
  }) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.brand,
                    ),
                  ),
                  Text(
                    subtext,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  Widget _actionChip(String label, IconData icon, VoidCallback onTap) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: palette.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: palette.brand),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: palette.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
