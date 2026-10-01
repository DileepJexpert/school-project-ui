import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/platform_api_service.dart';

class PlatformDashboardPage extends StatefulWidget {
  const PlatformDashboardPage({super.key});

  @override
  State<PlatformDashboardPage> createState() => _PlatformDashboardPageState();
}

class _PlatformDashboardPageState extends State<PlatformDashboardPage> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _schools = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _loadSchools();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredSchools {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _schools;
    return _schools.where((school) {
      final haystack = [
        school['name'],
        school['tenantId'],
        school['city'],
        school['state'],
        school['adminEmail'],
        school['plan'],
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  int get _activeCount =>
      _schools.where((school) => school['active'] == true).length;

  int get _studentCount => _schools.fold<int>(
        0,
        (sum, school) => sum + ((school['studentCount'] as num?)?.toInt() ?? 0),
      );

  Future<void> _loadSchools() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final schools = await PlatformApiService.getSchools();
      if (mounted) setState(() => _schools = schools);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to load schools. Check the backend.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRouter.login, (_) => false);
    }
  }

  Future<void> _toggleSchool(String tenantId, bool active) async {
    try {
      await PlatformApiService.setSchoolActive(tenantId, active);
      await _loadSchools();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(active ? 'School activated' : 'School deactivated'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update school status')),
      );
    }
  }

  Future<void> _showCreateSchool() async {
    final formKey = GlobalKey<FormState>();
    final code = TextEditingController();
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final city = TextEditingController();
    final state = TextEditingController();
    final board = TextEditingController(text: 'CBSE');

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 4),
        contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add school',
              style: GoogleFonts.nunitoSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create a tenant entry in the platform registry.',
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: Form(
            key: formKey,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DialogField(
                  width: 200,
                  controller: code,
                  label: 'School code',
                  hint: 'demo_school',
                  validator: _tenantValidator,
                ),
                _DialogField(
                  width: 332,
                  controller: name,
                  label: 'School name',
                  validator: _required,
                ),
                _DialogField(
                  width: 270,
                  controller: email,
                  label: 'Admin email',
                  validator: _emailValidator,
                ),
                _DialogField(
                  width: 262,
                  controller: phone,
                  label: 'Phone',
                ),
                _DialogField(
                  width: 270,
                  controller: city,
                  label: 'City',
                ),
                _DialogField(
                  width: 128,
                  controller: state,
                  label: 'State',
                ),
                _DialogField(
                  width: 128,
                  controller: board,
                  label: 'Board',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await PlatformApiService.createSchool({
                'tenantId': code.text.trim().toLowerCase(),
                'name': name.text.trim(),
                'adminEmail': email.text.trim(),
                'phone': phone.text.trim(),
                'city': city.text.trim(),
                'state': state.text.trim(),
                'board': board.text.trim(),
                'plan': 'free',
              });
              if (context.mounted) Navigator.pop(context, true);
            },
            icon: const Icon(Icons.add_business_outlined, size: 18),
            label: const Text('Create school'),
          ),
        ],
      ),
    );

    code.dispose();
    name.dispose();
    email.dispose();
    phone.dispose();
    city.dispose();
    state.dispose();
    board.dispose();

    if (created == true) await _loadSchools();
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  static String? _tenantValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(text)) {
      return 'Use letters, numbers, underscore or dash';
    }
    return null;
  }

  static String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    if (!text.contains('@')) return 'Enter a valid email';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.canvas,
      appBar: AppBar(
        title: const Text('Platform Administration'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadSchools,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                sliver: SliverToBoxAdapter(child: _buildHero(context)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                sliver: SliverToBoxAdapter(child: _buildMetrics(context)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                sliver: SliverToBoxAdapter(child: _buildSchoolsPanel(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: context.palette.heroGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final content = [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Pill(
                    label: 'Owner workspace',
                    color: Colors.white.withValues(alpha: 0.14),
                    textColor: Colors.white,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Manage every school from one clean control center.',
                    style: GoogleFonts.nunitoSans(
                      color: Colors.white,
                      fontSize: compact ? 24 : 32,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create tenants, monitor activation and keep platform access separate from school operations.',
                    style: GoogleFonts.nunitoSans(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18, height: 18),
            FilledButton.icon(
              onPressed: _showCreateSchool,
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Add school'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: context.palette.brand,
                minimumSize: const Size(140, 46),
              ),
            ),
          ];

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content,
            );
          }
          return Row(
              crossAxisAlignment: CrossAxisAlignment.end, children: content);
        },
      ),
    );
  }

  Widget _buildMetrics(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 680
                ? 2
                : 1;
        final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
        final inactive = _schools.length - _activeCount;
        final metrics = [
          _MetricData(
            label: 'Total schools',
            value: '${_schools.length}',
            icon: Icons.apartment_rounded,
            color: context.palette.brand,
          ),
          _MetricData(
            label: 'Active schools',
            value: '$_activeCount',
            icon: Icons.verified_outlined,
            color: AppColors.success,
          ),
          _MetricData(
            label: 'Paused schools',
            value: '$inactive',
            icon: Icons.pause_circle_outline_rounded,
            color: AppColors.warning,
          ),
          _MetricData(
            label: 'Approx. students',
            value: '$_studentCount',
            icon: Icons.groups_2_outlined,
            color: AppColors.info,
          ),
        ];
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: metrics
              .map((metric) => SizedBox(
                    width: width,
                    child: _MetricCard(metric: metric),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildSchoolsPanel(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registered schools',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Search, review and activate tenant accounts.',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search schools',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _buildSchoolsContent(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolsContent(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _StatePanel(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load platform data',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _loadSchools,
      );
    }

    if (_schools.isEmpty) {
      return _StatePanel(
        icon: Icons.add_business_outlined,
        title: 'No schools yet',
        message: 'Create the first school tenant to begin onboarding.',
        actionLabel: 'Add school',
        onAction: _showCreateSchool,
      );
    }

    final schools = _filteredSchools;
    if (schools.isEmpty) {
      return _StatePanel(
        icon: Icons.search_off_rounded,
        title: 'No matching schools',
        message: 'Try a different school name, code, city or plan.',
        actionLabel: 'Clear search',
        onAction: _searchCtrl.clear,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final table = DataTable(
          columnSpacing: 28,
          horizontalMargin: 14,
          columns: const [
            DataColumn(label: Text('School')),
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Plan')),
            DataColumn(label: Text('Students'), numeric: true),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Active')),
          ],
          rows: schools.map((school) {
            final enabled = school['active'] == true;
            final code = school['tenantId']?.toString() ?? '';
            return DataRow(
              cells: [
                DataCell(_SchoolIdentity(school: school)),
                DataCell(Text(code)),
                DataCell(_Pill(
                  label: (school['plan']?.toString() ?? 'free').toUpperCase(),
                  color: context.palette.canvas,
                  textColor: AppColors.textSecondary,
                )),
                DataCell(
                    Text('${(school['studentCount'] as num?)?.toInt() ?? 0}')),
                DataCell(_StatusChip(active: enabled)),
                DataCell(Switch(
                  value: enabled,
                  onChanged: code.isEmpty
                      ? null
                      : (value) => _toggleSchool(code, value),
                )),
              ],
            );
          }).toList(),
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: table,
            ),
          ),
        );
      },
    );
  }
}

