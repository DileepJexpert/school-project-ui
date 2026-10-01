import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/shared_widgets.dart';
import 'fee_collection_screen.dart';
import 'fee_setup_screen.dart';
import 'fee_reports_screen.dart';
import 'outstanding_dues_screen.dart';
import 'transaction_history_screen.dart';

class FeeScreen extends StatefulWidget {
  const FeeScreen({super.key});

  @override
  State<FeeScreen> createState() => _FeeScreenState();
}

class _FeeScreenState extends State<FeeScreen> {
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  bool _loading = true;
  String? _error;
  SchoolSummary? _summary;
  List<StudentFeeProfile> _dues = [];
  List<FeeStructure> _structures = [];

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
      final results = await Future.wait([
        FeeApiService.getSchoolSummary(),
        FeeApiService.getOutstandingDues(),
        FeeApiService.getFeeStructures(year: '2025-2026'),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as SchoolSummary;
        _dues = results[1] as List<StudentFeeProfile>;
        _structures = results[2] as List<FeeStructure>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modules = [
      _FeeModule(
        icon: Icons.point_of_sale_outlined,
        title: 'Collect Fees',
        subtitle: 'Search a student and process fee payments instantly.',
        color: const Color(0xFF059669),
        page: const FeeCollectionScreen(),
      ),
      _FeeModule(
        icon: Icons.settings_applications_outlined,
        title: 'Fee Structure Setup',
        subtitle:
            'Define class-wise fee heads and amounts for each academic year.',
        color: AppColors.info,
        page: const FeeSetupScreen(),
      ),
      _FeeModule(
        icon: Icons.summarize_outlined,
        title: 'Fee Reports',
        subtitle:
            'View collection summaries, dues, and class-wise breakdowns with charts.',
        color: AppColors.warning,
        page: const FeeReportsScreen(),
      ),
      _FeeModule(
        icon: Icons.pending_actions_outlined,
        title: 'Outstanding Dues',
        subtitle:
            'View all students with pending fees, sorted by highest due amount.',
        color: AppColors.error,
        page: const OutstandingDuesScreen(),
      ),
      _FeeModule(
        icon: Icons.receipt_long_outlined,
        title: 'Transaction History',
        subtitle: 'Browse, filter, and export all fee payment transactions.',
        color: const Color(0xFF7C3AED),
        page: const TransactionHistoryScreen(),
      ),
    ];

    return AdminPageScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdminPageHeader(
          title: 'Fee Management Hub',
          subtitle: 'Collect, configure, track and report school fee activity.',
          icon: Icons.account_balance_wallet_outlined,
          actions: [
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadDashboard,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildDashboard(),
        const SizedBox(height: 20),
        Text(
          'Workflows',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final cols = Responsive.isDesktop(context)
              ? 3
              : constraints.maxWidth > 720
                  ? 2
                  : 1;
          final cardW = (constraints.maxWidth - (cols - 1) * 16) / cols;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: modules
                .map((m) => SizedBox(
                      width: cardW,
                      child: _ModuleCard(module: m),
                    ))
                .toList(),
          );
        }),
      ]),
    );
  }

  Widget _buildDashboard() {
    if (_loading) {
      return const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Could not load fee dashboard: $_error',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(onPressed: _loadDashboard, child: const Text('Retry')),
          ]),
        ),
      );
    }

    final summary = _summary;
    final totalCollected = summary?.totalFeesCollected ?? 0;
    final totalDue = summary?.totalFeesDue ??
        _dues.fold<double>(0.0, (sum, profile) => sum + profile.dueFees);
    final transactions = summary?.totalTransactions ?? 0;
    final highDueCount = _dues
        .where((p) => p.totalFees > 0 && (p.dueFees / p.totalFees) >= 0.5)
        .length;
    final missingStructures =
        (SchoolConstants.allClasses.length - _structures.length).clamp(0, 999);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, constraints) {
        final cols = Responsive.isDesktop(context)
            ? 4
            : constraints.maxWidth > 720
                ? 2
                : 1;
        final w = (constraints.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
            width: w,
            child: AdminMetricCard(
              title: 'Total Collected',
              value: _currency.format(totalCollected),
              icon: Icons.account_balance_wallet_rounded,
              color: AppColors.success,
              caption: '$transactions transactions',
            ),
          ),
          SizedBox(
            width: w,
            child: AdminMetricCard(
              title: 'Outstanding Due',
              value: _currency.format(totalDue),
              icon: Icons.pending_actions_rounded,
              color: AppColors.error,
              caption: '${_dues.length} students',
            ),
          ),
          SizedBox(
            width: w,
            child: AdminMetricCard(
              title: 'High Due Risk',
              value: '$highDueCount',
              icon: Icons.priority_high_rounded,
              color: AppColors.warning,
              caption: '50%+ unpaid',
            ),
          ),
          SizedBox(
            width: w,
            child: AdminMetricCard(
              title: 'Fee Structures',
              value: '${_structures.length}',
              icon: Icons.fact_check_outlined,
              color: AppColors.info,
              caption: missingStructures > 0
                  ? '$missingStructures missing'
                  : 'All covered',
            ),
          ),
        ]);
      }),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final attention = _AttentionCard(
          icon: Icons.notifications_active_outlined,
          title: 'Needs Attention',
          lines: [
            '${_dues.length} students have pending dues',
            '$highDueCount students have more than 50% unpaid fees',
            missingStructures > 0
                ? '$missingStructures classes may need fee structures'
                : 'Fee structures look covered for the selected year',
          ],
        );
        final actions = _QuickActionsCard(
          onCollect: () => _open(const FeeCollectionScreen()),
          onDues: () => _open(const OutstandingDuesScreen()),
          onReport: () => _open(const FeeReportsScreen()),
          onSetup: () => _open(const FeeSetupScreen()),
        );
        return compact
            ? Column(children: [attention, const SizedBox(height: 12), actions])
            : Row(children: [
                Expanded(child: attention),
                const SizedBox(width: 12),
                Expanded(child: actions),
              ]);
      }),
    ]);
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page))
        .then((_) => _loadDashboard());
  }
}

