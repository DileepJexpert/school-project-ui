import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../services/staff_api_service.dart';
import 'staff_form_screen.dart';

class StaffListScreen extends StatefulWidget {
  final String? initialCategory;

  const StaffListScreen({super.key, this.initialCategory});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  bool _loading = true;
  List<dynamic> _staffList = [];
  String _searchQuery = '';
  late String _selectedCategory;
  String _selectedDept = 'ALL';

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'ALL';
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

  List<String> get _departments {
    final depts = <String>{};
    for (final s in _staffList) {
      final d = (s['department'] as String? ?? '').trim();
      if (d.isNotEmpty) depts.add(d);
    }
    return depts.toList()..sort();
  }

  int _categoryCount(String catCode) {
    if (catCode == 'ALL') return _staffList.length;
    return _staffList
        .where((s) => (s['category'] as String? ?? '').toUpperCase() == catCode)
        .length;
  }

  List<dynamic> get _filteredStaff {
    var list = _staffList;
    if (_selectedCategory != 'ALL') {
      list = list
          .where((s) => (s['category'] as String? ?? '').toUpperCase() == _selectedCategory)
          .toList();
    }
    if (_selectedDept != 'ALL') {
      list = list
          .where((s) => (s['department'] as String? ?? '').trim() == _selectedDept)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) {
        final name = (s['fullName'] as String? ?? '').toLowerCase();
        final dept = (s['department'] as String? ?? '').toLowerCase();
        final empId = (s['employeeId'] as String? ?? '').toLowerCase();
        final desig = (s['designation'] as String? ?? '').toLowerCase();
        final cat = (s['category'] as String? ?? '').toLowerCase();
        return name.contains(q) ||
            dept.contains(q) ||
            empId.contains(q) ||
            desig.contains(q) ||
            cat.contains(q);
      }).toList();
    }
    return list;
  }

  int get _activeCount => _staffList
      .where((s) => (s['status'] as String? ?? 'ACTIVE').toUpperCase() == 'ACTIVE')
      .length;

  double get _totalSalary => _staffList.fold(
      0.0, (acc, s) => acc + ((s['basicSalary'] as num?)?.toDouble() ?? 0.0));

  Future<void> _deleteStaff(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Staff Member',
            style: GoogleFonts.cormorantGaramond(
                fontWeight: FontWeight.w700, fontSize: 20)),
        content: Text('Remove $name from staff directory? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
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
            SnackBar(
                content: Text('Removed $name successfully'),
                backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to delete staff: $e'),
                backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator()));
    }

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
                    hintText: 'Search staff by name, category, role, or employee ID…',
                    hintStyle: GoogleFonts.nunitoSans(
                        color: AppColors.textLight, fontSize: 13),
                    prefixIcon:
                        const Icon(Icons.search, size: 18, color: AppColors.textLight),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showAddStaffDialog(),
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: Text('Add Staff',
                    style: GoogleFonts.nunitoSans(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Primary Category Filter Chips
          _buildCategoryFilterBar(),
          const SizedBox(height: 10),

          // Department filter pills (secondary)
          if (depts.isNotEmpty) ...[
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _deptChip('ALL', 'All Depts'),
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
                child: Column(
                  children: [
                    const Icon(Icons.person_search_outlined,
                        size: 48, color: AppColors.textLight),
                    const SizedBox(height: 10),
                    Text('No staff members match the selected category & filters.',
                        style: GoogleFonts.nunitoSans(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategory = 'ALL';
                          _selectedDept = 'ALL';
                          _searchQuery = '';
                        });
                      },
                      child: const Text('Reset Filters'),
                    ),
                  ],
                ),
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
      final isCompact = constraints.maxWidth < 800;
      final kpis = [
        _kpiItem('Total Staff', '${_staffList.length}',
            Icons.groups_outlined, AppColors.navy),
        _kpiItem('Active Staff', '$_activeCount',
            Icons.verified_user_outlined, AppColors.success),
        _kpiItem('Monthly Payroll', '₹${_formatNum(_totalSalary)}',
            Icons.payments_outlined, const Color(0xFF6366F1)),
        _kpiItem('Departments', '${_departments.length}',
            Icons.apartment_outlined, AppColors.info),
      ];

      if (isCompact) {
        return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kpis
                .map((k) => SizedBox(
                    width: (constraints.maxWidth - 8) / 2, child: k))
                .toList());
      }
      return Row(
          children: kpis
              .map((k) => Expanded(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: k)))
              .toList());
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
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(val,
                    style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: color)),
                Text(title,
                    style: GoogleFonts.nunitoSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterBar() {
    final categories = [
      {'code': 'ALL', 'label': 'All Staff', 'icon': Icons.groups_outlined, 'color': AppColors.navy},
      {'code': 'TEACHER', 'label': 'Teachers', 'icon': Icons.school_outlined, 'color': const Color(0xFF2563EB)},
      {'code': 'DRIVER', 'label': 'Drivers & Transport', 'icon': Icons.directions_bus_filled_outlined, 'color': const Color(0xFFD97706)},
      {'code': 'PEON', 'label': 'Peons & Support', 'icon': Icons.cleaning_services_outlined, 'color': const Color(0xFF0D9488)},
      {'code': 'ADMIN', 'label': 'Administration', 'icon': Icons.admin_panel_settings_outlined, 'color': const Color(0xFF7C3AED)},
      {'code': 'ACCOUNTANT', 'label': 'Accounts', 'icon': Icons.account_balance_outlined, 'color': const Color(0xFF059669)},
      {'code': 'SECURITY', 'label': 'Security', 'icon': Icons.shield_outlined, 'color': const Color(0xFF475569)},
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final code = cat['code'] as String;
          final label = cat['label'] as String;
          final icon = cat['icon'] as IconData;
          final color = cat['color'] as Color;
          final isSelected = _selectedCategory == code;
          final count = _categoryCount(code);

          return InkWell(
            onTap: () => setState(() => _selectedCategory = code),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? color : color.withValues(alpha: 0.3),
                  width: isSelected ? 1.5 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: isSelected ? Colors.white : color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.25)
                          : color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : color,
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

  Widget _deptChip(String code, String label) {
    final active = _selectedDept == code;
    return GestureDetector(
      onTap: () => setState(() => _selectedDept = code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppColors.navy : AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunitoSans(
            fontSize: 11,
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
    final category = (staff['category'] as String? ?? 'OTHER').toUpperCase();
    final basicSalary = (staff['basicSalary'] as num?)?.toDouble() ?? 0.0;
    final status = staff['status'] as String? ?? 'ACTIVE';
    final email = staff['email'] as String? ?? '';
    final phone = staff['phone'] as String? ?? '';
    final qualification = staff['qualification'] as String? ?? '';
    final isActive = status.toUpperCase() == 'ACTIVE';

    final catColor = _categoryColor(category);
    final catIcon = _categoryIcon(category);
    final catLabel = _categoryLabel(category);

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
            backgroundColor: catColor.withValues(alpha: 0.12),
            child: Icon(catIcon, color: catColor, size: 22),
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
                        style: GoogleFonts.nunitoSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy),
                      ),
                    ),
                    // Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: catColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(catIcon, size: 12, color: catColor),
                          const SizedBox(width: 4),
                          Text(
                            catLabel,
                            style: GoogleFonts.nunitoSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: catColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isActive ? AppColors.success : AppColors.error)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
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
                const SizedBox(height: 4),
                // Designation, Department, ID, Salary badge
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${designation.isNotEmpty ? designation : 'Staff'} · ${dept.isNotEmpty ? dept : 'General'}${empId.isNotEmpty ? ' · ID: $empId' : ''}',
                      style: GoogleFonts.nunitoSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '₹${_formatNum(basicSalary)} / mo',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
                if (qualification.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text('Qualification: $qualification',
                      style: GoogleFonts.nunitoSans(
                          fontSize: 11, color: AppColors.textLight)),
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
                          const Icon(Icons.phone_outlined,
                              size: 13, color: AppColors.textLight),
                          const SizedBox(width: 4),
                          Text(phone,
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    if (email.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.email_outlined,
                              size: 13, color: AppColors.textLight),
                          const SizedBox(width: 4),
                          Text(email,
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 11, color: AppColors.textSecondary)),
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
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
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
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
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

  String _formatNum(double val) {
    if (val >= 100000) {
      return '${(val / 100000).toStringAsFixed(val % 100000 == 0 ? 0 : 2)} L';
    }
    return val.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))(\.\d+)?'),
          (Match m) => '${m[1]},',
        );
  }

  static Color _categoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'TEACHER':
        return const Color(0xFF2563EB); // Royal Blue
      case 'DRIVER':
        return const Color(0xFFD97706); // Amber
      case 'PEON':
        return const Color(0xFF0D9488); // Teal
      case 'ADMIN':
        return const Color(0xFF7C3AED); // Purple
      case 'ACCOUNTANT':
        return const Color(0xFF059669); // Emerald
      case 'SECURITY':
        return const Color(0xFF475569); // Slate
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  static IconData _categoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'TEACHER':
        return Icons.school_outlined;
      case 'DRIVER':
        return Icons.directions_bus_filled_outlined;
      case 'PEON':
        return Icons.cleaning_services_outlined;
      case 'ADMIN':
        return Icons.admin_panel_settings_outlined;
      case 'ACCOUNTANT':
        return Icons.account_balance_outlined;
      case 'SECURITY':
        return Icons.shield_outlined;
      default:
        return Icons.badge_outlined;
    }
  }

  static String _categoryLabel(String category) {
    switch (category.toUpperCase()) {
      case 'TEACHER':
        return 'Teacher';
      case 'DRIVER':
        return 'Driver';
      case 'PEON':
        return 'Peon / Support';
      case 'ADMIN':
        return 'Admin';
      case 'ACCOUNTANT':
        return 'Accountant';
      case 'SECURITY':
        return 'Security';
      default:
        return 'Staff';
    }
  }
}
