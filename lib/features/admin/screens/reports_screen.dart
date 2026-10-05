import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';
import '../../../services/csv_export_service.dart';
import '../../../services/receipt_print_service.dart';
import '../../../services/whatsapp_share_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _currency = NumberFormat.currency(symbol: '\u20B9', decimalDigits: 0);
  final _dateFmt = DateFormat('dd MMM yyyy');
  final _shortFmt = DateFormat('dd MMM');

  SchoolSummary? _summary;
  FeeReportResponse? _feeReport;
  List<StudentFeeProfile> _dues = [];
  List<Expense> _expenses = [];

  bool _loading = true;
  String? _error;

  // Granular Filter States
  String _datePreset = 'All Time';
  DateTimeRange? _customRange;
  String _classSearch = '';
  String _classSortBy = 'dueDesc'; // 'dueDesc', 'collectedDesc', 'pctAsc', 'name'
  String _defaulterSearch = '';
  String _defaulterClassFilter = 'All Classes';
  String _txnSearch = '';
  String _txnModeFilter = 'All';

  final _defaulterSearchCtrl = TextEditingController();
  final _txnSearchCtrl = TextEditingController();

  static const _datePresets = [
    'All Time',
    'This Year',
    'This Quarter',
    'This Month',
    'Last 30 Days',
    'Custom Range'
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _defaulterSearchCtrl.addListener(() {
      setState(() => _defaulterSearch = _defaulterSearchCtrl.text.trim().toLowerCase());
    });
    _txnSearchCtrl.addListener(() {
      setState(() => _txnSearch = _txnSearchCtrl.text.trim().toLowerCase());
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _defaulterSearchCtrl.dispose();
    _txnSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    DateTimeRange? range = _calcRangeForPreset(_datePreset);
    final startStr = range?.start.toIso8601String().substring(0, 10);
    final endStr = range?.end.toIso8601String().substring(0, 10);

    try {
      final results = await Future.wait([
        FeeApiService.getSchoolSummary(),
        FeeApiService.getFeeReport(startDate: startStr, endDate: endStr),
        FeeApiService.getOutstandingDues(),
        FeeApiService.getExpenses(from: startStr, to: endStr).catchError((_) => <Expense>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _summary = results[0] as SchoolSummary;
        _feeReport = results[1] as FeeReportResponse;
        _dues = results[2] as List<StudentFeeProfile>;
        _expenses = results[3] as List<Expense>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTimeRange? _calcRangeForPreset(String preset) {
    final now = DateTime.now();
    return switch (preset) {
      'This Month' => DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        ),
      'Last 30 Days' => DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        ),
      'This Quarter' => DateTimeRange(
          start: DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1),
          end: now,
        ),
      'This Year' => DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: now,
        ),
      'Custom Range' => _customRange,
      _ => null, // All Time
    };
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
                  primary: context.palette.brand,
                  surface: context.palette.surface,
                ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
              child: child!,
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _customRange = picked;
        _datePreset = 'Custom Range';
      });
      _loadAllData();
    }
  }

  void _onPresetChanged(String preset) {
    if (preset == 'Custom Range') {
      _pickCustomRange();
      return;
    }
    setState(() => _datePreset = preset);
    _loadAllData();
  }

  // ─── Export Utilities ────────────────────────────────────────────────────────
  void _exportClassReportCsv(List<_ClassMatrixItem> list) {
    if (list.isEmpty) return;
    final headers = [
      'Class Name',
      'Enrolled Students',
      'Total Demand',
      'Total Collected',
      'Collection %',
      'Outstanding Dues',
      'Discounts Given',
      'Defaulter Count',
      'Status'
    ];
    final rows = list
        .map((item) => [
              item.className,
              '${item.enrolled}',
              item.demand.toStringAsFixed(0),
              item.collected.toStringAsFixed(0),
              '${item.collectionRate.toStringAsFixed(1)}%',
              item.due.toStringAsFixed(0),
              item.discount.toStringAsFixed(0),
              '${item.defaultersCount}',
              item.healthStatus,
            ])
        .toList();
    CsvExportService.exportCustomCsv(
      filename: 'class_wise_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      headers: headers,
      rows: rows,
    );
    _showToast('Class-wise report downloaded as CSV');
  }

  void _exportDefaultersCsv(List<StudentFeeProfile> list) {
    if (list.isEmpty) return;
    final headers = [
      'Admission No',
      'Student Name',
      'Class',
      'Roll Number',
      'Parent Contact',
      'Total Fees',
      'Paid Fees',
      'Outstanding Due',
      'Last Payment Date',
    ];
    final rows = list
        .map((s) => [
              s.id,
              s.name,
              s.className,
              s.rollNumber,
              s.parentPhone,
              s.totalFees.toStringAsFixed(0),
              s.paidFees.toStringAsFixed(0),
              s.dueFees.toStringAsFixed(0),
              s.lastPayment != null ? _dateFmt.format(s.lastPayment!.paymentDate) : 'Never',
            ])
        .toList();
    CsvExportService.exportCustomCsv(
      filename: 'fee_defaulters_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      headers: headers,
      rows: rows,
    );
    _showToast('Defaulters list exported as CSV');
  }

  void _exportTransactionsCsv(List<TransactionRecord> list) {
    if (list.isEmpty) return;
    final headers = [
      'Receipt No',
      'Payment Date',
      'Student Name',
      'Class',
      'Roll No',
      'Installment',
      'Gross Amount',
      'Discount',
      'Net Paid',
      'Payment Mode',
      'Recorded By',
    ];
    final rows = list
        .map((t) => [
              t.receiptNumber,
              _dateFmt.format(t.paymentDate),
              t.studentName,
              t.className,
              t.rollNumber,
              t.paidForMonths.join('; '),
              (t.amountPaid + t.discount).toStringAsFixed(0),
              t.discount.toStringAsFixed(0),
              t.amountPaid.toStringAsFixed(0),
              t.paymentMode,
              t.collectedBy,
            ])
        .toList();
    CsvExportService.exportCustomCsv(
      filename: 'transactions_ledger_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      headers: headers,
      rows: rows,
    );
    _showToast('Transaction audit ledger exported as CSV');
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ─── WhatsApp Fee Reminder ───────────────────────────────────────────────────
  void _openWhatsAppReminder(StudentFeeProfile student) {
    final phoneCtrl = TextEditingController(text: student.parentPhone);
    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Send Fee Due Reminder',
                      style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, fontSize: 18)),
                  Text('${student.name} • ${student.className}',
                      style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Outstanding Amount',
                        style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(_currency.format(student.dueFees),
                        style: GoogleFonts.nunitoSans(
                            fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.error)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Parent WhatsApp Mobile',
                  hintText: 'e.g. 9876543210',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF25D366)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Send Reminder'),
            onPressed: () {
              Navigator.pop(dlgContext);
              final pending = student.feeInstallments
                  .where((i) => i.status != 'PAID')
                  .map((i) => i.installmentName)
                  .toList();
              WhatsAppShareService.shareFeeDueReminder(
                schoolName: AppStrings.schoolName,
                studentName: student.name,
                className: student.className,
                rollNumber: student.rollNumber,
                dueAmount: student.dueFees,
                pendingInstallments: pending,
                parentPhone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Build Screen ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'School Reports & Financial Intelligence',
            subtitle:
                'Multi-dimensional operational analytics across class performance, collections, dues and transactions.',
            icon: Icons.analytics_outlined,
            actions: [
              OutlinedButton.icon(
                onPressed: _loading ? null : _loadAllData,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Date Preset & Filter Header Row
          _buildFilterBar(),
          const SizedBox(height: 14),

          // Granular Tabs
          Container(
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              border: Border.all(color: context.palette.border),
            ),
            child: TabBar(
              controller: _tabCtrl,
              labelColor: context.palette.brand,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: context.palette.brand,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.nunitoSans(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Executive Overview'),
                Tab(icon: Icon(Icons.class_outlined, size: 18), text: 'Class-wise Matrix'),
                Tab(icon: Icon(Icons.warning_amber_rounded, size: 18), text: 'Dues & Defaulters'),
                Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Transaction Ledger'),
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (_loading)
            const SizedBox(
              height: 380,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _errorState()
          else
            _buildTabContent(),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: context.palette.brand),
                const SizedBox(width: 8),
                Text('Period Filter:',
                    style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 10),
                Wrap(
                  spacing: 6,
                  children: _datePresets.map((preset) {
                    final selected = _datePreset == preset;
                    return ChoiceChip(
                      label: Text(preset),
                      labelStyle: GoogleFonts.nunitoSans(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? Colors.white : AppColors.textSecondary,
                      ),
                      selected: selected,
                      selectedColor: context.palette.brand,
                      backgroundColor: context.palette.surface,
                      showCheckmark: false,
                      onSelected: (_) => _onPresetChanged(preset),
                    );
                  }).toList(),
                ),
              ],
            ),
            if (_calcRangeForPreset(_datePreset) != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.palette.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSM),
                  border: Border.all(color: context.palette.brand.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '${_shortFmt.format(_calcRangeForPreset(_datePreset)!.start)} - ${_shortFmt.format(_calcRangeForPreset(_datePreset)!.end)}',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 12, fontWeight: FontWeight.w700, color: context.palette.brand),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return AnimatedBuilder(
      animation: _tabCtrl,
      builder: (context, _) {
        return switch (_tabCtrl.index) {
          0 => _buildExecutiveOverviewTab(),
          1 => _buildClassWiseMatrixTab(),
          2 => _buildDuesDefaultersTab(),
          3 => _buildTransactionLedgerTab(),
          _ => _buildExecutiveOverviewTab(),
        };
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 1: EXECUTIVE OVERVIEW
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildExecutiveOverviewTab() {
    final s = _summary!;
    final totalDemand = s.totalFeesCollected + s.totalFeesDue;
    final coverage = totalDemand <= 0 ? 0.0 : s.totalFeesCollected / totalDemand;
    final averageTxn = s.totalTransactions == 0 ? 0.0 : s.totalFeesCollected / s.totalTransactions;
    final totalExpenses = _expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final netCashflow = s.totalFeesCollected - totalExpenses;
    final defaultersCount = _dues.length;
    final defaulterRate = s.totalStudents == 0 ? 0.0 : (defaultersCount / s.totalStudents * 100);

    final monthly = s.monthlyCollections;
    final peak = monthly.isEmpty ? null : monthly.reduce((a, b) => a.amount >= b.amount ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 8 Key Executive KPIs
        LayoutBuilder(builder: (context, constraints) {
          final columns = Responsive.isDesktop(context)
              ? 4
              : constraints.maxWidth > 700
                  ? 2
                  : 1;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          final kpis = [
            AdminMetricCard(
              title: 'Total Enrolled',
              value: '${s.totalStudents}',
              icon: Icons.people_alt_outlined,
              color: context.palette.brand,
              caption: '${s.enrollmentByClass.length} active classes',
            ),
            AdminMetricCard(
              title: 'Total Fee Demand',
              value: _currency.format(totalDemand),
              icon: Icons.account_balance_outlined,
              color: AppColors.info,
              caption: 'Assessed for all students',
            ),
            AdminMetricCard(
              title: 'Collected Revenue',
              value: _currency.format(s.totalFeesCollected),
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.success,
              caption: '${(coverage * 100).toStringAsFixed(1)}% collected (${s.totalTransactions} txns)',
            ),
            AdminMetricCard(
              title: 'Outstanding Dues',
              value: _currency.format(s.totalFeesDue),
              icon: Icons.pending_actions_outlined,
              color: AppColors.error,
              caption: '$defaultersCount defaulter(s) (${defaulterRate.toStringAsFixed(1)}%)',
            ),
            AdminMetricCard(
              title: 'Discounts / Waivers',
              value: _currency.format(s.totalDiscountGiven),
              icon: Icons.discount_outlined,
              color: AppColors.warning,
              caption: 'Total concessions awarded',
            ),
            AdminMetricCard(
              title: 'Recorded Expenses',
              value: _currency.format(totalExpenses),
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFF8B5CF6),
              caption: '${_expenses.length} expense record(s)',
            ),
            AdminMetricCard(
              title: 'Net Cashflow',
              value: _currency.format(netCashflow),
              icon: Icons.trending_up_rounded,
              color: netCashflow >= 0 ? AppColors.success : AppColors.error,
              caption: 'Collected minus expenses',
            ),
            AdminMetricCard(
              title: 'Avg Collection / Student',
              value: _currency.format(s.totalStudents > 0 ? s.totalFeesCollected / s.totalStudents : 0),
              icon: Icons.calculate_outlined,
              color: context.palette.brand,
              caption: 'Avg txn: ${_currency.format(averageTxn)}',
            ),
          ];

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: kpis.map((card) => SizedBox(width: width, child: card)).toList(),
          );
        }),
        const SizedBox(height: 18),

        // Collection Health Gauge Bar
        _buildCollectionProgressBar(s, totalDemand, coverage),
        const SizedBox(height: 18),

        // Monthly Collection Trend BarChart
        _monthlyCollectionCard(monthly, peak),
        const SizedBox(height: 18),

        // 3-Column Breakdown (Financial Balance, Enrollment Mix, Payment Channels)
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth > 960;
          if (!wide) {
            return Column(children: [
              _buildNetOperatingCard(s.totalFeesCollected, totalExpenses, netCashflow),
              const SizedBox(height: 16),
              _enrollmentCard(s),
              const SizedBox(height: 16),
              _paymentModesCard(s),
            ]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildNetOperatingCard(s.totalFeesCollected, totalExpenses, netCashflow)),
              const SizedBox(width: 16),
              Expanded(child: _enrollmentCard(s)),
              const SizedBox(width: 16),
              Expanded(child: _paymentModesCard(s)),
            ],
          );
        }),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildCollectionProgressBar(SchoolSummary s, double totalDemand, double coverage) {
    final duePct = totalDemand <= 0 ? 0.0 : s.totalFeesDue / totalDemand;
    final discPct = totalDemand <= 0 ? 0.0 : s.totalDiscountGiven / totalDemand;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.donut_large_rounded, color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Text('Fee Demand & Recovery Progress',
                      style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w800, fontSize: 14)),
                ]),
                Text('Recovery Rate: ${(coverage * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.success)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    if (coverage > 0)
                      Expanded(
                        flex: (coverage * 1000).toInt(),
                        child: Container(color: AppColors.success),
                      ),
                    if (duePct > 0)
                      Expanded(
                        flex: (duePct * 1000).toInt(),
                        child: Container(color: AppColors.error),
                      ),
                    if (discPct > 0)
                      Expanded(
                        flex: (discPct * 1000).toInt(),
                        child: Container(color: AppColors.warning),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _progressLegend('Collected', _currency.format(s.totalFeesCollected),
                    '${(coverage * 100).toStringAsFixed(1)}%', AppColors.success),
                _progressLegend('Outstanding Dues', _currency.format(s.totalFeesDue),
                    '${(duePct * 100).toStringAsFixed(1)}%', AppColors.error),
                _progressLegend('Discounts Awarded', _currency.format(s.totalDiscountGiven),
                    '${(discPct * 100).toStringAsFixed(1)}%', AppColors.warning),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressLegend(String label, String amount, String pct, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.nunitoSans(fontSize: 11, color: AppColors.textSecondary)),
            Text('$amount ($pct)',
                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w800, fontSize: 12, color: color)),
          ],
        ),
      ],
    );
  }

  Widget _buildNetOperatingCard(double collected, double expenses, double net) {
    final margin = collected <= 0 ? 0.0 : (net / collected * 100);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cardHeader(
            title: 'Operating Financial Balance',
            subtitle: 'Fee collections vs institutional expenses',
            icon: Icons.account_balance_rounded,
            color: context.palette.brand,
          ),
          const SizedBox(height: 16),
          _progressRow(
            label: 'Total Fee Revenue',
            value: collected,
            percent: 1.0,
            color: AppColors.success,
          ),
          const SizedBox(height: 12),
          _progressRow(
            label: 'Recorded Operating Expenses',
            value: expenses,
            percent: collected <= 0 ? 0.0 : (expenses / collected).clamp(0.0, 1.0),
            color: const Color(0xFF8B5CF6),
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Net Surplus / Balance',
                    style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.textSecondary)),
                Text(_currency.format(net),
                    style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: net >= 0 ? AppColors.success : AppColors.error)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (net >= 0 ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSM),
                ),
                child: Text(
                  '${margin.toStringAsFixed(1)}% Operating Margin',
                  style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: net >= 0 ? AppColors.success : AppColors.error),
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _monthlyCollectionCard(List<MonthlyFeeSummary> monthly, MonthlyFeeSummary? peak) {
    final maxAmount = monthly.isEmpty
        ? 1.0
        : monthly.map((item) => item.amount).reduce((a, b) => a > b ? a : b);
    final axisInterval = maxAmount <= 0 ? 1.0 : maxAmount / 4;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _cardHeader(
                title: 'Monthly Collection Trend',
                subtitle: monthly.isEmpty
                    ? 'No payment records found'
                    : '${monthly.length} month(s) tracked • Peak in ${peak?.label ?? 'N/A'}',
                icon: Icons.bar_chart_rounded,
                color: context.palette.brand,
              ),
              if (peak != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSM),
                  ),
                  child: Text(
                    'Peak: ${_currency.format(peak.amount)}',
                    style: GoogleFonts.nunitoSans(
                        fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.warning),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (monthly.isEmpty)
            _noData('No payment transactions recorded yet')
          else
            SizedBox(
              height: 260,
              child: BarChart(
                BarChartData(
                  maxY: maxAmount <= 0 ? 1 : maxAmount * 1.25,
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: axisInterval,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: AppColors.border, strokeWidth: 1),
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 58,
                        interval: axisInterval,
                        getTitlesWidget: (value, _) => Text(
                          _shortMoney(value),
                          style: GoogleFonts.nunitoSans(color: AppColors.textLight, fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index < 0 || index >= monthly.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              monthly[index].label,
                              style: GoogleFonts.nunitoSans(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: monthly.asMap().entries.map((entry) {
                    final item = entry.value;
                    final isPeak = item.amount == maxAmount;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: item.amount,
                          width: 20,
                          color: isPeak ? AppColors.warning : context.palette.brand,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _enrollmentCard(SchoolSummary summary) {
    final entries = summary.enrollmentByClass.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);
    final colors = [
      context.palette.brand,
      AppColors.info,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      const Color(0xFF7C3AED),
      const Color(0xFFEC4899),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cardHeader(
            title: 'Enrollment Distribution',
            subtitle: '$total active students across ${entries.length} classes',
            icon: Icons.groups_outlined,
            color: AppColors.info,
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            _noData('No student records found')
          else ...[
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 32,
                  sections: entries.asMap().entries.map((entry) {
                    final percent = total <= 0 ? 0.0 : entry.value.value / total * 100;
                    return PieChartSectionData(
                      value: entry.value.value.toDouble(),
                      color: colors[entry.key % colors.length],
                      title: '${percent.toStringAsFixed(0)}%',
                      radius: 56,
                      titleStyle: GoogleFonts.nunitoSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...entries.take(5).toList().asMap().entries.map((entry) {
              final color = colors[entry.key % colors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _legendRow(entry.value.key, '${entry.value.value} students', color),
              );
            }),
          ],
        ]),
      ),
    );
  }

  Widget _paymentModesCard(SchoolSummary summary) {
    final modes = summary.paymentModeSummary;
    final total = modes.fold<double>(0, (sum, mode) => sum + mode.totalAmount);
    final colors = {
      'CASH': AppColors.success,
      'CHEQUE': AppColors.info,
      'DIGITAL_PAYMENT': context.palette.brand,
      'CHALLAN': AppColors.warning,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cardHeader(
            title: 'Payment Channels',
            subtitle: 'Collection method distribution',
            icon: Icons.payments_outlined,
            color: AppColors.warning,
          ),
          const SizedBox(height: 16),
          if (modes.isEmpty)
            _noData('No payment mode data')
          else
            ...modes.map((mode) {
              final percent = total <= 0 ? 0.0 : mode.totalAmount / total;
              final color = colors[mode.paymentMode.toUpperCase()] ?? AppColors.info;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _progressRow(
                  label: _modeLabel(mode.paymentMode),
                  value: mode.totalAmount,
                  percent: percent,
                  color: color,
                ),
              );
            }),
        ]),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 2: CLASS-WISE GRANULAR MATRIX
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildClassWiseMatrixTab() {
    final classList = _buildClassMatrixList();

    // Filter
    final filtered = classList.where((item) {
      if (_classSearch.isEmpty) return true;
      return item.className.toLowerCase().contains(_classSearch);
    }).toList();

    // Sort
    if (_classSortBy == 'dueDesc') {
      filtered.sort((a, b) => b.due.compareTo(a.due));
    } else if (_classSortBy == 'collectedDesc') {
      filtered.sort((a, b) => b.collected.compareTo(a.collected));
    } else if (_classSortBy == 'pctAsc') {
      filtered.sort((a, b) => a.collectionRate.compareTo(b.collectionRate));
    } else if (_classSortBy == 'name') {
      filtered.sort((a, b) => a.className.compareTo(b.className));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls Row
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search class by name...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                    ),
                    onChanged: (val) => setState(() => _classSearch = val.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _classSortBy,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'dueDesc', child: Text('Sort: Highest Dues')),
                    DropdownMenuItem(value: 'collectedDesc', child: Text('Sort: Highest Collections')),
                    DropdownMenuItem(value: 'pctAsc', child: Text('Sort: Lowest Collection %')),
                    DropdownMenuItem(value: 'name', child: Text('Sort: Class Name')),
                  ],
                  onChanged: (v) => setState(() => _classSortBy = v ?? 'dueDesc'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.palette.brand,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export CSV'),
                  onPressed: () => _exportClassReportCsv(filtered),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Class Matrix Table
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(context.palette.surface),
              columns: const [
                DataColumn(label: Text('Class Name')),
                DataColumn(label: Text('Students'), numeric: true),
                DataColumn(label: Text('Fee Demand'), numeric: true),
                DataColumn(label: Text('Collected'), numeric: true),
                DataColumn(label: Text('Recovery Rate')),
                DataColumn(label: Text('Outstanding Dues'), numeric: true),
                DataColumn(label: Text('Discounts'), numeric: true),
                DataColumn(label: Text('Defaulters'), numeric: true),
                DataColumn(label: Text('Status')),
              ],
              rows: filtered.map((c) {
                final color = c.collectionRate >= 80
                    ? AppColors.success
                    : c.collectionRate >= 50
                        ? AppColors.warning
                        : AppColors.error;

                return DataRow(cells: [
                  DataCell(Text(c.className,
                      style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w800, fontSize: 13))),
                  DataCell(Text('${c.enrolled}')),
                  DataCell(Text(_currency.format(c.demand))),
                  DataCell(Text(_currency.format(c.collected),
                      style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, color: AppColors.success))),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text('${c.collectionRate.toStringAsFixed(1)}%',
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w800, color: color, fontSize: 12)),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (c.collectionRate / 100).clamp(0, 1),
                            minHeight: 6,
                            backgroundColor: color.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ),
                    ],
                  )),
                  DataCell(Text(
                    _currency.format(c.due),
                    style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w800,
                      color: c.due > 0 ? AppColors.error : AppColors.textSecondary,
                    ),
                  )),
                  DataCell(Text(c.discount > 0 ? _currency.format(c.discount) : '-')),
                  DataCell(Text(
                    '${c.defaultersCount}',
                    style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w700,
                      color: c.defaultersCount > 0 ? AppColors.error : AppColors.textLight,
                    ),
                  )),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusSM),
                    ),
                    child: Text(c.healthStatus,
                        style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w800, fontSize: 11, color: color)),
                  )),
                ]);
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  List<_ClassMatrixItem> _buildClassMatrixList() {
    final s = _summary!;
    final classSummaries = _feeReport?.classSummaries ?? [];
    final classMap = <String, _ClassMatrixItem>{};

    // 1. Seed with enrolled classes
    for (final e in s.enrollmentByClass.entries) {
      classMap[e.key] = _ClassMatrixItem(
        className: e.key,
        enrolled: e.value,
        collected: 0,
        due: 0,
        discount: 0,
        defaultersCount: 0,
      );
    }

    // 2. Add collected amounts from report
    for (final cs in classSummaries) {
      final existing = classMap[cs.className];
      if (existing != null) {
        existing.collected += cs.totalCollected;
        existing.discount += cs.totalDiscount;
      } else {
        classMap[cs.className] = _ClassMatrixItem(
          className: cs.className,
          enrolled: 0,
          collected: cs.totalCollected,
          due: 0,
          discount: cs.totalDiscount,
          defaultersCount: 0,
        );
      }
    }

    // 3. Add dues & defaulter counts
    for (final d in _dues) {
      final existing = classMap[d.className];
      if (existing != null) {
        existing.due += d.dueFees;
        existing.defaultersCount += 1;
      } else {
        classMap[d.className] = _ClassMatrixItem(
          className: d.className,
          enrolled: 1,
          collected: 0,
          due: d.dueFees,
          discount: 0,
          defaultersCount: 1,
        );
      }
    }

    return classMap.values.toList();
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 3: DUES & DEFAULTERS AGING
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildDuesDefaultersTab() {
    final highDues = _dues.where((d) => d.dueFees >= 10000).toList();
    final medDues = _dues.where((d) => d.dueFees >= 3000 && d.dueFees < 10000).toList();
    final lowDues = _dues.where((d) => d.dueFees < 3000).toList();
    final totalDuesAmt = _dues.fold<double>(0.0, (sum, d) => sum + d.dueFees);

    final filtered = _dues.where((d) {
      if (_defaulterClassFilter != 'All Classes' && d.className != _defaulterClassFilter) {
        return false;
      }
      if (_defaulterSearch.isEmpty) return true;
      return d.name.toLowerCase().contains(_defaulterSearch) ||
          d.rollNumber.toLowerCase().contains(_defaulterSearch) ||
          d.className.toLowerCase().contains(_defaulterSearch) ||
          d.parentPhone.contains(_defaulterSearch);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4 Defaulter Segment Cards
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth > 780 ? 4 : 2;
          final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
          final segments = [
            _defaulterKpi(
              label: 'Total Defaulters',
              count: _dues.length,
              amount: totalDuesAmt,
              color: AppColors.error,
              icon: Icons.warning_amber_rounded,
            ),
            _defaulterKpi(
              label: 'High Risk (> ₹10k)',
              count: highDues.length,
              amount: highDues.fold(0.0, (s, d) => s + d.dueFees),
              color: const Color(0xFFDC2626),
              icon: Icons.error_outline_rounded,
            ),
            _defaulterKpi(
              label: 'Medium Risk (₹3k-10k)',
              count: medDues.length,
              amount: medDues.fold(0.0, (s, d) => s + d.dueFees),
              color: AppColors.warning,
              icon: Icons.schedule_rounded,
            ),
            _defaulterKpi(
              label: 'Low Risk (< ₹3k)',
              count: lowDues.length,
              amount: lowDues.fold(0.0, (s, d) => s + d.dueFees),
              color: AppColors.info,
              icon: Icons.info_outline_rounded,
            ),
          ];

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: segments.map((c) => SizedBox(width: width, child: c)).toList(),
          );
        }),
        const SizedBox(height: 16),

        // Controls
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _defaulterSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by student name, roll number, or phone...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _defaulterClassFilter,
                  underline: const SizedBox(),
                  items: ['All Classes', ..._summary!.enrollmentByClass.keys]
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _defaulterClassFilter = v ?? 'All Classes'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.palette.brand,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export Defaulters'),
                  onPressed: () => _exportDefaultersCsv(filtered),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Defaulters Table
        Card(
          clipBehavior: Clip.antiAlias,
          child: filtered.isEmpty
              ? _noData('No fee defaulters matching current criteria')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(context.palette.surface),
                    columns: const [
                      DataColumn(label: Text('Student Name')),
                      DataColumn(label: Text('Class & Roll')),
                      DataColumn(label: Text('Parent Phone')),
                      DataColumn(label: Text('Total Fee'), numeric: true),
                      DataColumn(label: Text('Paid So Far'), numeric: true),
                      DataColumn(label: Text('Outstanding Due'), numeric: true),
                      DataColumn(label: Text('Last Payment')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: filtered.map((d) {
                      return DataRow(cells: [
                        DataCell(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(d.name,
                                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w800, fontSize: 13)),
                            if (d.parentName.isNotEmpty)
                              Text('Parent: ${d.parentName}',
                                  style: GoogleFonts.nunitoSans(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        )),
                        DataCell(Text('${d.className}${d.rollNumber.isNotEmpty ? ' • Roll ${d.rollNumber}' : ''}')),
                        DataCell(Text(d.parentPhone.isNotEmpty ? d.parentPhone : 'Not provided',
                            style: GoogleFonts.nunitoSans(fontSize: 12))),
                        DataCell(Text(_currency.format(d.totalFees))),
                        DataCell(Text(_currency.format(d.paidFees),
                            style: GoogleFonts.nunitoSans(color: AppColors.success, fontWeight: FontWeight.w700))),
                        DataCell(Text(
                          _currency.format(d.dueFees),
                          style: GoogleFonts.nunitoSans(
                              fontWeight: FontWeight.w900, color: AppColors.error, fontSize: 13),
                        )),
                        DataCell(Text(
                            d.lastPayment != null ? _dateFmt.format(d.lastPayment!.paymentDate) : 'Never',
                            style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.textSecondary))),
                        DataCell(ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: GoogleFonts.nunitoSans(fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                          icon: const Icon(Icons.chat_bubble_rounded, size: 14),
                          label: const Text('WhatsApp Reminder'),
                          onPressed: () => _openWhatsAppReminder(d),
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _defaulterKpi({
    required String label,
    required int count,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$count students',
                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w900, fontSize: 15)),
                Text(_currency.format(amount),
                    style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w800, fontSize: 12, color: color)),
                Text(label,
                    style: GoogleFonts.nunitoSans(fontSize: 10, color: AppColors.textSecondary)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 4: TRANSACTION AUDIT LEDGER
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildTransactionLedgerTab() {
    final txns = _feeReport?.transactions ?? [];

    final filtered = txns.where((t) {
      if (_txnModeFilter != 'All' && t.paymentMode.toUpperCase() != _txnModeFilter.toUpperCase()) {
        return false;
      }
      if (_txnSearch.isEmpty) return true;
      return t.studentName.toLowerCase().contains(_txnSearch) ||
          t.receiptNumber.toLowerCase().contains(_txnSearch) ||
          t.className.toLowerCase().contains(_txnSearch);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _txnSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by receipt number, student name, class...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _txnModeFilter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Modes')),
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                    DropdownMenuItem(value: 'DIGITAL_PAYMENT', child: Text('Digital / UPI')),
                    DropdownMenuItem(value: 'CHALLAN', child: Text('Challan')),
                  ],
                  onChanged: (v) => setState(() => _txnModeFilter = v ?? 'All'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.palette.brand,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export Ledger'),
                  onPressed: () => _exportTransactionsCsv(filtered),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Ledger Table
        Card(
          clipBehavior: Clip.antiAlias,
          child: filtered.isEmpty
              ? _noData('No transaction records found for the selected period')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(context.palette.surface),
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Receipt #')),
                      DataColumn(label: Text('Student Name')),
                      DataColumn(label: Text('Class & Roll')),
                      DataColumn(label: Text('Installments')),
                      DataColumn(label: Text('Gross'), numeric: true),
                      DataColumn(label: Text('Discount'), numeric: true),
                      DataColumn(label: Text('Net Paid'), numeric: true),
                      DataColumn(label: Text('Mode')),
                      DataColumn(label: Text('Receipt Actions')),
                    ],
                    rows: filtered.map((t) {
                      final gross = t.amountPaid + t.discount;
                      return DataRow(cells: [
                        DataCell(Text(_dateFmt.format(t.paymentDate), style: GoogleFonts.nunitoSans(fontSize: 12))),
                        DataCell(Text(t.receiptNumber,
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w800, color: context.palette.brand, fontSize: 12))),
                        DataCell(Text(t.studentName,
                            style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 12))),
                        DataCell(Text('${t.className}${t.rollNumber.isNotEmpty ? ' • ${t.rollNumber}' : ''}')),
                        DataCell(Text(t.paidForMonths.isEmpty ? 'Tuition' : t.paidForMonths.join(', '),
                            style: GoogleFonts.nunitoSans(fontSize: 11))),
                        DataCell(Text(_currency.format(gross))),
                        DataCell(Text(t.discount > 0 ? _currency.format(t.discount) : '-',
                            style: GoogleFonts.nunitoSans(
                                color: t.discount > 0 ? AppColors.warning : AppColors.textLight))),
                        DataCell(Text(_currency.format(t.amountPaid),
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w900, color: AppColors.success, fontSize: 13))),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: context.palette.brand.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppSizes.radiusSM),
                          ),
                          child: Text(_modeLabel(t.paymentMode),
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 11, fontWeight: FontWeight.w700, color: context.palette.brand)),
                        )),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.print_outlined, size: 18),
                              tooltip: 'Print Receipt',
                              onPressed: () {
                                ReceiptPrintService.printFeeReceipt(
                                  schoolName: AppStrings.schoolName,
                                  receiptNumber: t.receiptNumber,
                                  studentName: t.studentName,
                                  className: t.className,
                                  rollNumber: t.rollNumber,
                                  admissionNumber: t.id,
                                  paymentDate: _dateFmt.format(t.paymentDate),
                                  paymentMode: t.paymentMode,
                                  amountPaid: t.amountPaid,
                                  discount: t.discount,
                                  installments: t.paidForMonths,
                                  remarks: t.remarks,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                              tooltip: 'Share on WhatsApp',
                              color: const Color(0xFF25D366),
                              onPressed: () {
                                WhatsAppShareService.shareFeeReceipt(
                                  schoolName: AppStrings.schoolName,
                                  receiptNumber: t.receiptNumber,
                                  studentName: t.studentName,
                                  className: t.className,
                                  rollNumber: t.rollNumber,
                                  paymentDate: _dateFmt.format(t.paymentDate),
                                  paymentMode: t.paymentMode,
                                  amountPaid: t.amountPaid,
                                  discount: t.discount,
                                  installments: t.paidForMonths,
                                  parentPhone: t.parentPhone.isNotEmpty ? t.parentPhone : null,
                                  remarks: t.remarks,
                                );
                              },
                            ),
                          ],
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  // ─── UI Helper Widgets ───────────────────────────────────────────────────────
  Widget _cardHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            title,
            style: GoogleFonts.nunitoSans(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12),
          ),
        ]),
      ),
    ]);
  }

  Widget _progressRow({
    required String label,
    required double value,
    required double percent,
    required Color color,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          _currency.format(value),
          style: GoogleFonts.nunitoSans(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(percent * 100).clamp(0, 999).toStringAsFixed(1)}%',
          style: GoogleFonts.nunitoSans(color: color, fontWeight: FontWeight.w800, fontSize: 11),
        ),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: percent.clamp(0, 1),
          minHeight: 7,
          backgroundColor: color.withValues(alpha: 0.12),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }

  Widget _legendRow(String label, String value, Color color) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.nunitoSans(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
      Text(
        value,
        style: GoogleFonts.nunitoSans(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    ]);
  }

  Widget _noData(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(children: [
          Icon(Icons.inbox_outlined, size: 48, color: AppColors.textLight.withValues(alpha: 0.45)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 13),
          ),
        ]),
      ),
    );
  }

  Widget _errorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 52, color: AppColors.warning),
            const SizedBox(height: 12),
            Text(
              'Failed to load reports data',
              style: GoogleFonts.nunitoSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAllData,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Retry'),
            ),
          ]),
        ),
      ),
    );
  }

  String _shortMoney(double value) {
    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }

  String _modeLabel(String mode) => switch (mode.toUpperCase()) {
        'CASH' => 'Cash',
        'CHEQUE' => 'Cheque',
        'DIGITAL_PAYMENT' => 'Digital / UPI',
        'CHALLAN' => 'Challan',
        _ => mode,
      };
}

class _ClassMatrixItem {
  final String className;
  final int enrolled;
  double collected;
  double due;
  double discount;
  int defaultersCount;

  _ClassMatrixItem({
    required this.className,
    required this.enrolled,
    required this.collected,
    required this.due,
    required this.discount,
    required this.defaultersCount,
  });

  double get demand => collected + due;
  double get collectionRate => demand <= 0 ? 0.0 : (collected / demand * 100);

  String get healthStatus {
    if (collectionRate >= 80) return 'Excellent';
    if (collectionRate >= 50) return 'Moderate';
    return 'Critical';
  }
}