class _ModuleCard extends StatelessWidget {
  final _FeeModule module;
  const _ModuleCard({required this.module});

  @override
  Widget build(BuildContext context) {
    return AdminModuleCard(
      icon: module.icon,
      title: module.title,
      subtitle: module.subtitle,
      color: module.color,
      badge: 'Open',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => module.page),
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;

  const _AttentionCard({
    required this.icon,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: AppColors.warning, size: 20),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleSmall),
          ]),
          const SizedBox(height: 10),
          ...lines.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(color: AppColors.textSecondary)),
                      Expanded(
                        child: Text(line,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ]),
              )),
        ]),
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  final VoidCallback onCollect;
  final VoidCallback onDues;
  final VoidCallback onReport;
  final VoidCallback onSetup;

  const _QuickActionsCard({
    required this.onCollect,
    required this.onDues,
    required this.onReport,
    required this.onSetup,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Quick Actions', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ElevatedButton.icon(
              onPressed: onCollect,
              icon: const Icon(Icons.point_of_sale_outlined, size: 17),
              label: const Text('Collect Fee'),
            ),
            OutlinedButton.icon(
              onPressed: onDues,
              icon: const Icon(Icons.pending_actions_outlined, size: 17),
              label: const Text('View Dues'),
            ),
            OutlinedButton.icon(
              onPressed: onReport,
              icon: const Icon(Icons.summarize_outlined, size: 17),
              label: const Text('Reports'),
            ),
            OutlinedButton.icon(
              onPressed: onSetup,
              icon: const Icon(Icons.settings_applications_outlined, size: 17),
              label: const Text('Setup'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _FeeModule {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget page;
  const _FeeModule({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.page,
  });
}
