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

  List<dynamic> get _filteredStaff {
    if (_searchQuery.isEmpty) return _staffList;
    final q = _searchQuery.toLowerCase();
    return _staffList.where((s) {
      final name = (s['fullName'] as String? ?? '').toLowerCase();
      final dept = (s['department'] as String? ?? '').toLowerCase();
      final empId = (s['employeeId'] as String? ?? '').toLowerCase();
      return name.contains(q) || dept.contains(q) || empId.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final filtered = _filteredStaff;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search staff...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onPressed: () => _showAddStaffDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add Staff',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('No staff found.',
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final staff = filtered[index] as Map<String, dynamic>;
                    return _buildStaffTile(staff);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStaffTile(Map<String, dynamic> staff) {
    final name = staff['fullName'] as String? ?? '';
    final empId = staff['employeeId'] as String? ?? '';
    final dept = staff['department'] as String? ?? '';
    final designation = staff['designation'] as String? ?? '';
    final status = staff['status'] as String? ?? 'ACTIVE';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.navy.withOpacity(0.1),
        child: Text(name.isNotEmpty ? name[0] : '?',
            style: const TextStyle(color: AppColors.navy)),
      ),
      title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      subtitle: Text('$empId | $dept | $designation',
          style:
              GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
      trailing: Chip(
        label: Text(status, style: GoogleFonts.poppins(fontSize: 11)),
        backgroundColor: status == 'ACTIVE'
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
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
}
