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

  int get _pendingCount => _allLeaves.where((l) => (l['status'] as String? ?? '').toUpperCase() == 'PENDING').length;
  int get _approvedCount => _allLeaves.where((l) => (l['status'] as String? ?? '').toUpperCase() == 'APPROVED').length;
  int get _rejectedCount => _allLeaves.where((l) => (l['status'] as String? ?? '').toUpperCase() == 'REJECTED').length;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _buildKpiStrip(),
        ),
        TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.navy,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.navy,
          labelStyle: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: 'Pending ($_pendingCount)'),
            Tab(text: 'Approved ($_approvedCount)'),
            Tab(text: 'Rejected ($_rejectedCount)'),
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

  Widget _buildKpiStrip() {
    return LayoutBuilder(builder: (context, constraints) {
      final isCompact = constraints.maxWidth < 650;
      final kpis = [
        _kpiItem('Pending Review', '$_pendingCount', Icons.pending_actions_outlined, AppColors.warning),
        _kpiItem('Approved Leaves', '$_approvedCount', Icons.check_circle_outline, AppColors.success),
        _kpiItem('Rejected', '$_rejectedCount', Icons.cancel_outlined, AppColors.error),
      ];

      if (isCompact) {
        return Wrap(spacing: 8, runSpacing: 8, children: kpis.map((k) => SizedBox(width: (constraints.maxWidth - 8) / 2, child: k)).toList());
      }
      return Row(children: kpis.map((k) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: k))).toList());
    });
  }

  Widget _kpiItem(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(val, style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
                Text(title, style: GoogleFonts.nunitoSans(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveList(List<dynamic> leaves, {bool showActions = false}) {
    if (leaves.isEmpty) {
      return Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text('No leave requests in this category.',
                style: GoogleFonts.nunitoSans(color: AppColors.textSecondary)),
          ));
    }

    return RefreshIndicator(
      onRefresh: _loadLeaves,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: leaves.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final leave = leaves[index] as Map<String, dynamic>;
          return _buildLeaveCard(leave, showActions: showActions);
        },
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave,
      {bool showActions = false}) {
    final staffName = leave['staffName'] as String? ?? 'Staff';
    final leaveType = leave['leaveType'] as String? ?? 'General';
    final fromDate = leave['fromDate'] as String? ?? '';
    final toDate = leave['toDate'] as String? ?? '';
    final totalDays = (leave['totalDays'] as num?)?.toInt() ?? 0;
    final reason = leave['reason'] as String? ?? '';
    final id = leave['id'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                child: Text(staffName.isNotEmpty ? staffName[0].toUpperCase() : '?',
                    style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(staffName,
                        style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.navy)),
                    Text('$fromDate to $toDate · $totalDays ${totalDays == 1 ? 'day' : 'days'}',
                        style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  leaveType,
                  style: GoogleFonts.nunitoSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.navy),
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Reason: $reason',
                style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _handleLeaveAction(id, 'reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _handleLeaveAction(id, 'approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Approve'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleLeaveAction(String id, String action) async {
    try {
      await StaffApiService.approveLeave(id, action);
      _loadLeaves();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave request $action' 'd successfully'),
            backgroundColor: action == 'approve' ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to $action leave request'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