class _DialogField extends StatelessWidget {
  final double width;
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;

  const _DialogField({
    required this.width,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: validator,
      ),
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricData metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: metric.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(metric.icon, color: metric.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.value,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    metric.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
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
}

class _SchoolIdentity extends StatelessWidget {
  final Map<String, dynamic> school;

  const _SchoolIdentity({required this.school});

  @override
  Widget build(BuildContext context) {
    final name = school['name']?.toString() ?? 'Unnamed school';
    final adminEmail = school['adminEmail']?.toString();
    final city = school['city']?.toString();
    final state = school['state']?.toString();
    final location = [city, state]
        .where((part) => part != null && part.trim().isNotEmpty)
        .join(', ');

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: context.palette.brand.withValues(alpha: 0.1),
          foregroundColor: context.palette.brand,
          child: Text(name.characters.first.toUpperCase()),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                adminEmail?.isNotEmpty == true
                    ? adminEmail!
                    : location.isNotEmpty
                        ? location
                        : 'Contact not set',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool active;

  const _StatusChip({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.warning;
    return _Pill(
      label: active ? 'Active' : 'Paused',
      color: color.withValues(alpha: 0.1),
      textColor: color,
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Pill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunitoSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      decoration: BoxDecoration(
        color: context.palette.canvas,
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppColors.textLight),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.nunitoSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
