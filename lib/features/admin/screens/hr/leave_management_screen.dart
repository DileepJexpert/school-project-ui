import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../services/staff_api_service.dart';

class LeaveManagementScreen extends StatefulWidget {
  const LeaveManagementScreen({super.key});

  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;
  List<dynamic> _allLeaves = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadLeaves();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLeaves() async {
    setState(() => _loading = true);
    try {
      final data = await StaffApiService.getLeaves();
      if (mounted) setState(() => _allLeaves = data);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<dynamic> _filterByStatus(String status) {
    return _allLeaves
        .where((l) => (l['status'] as String? ?? '') == status)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.navy,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.navy,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildLeaveList(_filterByStatus('PENDING'),
                        showActions: true),
                    _buildLeaveList(_filterByStatus('APPROVED')),
                    _buildLeaveList(_filterByStatus('REJECTED')),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildLeaveList(List<dynamic> leaves, {bool showActions = false}) {
    if (leaves.isEmpty) {
      return Center(
          child: Text('No leave requests.',
              style: GoogleFonts.poppins(color: AppColors.textSecondary)));
    }

    return RefreshIndicator(
      onRefresh: _loadLeaves,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: leaves.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final leave = leaves[index] as Map<String, dynamic>;
          return _buildLeaveCard(leave, showActions: showActions);
        },
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave,
      {bool showActions = false}) {
    final staffName = leave['staffName'] as String? ?? '';
    final leaveType = leave['leaveType'] as String? ?? '';
    final fromDate = leave['fromDate'] as String? ?? '';
    final toDate = leave['toDate'] as String? ?? '';
    final totalDays = (leave['totalDays'] as num?)?.toInt() ?? 0;
    final reason = leave['reason'] as String? ?? '';
    final id = leave['id'] as String? ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(staffName,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                Chip(
                  label: Text(leaveType,
                      style: GoogleFonts.poppins(fontSize: 11)),
                  backgroundColor: AppColors.navy.withOpacity(0.1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('$fromDate to $toDate ($totalDays days)',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecondary)),
            if (reason.isNotEmpty) ...
              [const SizedBox(height: 4),
              Text('Reason: $reason',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textSecondary))],
            if (showActions) ...
              [const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _handleLeaveAction(id, 'reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Reject'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _handleLeaveAction(id, 'approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Approve'),
                  ),
                ],
              )],
          ],
        ),
      ),
    );
  }

  Future<void> _handleLeaveAction(String id, String action) async {
    try {
      await StaffApiService.approveLeave(id, action);
      _loadLeaves();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to $action leave request')),
        );
      }
    }
  }
}
