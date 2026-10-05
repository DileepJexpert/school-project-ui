import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../services/staff_api_service.dart';
import 'staff_form_screen.dart';

class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  bool _loading = true;
  List<dynamic> _staffList = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _loading = true);
    try {
      final data = await StaffApiService.getAllStaff();
      if (mounted) setState(() => _staffList = data);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _selectedDept = 'ALL';

  List<String> get _departments {
    final depts = <String>{};
    for (final s in _staffList) {
      final d = (s['department'] as String? ?? '').trim();
      if (d.isNotEmpty) depts.add(d);
    }
    return depts.toList()..sort();
  }

  List<dynamic> get _filteredStaff {
    var list = _staffList;
    if (_selectedDept != 'ALL') {
      list = list.where((s) => (s['department'] as String? ?? '').trim() == _selectedDept).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) {
        final name = (s['fullName'] as String? ?? '').toLowerCase();
        final dept = (s['department'] as String? ?? '').toLowerCase();
        final empId = (s['employeeId'] as String? ?? '').toLowerCase();
        final desig = (s['designation'] as String? ?? '').toLowerCase();
        return name.contains(q) || dept.contains(q) || empId.contains(q) || desig.contains(q);
      }).toList();
    }
    return list;
  }

  int get _activeCount =>
      _staffList.where((s) => (s['status'] as String? ?? 'ACTIVE').toUpperCase() == 'ACTIVE').length;

  Future<void> _deleteStaff(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Staff Member',
            style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, fontSize: 20)),
        content: Text('Remove $name from staff directory? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await StaffApiService.deleteStaff(id);
        _loadStaff();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Removed $name successfully'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete staff: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));

    final filtered = _filteredStaff;
    final depts = _departments;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Metric Strip
          _buildKpiStrip(),
          const SizedBox(height: 14),

          // Search & Action Header
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search staff by name, employee ID, or role…',
                    hintStyle: GoogleFonts.nunitoSans(color: AppColors.textLight, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textLight),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showAddStaffDialog(),
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: Text('Add Staff',
                    style: GoogleFonts.nunitoSans(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Department filter pills
          if (depts.isNotEmpty) ...[
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _deptChip('ALL', 'All Departments (${_staffList.length})'),
                  ...depts.map((d) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _deptChip(d, d),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Staff Cards List
          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('No staff members match the selected filters.',
                    style: GoogleFonts.nunitoSans(color: AppColors.textSecondary)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final staff = filtered[index] as Map<String, dynamic>;
                return _buildStaffCard(staff);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildKpiStrip() {
    return LayoutBuilder(builder: (context, constraints) {
      final isCompact = constraints.maxWidth < 700;
      final kpis = [
        _kpiItem('Total Staff', '${_staffList.length}', Icons.groups_outlined, AppColors.navy),
        _kpiItem('Active Faculty', '$_activeCount', Icons.verified_user_outlined, AppColors.success),
        _kpiItem('Departments', '${_departments.length}', Icons.apartment_outlined, AppColors.info),
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

  Widget _deptChip(String code, String label) {
    final active = _selectedDept == code;
    return GestureDetector(
      onTap: () => setState(() => _selectedDept = code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? AppColors.navy : AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunitoSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff) {
    final id = staff['id'] as String? ?? '';
    final name = staff['fullName'] as String? ?? '';
    final empId = staff['employeeId'] as String? ?? '';
    final dept = staff['department'] as String? ?? '';
    final designation = staff['designation'] as String? ?? '';
    final status = staff['status'] as String? ?? 'ACTIVE';
    final email = staff['email'] as String? ?? '';
    final phone = staff['phone'] as String? ?? '';
    final qualification = staff['qualification'] as String? ?? '';
    final isActive = status.toUpperCase() == 'ACTIVE';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: (isActive ? AppColors.navy : AppColors.error).withValues(alpha: 0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isActive ? AppColors.navy : AppColors.error,
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
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.nunitoSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.nunitoSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isActive ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${designation.isNotEmpty ? designation : 'Staff'} · ${dept.isNotEmpty ? dept : 'General'}${empId.isNotEmpty ? ' · ID: $empId' : ''}',
                  style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                if (qualification.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Qual: $qualification', style: GoogleFonts.nunitoSans(fontSize: 11, color: AppColors.textLight)),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (phone.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_outlined, size: 13, color: AppColors.textLight),
                          const SizedBox(width: 4),
                          Text(phone, style: GoogleFonts.nunitoSans(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    if (email.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.email_outlined, size: 13, color: AppColors.textLight),
                          const SizedBox(width: 4),
                          Text(email, style: GoogleFonts.nunitoSans(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.navy,
                tooltip: 'Edit Details',
                onPressed: () => _showEditStaffDialog(staff),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.error,
                tooltip: 'Delete Staff',
                onPressed: () => _deleteStaff(id, name),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddStaffDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: StaffFormScreen(
            onSaved: () {
              Navigator.pop(ctx);
              _loadStaff();
            },
          ),
        ),
      ),
    );
  }

  void _showEditStaffDialog(Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: StaffFormScreen(
            existingStaff: staff,
            onSaved: () {
              Navigator.pop(ctx);
              _loadStaff();
            },
          ),
        ),
      ),
    );
  }
}
