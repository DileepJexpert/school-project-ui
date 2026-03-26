import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/student_portal_api_service.dart';
import '../../../services/auth_service.dart';

class StudentOverviewScreen extends StatefulWidget {
  final void Function(int index) onNavigate;

  const StudentOverviewScreen({super.key, required this.onNavigate});

  @override
  State<StudentOverviewScreen> createState() => _StudentOverviewScreenState();
}

class _StudentOverviewScreenState extends State<StudentOverviewScreen> {
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
      final data = await StudentPortalApiService.getDashboard();
      if (mounted) setState(() => _dashboard = data);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load dashboard: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = AuthService.instance.currentUser?.fullName ?? 'Student';

    if (_loading) return const Center(child: CircularProgressIndicator());
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
                onPressed: _loadDashboard, child: const Text('Retry')),
          ],
        ),
      );
    }

    final attendance =
        (_dashboard?['attendancePercentage'] as num?)?.toDouble() ?? 0;
    final overallPct =
        (_dashboard?['overallPercentage'] as num?)?.toDouble() ?? 0;
    final totalFees = (_dashboard?['totalFees'] as num?)?.toDouble() ?? 0;
    final paidFees = (_dashboard?['paidFees'] as num?)?.toDouble() ?? 0;
    final pendingFees = (_dashboard?['pendingFees'] as num?)?.toDouble() ?? 0;
    final className = _dashboard?['className'] as String? ?? '';

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome, ${userName.split(' ').first}!',
              style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          if (className.isNotEmpty) ...
            [const SizedBox(height: 4),
            Text('Class: $className',
                style: GoogleFonts.poppins(
                    color: AppColors.textSecondary, fontSize: 14))],
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = Responsive.gridColumns(context);
              final cardWidth =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _overviewCard(
                    'Attendance',
                    '${attendance.toStringAsFixed(1)}%',
                    Icons.rule_folder_outlined,
                    attendance >= 75 ? Colors.green : Colors.red,
                    cardWidth,
                    () => widget.onNavigate(1),
                  ),
                  _overviewCard(
                    'Results',
                    '${overallPct.toStringAsFixed(1)}%',
                    Icons.emoji_events_outlined,
                    Colors.orange,
                    cardWidth,
                    () => widget.onNavigate(2),
                  ),
                  _overviewCard(
                    'Total Fees',
                    'Rs ${totalFees.toStringAsFixed(0)}',
                    Icons.receipt_long_outlined,
                    AppColors.navy,
                    cardWidth,
                    () => widget.onNavigate(4),
                  ),
                  _overviewCard(
                    'Pending Fees',
                    'Rs ${pendingFees.toStringAsFixed(0)}',
                    Icons.payment_outlined,
                    pendingFees > 0 ? Colors.red : Colors.green,
                    cardWidth,
                    () => widget.onNavigate(4),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _overviewCard(String title, String value, IconData icon, Color color,
      double width, VoidCallback onTap) {
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(icon, size: 26, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value,
                          style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: color)),
                      Text(title,
                          style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
