import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/staff_api_service.dart';
import 'hr/staff_list_screen.dart';
import 'hr/leave_management_screen.dart';
import 'hr/salary_screen.dart';
import 'hr/staff_attendance_screen.dart';

class HrScreen extends StatefulWidget {
  const HrScreen({super.key});

  @override
  State<HrScreen> createState() => _HrScreenState();
}

class _HrScreenState extends State<HrScreen> {
  String _activeSection = 'dashboard';
  bool _loading = true;
  Map<String, dynamic>? _dashboard;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    try {
      final data = await StaffApiService.getStaffDashboard();
      if (mounted) setState(() => _dashboard = data);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    switch (_activeSection) {
      case 'staff':
        return _wrapWithBack(const StaffListScreen(), 'Staff List');
      case 'leave':
        return _wrapWithBack(const LeaveManagementScreen(), 'Leave Management');
      case 'salary':
        return _wrapWithBack(const SalaryScreen(), 'Salary & Payroll');
      case 'attendance':
        return _wrapWithBack(
            const StaffAttendanceScreen(), 'Staff Attendance');
      default:
        return _buildDashboard();
    }
  }

  Widget _wrapWithBack(Widget child, String title) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() => _activeSection = 'dashboard');
                  _loadDashboard();
                },
              ),
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildDashboard() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final totalStaff = (_dashboard?['totalStaff'] as num?)?.toInt() ?? 0;
    final activeStaff = (_dashboard?['activeStaff'] as num?)?.toInt() ?? 0;
    final onLeave = (_dashboard?['onLeaveToday'] as num?)?.toInt() ?? 0;
    final pendingLeave =
        (_dashboard?['pendingLeaveRequests'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HR & Staff Management',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = Responsive.gridColumns(context);
              final w = (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _statCard('Total Staff', '$totalStaff',
                      Icons.people_alt_rounded, AppColors.navy, w),
                  _statCard('Active', '$activeStaff', Icons.check_circle,
                      Colors.green, w),
                  _statCard('On Leave Today', '$onLeave',
                      Icons.event_busy, Colors.orange, w),
                  _statCard('Pending Leaves', '$pendingLeave',
                      Icons.hourglass_top, Colors.red, w),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Text('Manage',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _actionCard('Staff Directory', Icons.badge_outlined,
                  'View and manage all staff', () {
                setState(() => _activeSection = 'staff');
              }),
              _actionCard('Leave Management', Icons.event_available,
                  'Approve or reject leave requests', () {
                setState(() => _activeSection = 'leave');
              }),
              _actionCard('Salary & Payroll', Icons.account_balance_wallet,
                  'Generate and manage salaries', () {
                setState(() => _activeSection = 'salary');
              }),
              _actionCard('Staff Attendance', Icons.fingerprint,
                  'Mark daily staff attendance', () {
                setState(() => _activeSection = 'attendance');
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(
      String title, String value, IconData icon, Color color, double width) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard(
      String title, IconData icon, String subtitle, VoidCallback onTap) {
    return SizedBox(
      width: 260,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 32, color: AppColors.navy),
                const SizedBox(height: 12),
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
