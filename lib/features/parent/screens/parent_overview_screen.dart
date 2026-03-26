import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
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
      if (mounted) setState(() => _dashboard = data);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load dashboard: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(_error!, style: GoogleFonts.poppins(color: Colors.red[700])),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadDashboard,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final children =
        (_dashboard?['children'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${_dashboard?['parentName'] ?? 'Parent'}!',
            style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.navy),
          ),
          const SizedBox(height: 4),
          Text(
            'Here\'s an overview of your children\'s progress.',
            style: GoogleFonts.poppins(
                color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          if (children.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No children linked to your account yet.',
                    style: GoogleFonts.poppins(color: AppColors.textSecondary),
                  ),
                ),
              ),
            )
          else
            ...children.map((child) => _buildChildCard(child)),
        ],
      ),
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    final studentId = child['studentId'] as String? ?? '';
    final name = child['studentName'] as String? ?? 'Student';
    final className = child['className'] as String? ?? '';
    final attendance = (child['attendancePercentage'] as num?)?.toDouble() ?? 0;
    final overallPct = (child['overallPercentage'] as num?)?.toDouble() ?? 0;
    final totalFees = (child['totalFees'] as num?)?.toDouble() ?? 0;
    final paidFees = (child['paidFees'] as num?)?.toDouble() ?? 0;
    final pendingFees = (child['pendingFees'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.navy.withOpacity(0.1),
                  child:
                      Text(name[0], style: const TextStyle(color: AppColors.navy)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(className,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    widget.onSelectChild(studentId, name);
                  },
                  child: Text('Select',
                      style: GoogleFonts.poppins(
                          color: AppColors.navy, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _statTile('Attendance', '${attendance.toStringAsFixed(1)}%',
                    Icons.rule_folder_outlined, Colors.blue, () {
                  widget.onSelectChild(studentId, name);
                  widget.onNavigate(1);
                }),
                _statTile('Results', '${overallPct.toStringAsFixed(1)}%',
                    Icons.emoji_events_outlined, Colors.orange, () {
                  widget.onSelectChild(studentId, name);
                  widget.onNavigate(2);
                }),
                _statTile(
                    'Fees',
                    'Paid: ${paidFees.toStringAsFixed(0)}/${totalFees.toStringAsFixed(0)}',
                    Icons.receipt_long_outlined,
                    pendingFees > 0 ? Colors.red : Colors.green, () {
                  widget.onSelectChild(studentId, name);
                  widget.onNavigate(3);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textSecondary)),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
