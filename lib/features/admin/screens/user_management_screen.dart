import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/dio_client.dart';

/// Staff accounts are created and managed by the school admin in FastAPI.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  static const _staffRoles = [
    'SCHOOL_ADMIN',
    'TEACHER',
    'ACCOUNTANT',
    'TRANSPORT_MANAGER',
  ];

  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  String _roleFilter = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await DioClient.get('/users');
      final users = (response.data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) => _staffRoles.contains(item['role']))
          .toList();
      if (mounted) setState(() => _users = users);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'SCHOOL_ADMIN':
        return const Color(0xFF4F46E5); // Indigo
      case 'TEACHER':
        return const Color(0xFF059669); // Emerald
      case 'ACCOUNTANT':
        return const Color(0xFFD97706); // Amber
      case 'TRANSPORT_MANAGER':
        return const Color(0xFF0284C7); // Sky Blue
      default:
        return AppColors.navy;
    }
  }

  IconData _roleIcon(String? role) {
    switch (role) {
      case 'SCHOOL_ADMIN':
        return Icons.admin_panel_settings_outlined;
      case 'TEACHER':
        return Icons.school_outlined;
      case 'ACCOUNTANT':
        return Icons.account_balance_wallet_outlined;
      case 'TRANSPORT_MANAGER':
        return Icons.directions_bus_outlined;
      default:
        return Icons.person_outline;
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchQuery.trim().toLowerCase();
    return _users.where((user) {
      final role = user['role']?.toString() ?? '';
      if (_roleFilter != 'ALL' && role != _roleFilter) return false;

      if (query.isEmpty) return true;
      final text = [
        user['fullName'],
        user['email'],
        user['phone'],
        role,
      ].whereType<String>().join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  Future<void> _edit([Map<String, dynamic>? user]) async {
    final name = TextEditingController(text: user?['fullName']?.toString() ?? '');
    final email = TextEditingController(text: user?['email']?.toString() ?? '');
    final phone = TextEditingController(text: user?['phone']?.toString() ?? '');
    final password = TextEditingController();
    var role = user?['role']?.toString() ?? 'TEACHER';
    var saving = false;
    var obscurePass = true;
    final formKey = GlobalKey<FormState>();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, updateDialog) => AlertDialog(
            title: Text(
              user == null ? 'Add Staff Account' : 'Edit Staff Account',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            content: SizedBox(
              width: 480,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter a full name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: email,
                      decoration: const InputDecoration(
                        labelText: 'Email Address *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => value == null ||
                              !value.contains('@') ||
                              value.trim().endsWith('@')
                          ? 'Enter a valid email address'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(
                        labelText: 'System Role *',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: _staffRoles
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item.replaceAll('_', ' ')),
                              ))
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) => updateDialog(() => role = value ?? role),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: password,
                      decoration: InputDecoration(
                        labelText: user == null
                            ? 'Initial Password *'
                            : 'New Password (leave blank to keep current)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () =>
                              updateDialog(() => obscurePass = !obscurePass),
                        ),
                      ),
                      obscureText: obscurePass,
                      validator: (value) {
                        if (user == null && (value == null || value.isEmpty)) {
                          return 'Enter an initial password';
                        }
                        if (value != null &&
                            value.isNotEmpty &&
                            value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                  ]),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.palette.brand,
                ),
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        updateDialog(() => saving = true);
                        final payload = {
                          'fullName': name.text.trim(),
                          'email': email.text.trim(),
                          'phone': phone.text.trim(),
                          'role': role,
                          'linkedEntityId': null,
                          'extraPermissions':
                              user?['extraPermissions'] ?? <String>[],
                          if (password.text.isNotEmpty) 'password': password.text,
                        };
                        try {
                          if (user == null) {
                            await DioClient.post('/users', data: payload);
                          } else {
                            await DioClient.put('/users/${user['id']}',
                                data: payload);
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          await _load();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(user == null
                                    ? 'Staff account created successfully'
                                    : 'Staff account updated'),
                                backgroundColor: context.palette.brand,
                              ),
                            );
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text('Could not save account: $error'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            updateDialog(() => saving = false);
                          }
                        }
                      },
                child: Text(saving ? 'Saving...' : 'Save Account'),
              ),
            ],
          ),
        ),
      );
    } finally {
      name.dispose();
      email.dispose();
      phone.dispose();
      password.dispose();
    }
  }

  Future<void> _deactivate(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Staff Account?'),
        content: Text(
            '${user['fullName']} will immediately lose access to the administrative portal.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DioClient.delete('/users/${user['id']}');
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff account deactivated'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not deactivate account: $error'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final total = _users.length;
    final admins =
        _users.where((u) => u['role'] == 'SCHOOL_ADMIN').length;
    final teachers =
        _users.where((u) => u['role'] == 'TEACHER').length;
    final operations =
        _users.where((u) => u['role'] == 'ACCOUNTANT' || u['role'] == 'TRANSPORT_MANAGER').length;
    final filtered = _filteredUsers;

    return Scaffold(
      backgroundColor: palette.surface,
      appBar: AppBar(
        title: Text(
          'Staff & Role Management',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh list',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: palette.brand,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => _edit(),
            icon: const Icon(Icons.person_add_rounded, size: 17),
            label: const Text('Add Staff'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    constraints: const BoxConstraints(maxWidth: 460),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded,
                            size: 48,
                            color: AppColors.error.withValues(alpha: 0.8)),
                        const SizedBox(height: 12),
                        Text('Could not load staff accounts',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: palette.brand)),
                        const SizedBox(height: 6),
                        Text('$_error',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunitoSans(
                                color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded, size: 17),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(Responsive.contentPadding(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI Strip
                      LayoutBuilder(builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 650;
                        final cardWidth = isNarrow
                            ? (constraints.maxWidth - 12) / 2
                            : (constraints.maxWidth - 36) / 4;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _kpiCard(
                              title: 'Total Accounts',
                              value: '$total',
                              icon: Icons.people_alt_outlined,
                              color: palette.brand,
                              width: cardWidth,
                              isSelected: _roleFilter == 'ALL',
                              onTap: () => setState(() => _roleFilter = 'ALL'),
                            ),
                            _kpiCard(
                              title: 'School Admins',
                              value: '$admins',
                              icon: Icons.admin_panel_settings_outlined,
                              color: const Color(0xFF4F46E5),
                              width: cardWidth,
                              isSelected: _roleFilter == 'SCHOOL_ADMIN',
                              onTap: () => setState(() => _roleFilter = 'SCHOOL_ADMIN'),
                            ),
                            _kpiCard(
                              title: 'Teachers & Faculty',
                              value: '$teachers',
                              icon: Icons.school_outlined,
                              color: const Color(0xFF059669),
                              width: cardWidth,
                              isSelected: _roleFilter == 'TEACHER',
                              onTap: () => setState(() => _roleFilter = 'TEACHER'),
                            ),
                            _kpiCard(
                              title: 'Finance & Transport',
                              value: '$operations',
                              icon: Icons.engineering_outlined,
                              color: const Color(0xFFD97706),
                              width: cardWidth,
                              isSelected: _roleFilter == 'ACCOUNTANT' || _roleFilter == 'TRANSPORT_MANAGER',
                              onTap: () => setState(() => _roleFilter = 'ACCOUNTANT'),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 18),

                      // Search and Filter Bar
                      Card(
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: palette.border.withValues(alpha: 0.6)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              TextField(
                                onChanged: (val) =>
                                    setState(() => _searchQuery = val),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search by name, email, phone, or role...',
                                  prefixIcon:
                                      const Icon(Icons.search_rounded, size: 20),
                                  isDense: true,
                                  filled: true,
                                  fillColor: palette.surface,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: palette.border
                                            .withValues(alpha: 0.6)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: palette.border
                                            .withValues(alpha: 0.6)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _roleChip('All Roles', 'ALL'),
                                    _roleChip('Administrators', 'SCHOOL_ADMIN',
                                        color: const Color(0xFF4F46E5)),
                                    _roleChip('Teachers', 'TEACHER',
                                        color: const Color(0xFF059669)),
                                    _roleChip('Accountants', 'ACCOUNTANT',
                                        color: const Color(0xFFD97706)),
                                    _roleChip('Transport', 'TRANSPORT_MANAGER',
                                        color: const Color(0xFF0284C7)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Users List
                      if (filtered.isEmpty)
                        Card(
                          elevation: 0.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: palette.border.withValues(alpha: 0.6)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 48),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.person_search_outlined,
                                      size: 54,
                                      color: palette.brand
                                          .withValues(alpha: 0.3)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No staff accounts found',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Try adjusting your search or role filter.',
                                    style: GoogleFonts.nunitoSans(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ...filtered.map((user) => _userCard(user)),
                    ],
                  ),
                ),
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
        padding: const EdgeInsets.all(14),
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
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
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

  Widget _roleChip(String label, String value, {Color? color}) {
    final selected = _roleFilter == value;
    final chipColor = color ?? context.palette.brand;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: chipColor.withValues(alpha: 0.12),
        labelStyle: GoogleFonts.nunitoSans(
          color: selected ? chipColor : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        side: BorderSide(
          color: selected
              ? chipColor
              : context.palette.border.withValues(alpha: 0.6),
        ),
        onSelected: (_) => setState(() => _roleFilter = value),
      ),
    );
  }

  Widget _userCard(Map<String, dynamic> user) {
    final palette = context.palette;
    final fullName = user['fullName']?.toString() ?? 'Staff Member';
    final email = user['email']?.toString() ?? '';
    final phone = user['phone']?.toString() ?? '';
    final role = user['role']?.toString() ?? 'TEACHER';
    final color = _roleColor(role);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Text(
                fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
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
                        fullName,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.brand,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_roleIcon(role), size: 12, color: color),
                            const SizedBox(width: 4),
                            Text(
                              role.replaceAll('_', ' '),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 12,
                    children: [
                      if (email.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.email_outlined,
                                size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              email,
                              style: GoogleFonts.nunitoSans(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      if (phone.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              phone,
                              style: GoogleFonts.nunitoSans(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit details',
              icon: const Icon(Icons.edit_outlined, size: 19),
              onPressed: () => _edit(user),
            ),
            IconButton(
              tooltip: 'Deactivate account',
              icon: const Icon(Icons.person_off_outlined,
                  size: 19, color: AppColors.error),
              onPressed: () => _deactivate(user),
            ),
          ],
        ),
      ),
    );
  }
}
