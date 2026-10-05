import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../services/staff_api_service.dart';
import '../../../../services/payslip_print_service.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  bool _loading = false;
  List<dynamic> _salaries = [];
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadSalaries();
  }

  Future<void> _loadSalaries() async {
    setState(() => _loading = true);
    try {
      final data = await StaffApiService.getSalaries(
          month: _selectedMonth, year: _selectedYear);
      if (mounted) setState(() => _salaries = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load salaries: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _generateSalaries() async {
    setState(() => _loading = true);
    try {
      final data = await StaffApiService.generateSalaries(
          month: _selectedMonth, year: _selectedYear);
      if (mounted) {
        setState(() => _salaries = data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salaries generated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _search = '';
  String _statusFilter = 'ALL';

  List<dynamic> get _filteredSalaries {
    return _salaries.where((item) {
      final sal = item as Map<String, dynamic>;
      final name = (sal['staffName'] as String? ?? '').toLowerCase();
      final dept = (sal['department'] as String? ?? '').toLowerCase();
      final desig = (sal['designation'] as String? ?? '').toLowerCase();
      final q = _search.trim().toLowerCase();
      if (q.isNotEmpty && !name.contains(q) && !dept.contains(q) && !desig.contains(q)) {
        return false;
      }
      final status = (sal['status'] as String? ?? 'GENERATED').toUpperCase();
      if (_statusFilter == 'PAID' && status != 'PAID') return false;
      if (_statusFilter == 'PENDING' && status == 'PAID') return false;
      return true;
    }).toList();
  }

  double get _totalPayroll => _salaries.fold(
      0.0, (acc, item) => acc + ((item['netSalary'] as num?)?.toDouble() ?? 0));

  double get _totalPaid => _salaries
      .where((s) => (s['status'] as String? ?? '').toUpperCase() == 'PAID')
      .fold(0.0, (acc, item) => acc + ((item['netSalary'] as num?)?.toDouble() ?? 0));

  double get _totalPending => _totalPayroll - _totalPaid;

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSalaries;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Month / Year & Generate
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<int>(
                    value: _selectedMonth,
                    underline: const SizedBox(),
                    items: List.generate(12, (i) {
                      final m = i + 1;
                      return DropdownMenuItem(
                          value: m, child: Text(_monthName(m), style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700)));
                    }),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedMonth = v);
                        _loadSalaries();
                      }
                    },
                  ),
                  DropdownButton<int>(
                    value: _selectedYear,
                    underline: const SizedBox(),
                    items: List.generate(5, (i) {
                      final y = DateTime.now().year - 2 + i;
                      return DropdownMenuItem(value: y, child: Text('$y', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700)));
                    }),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedYear = v);
                        _loadSalaries();
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _loadSalaries,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _loading ? null : _generateSalaries,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text('Generate Batch',
                        style: GoogleFonts.nunitoSans(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // KPI Strip
          _buildKpiStrip(),
          const SizedBox(height: 14),

          // Search & Filter row
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search staff by name, department or designation…',
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
                ),
              ),
              const SizedBox(width: 12),
              _filterChip('ALL', 'All (${_salaries.length})'),
              const SizedBox(width: 6),
              _filterChip('PAID', 'Paid'),
              const SizedBox(width: 6),
              _filterChip('PENDING', 'Pending'),
            ],
          ),
          const SizedBox(height: 16),

          // Salary List or Empty
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  'No salary records matching criteria for ${_monthName(_selectedMonth)} $_selectedYear.',
                  style: GoogleFonts.nunitoSans(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final sal = filtered[index] as Map<String, dynamic>;
                return _buildSalaryTile(sal);
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
        _kpiItem('Total Payroll', '₹ ${_fmt(_totalPayroll)}', Icons.account_balance_wallet_outlined, AppColors.navy),
        _kpiItem('Disbursed (Paid)', '₹ ${_fmt(_totalPaid)}', Icons.check_circle_outline, AppColors.success),
        _kpiItem('Pending Payout', '₹ ${_fmt(_totalPending)}', Icons.pending_actions_outlined, AppColors.error),
        _kpiItem('Total Staff', '${_salaries.length}', Icons.badge_outlined, AppColors.info),
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

  Widget _filterChip(String status, String label) {
    final active = _statusFilter == status;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.navy : AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunitoSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSalaryTile(Map<String, dynamic> sal) {
    final staffName = sal['staffName'] as String? ?? '';
    final department = sal['department'] as String? ?? '';
    final designation = sal['designation'] as String? ?? '';
    final basicPay = (sal['basicPay'] as num?)?.toDouble() ?? 0;
    final hra = (sal['hra'] as num?)?.toDouble() ?? 0;
    final da = (sal['da'] as num?)?.toDouble() ?? 0;
    final ta = (sal['ta'] as num?)?.toDouble() ?? 0;
    final otherAllowances =
        (sal['otherAllowances'] as num?)?.toDouble() ?? 0;
    final grossSalary = (sal['grossSalary'] as num?)?.toDouble() ?? 0;
    final pf = (sal['pf'] as num?)?.toDouble() ?? 0;
    final tax = (sal['tax'] as num?)?.toDouble() ?? 0;
    final otherDeductions =
        (sal['otherDeductions'] as num?)?.toDouble() ?? 0;
    final totalDeductions =
        (sal['totalDeductions'] as num?)?.toDouble() ?? 0;
    final netSalary = (sal['netSalary'] as num?)?.toDouble() ?? 0;
    final status = sal['status'] as String? ?? 'GENERATED';
    final id = sal['id'] as String? ?? '';
    final isPaid = status.toUpperCase() == 'PAID';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: (isPaid ? AppColors.success : AppColors.warning).withValues(alpha: 0.15),
          child: Text(staffName.isNotEmpty ? staffName[0] : '?',
              style: TextStyle(
                  color: isPaid ? AppColors.success : AppColors.warning, fontWeight: FontWeight.w700)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(staffName,
                  style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            IconButton(
              tooltip: 'Print Payslip',
              icon: const Icon(Icons.print_outlined, size: 20),
              color: AppColors.navy,
              onPressed: () {
                PayslipPrintService.printPayslip(
                  salary: sal,
                  month: _selectedMonth,
                  year: _selectedYear,
                );
              },
            ),
            const SizedBox(width: 4),
            isPaid
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('PAID',
                        style: GoogleFonts.nunitoSans(
                            fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success)),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero),
                    onPressed: () => _markPaid(id),
                    child: Text('Mark Paid',
                        style: GoogleFonts.nunitoSans(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
          ],
        ),
        subtitle: Text(
            '${department.isNotEmpty ? department : 'General'} · Net: ₹ ${_fmt(netSalary)}',
            style: GoogleFonts.nunitoSans(
                fontSize: 12, color: AppColors.textSecondary)),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                if (designation.isNotEmpty)
                  _detailRow('Designation', designation),
                const Divider(height: 16),
                _sectionHeader('Earnings'),
                _detailRow('Basic Pay', '₹ ${_fmt(basicPay)}'),
                _detailRow('HRA', '₹ ${_fmt(hra)}'),
                _detailRow('DA', '₹ ${_fmt(da)}'),
                _detailRow('TA', '₹ ${_fmt(ta)}'),
                if (otherAllowances > 0)
                  _detailRow('Other Allowances', '₹ ${_fmt(otherAllowances)}'),
                _detailRow('Gross Salary', '₹ ${_fmt(grossSalary)}', bold: true),
                const Divider(height: 16),
                _sectionHeader('Deductions'),
                _detailRow('PF', '₹ ${_fmt(pf)}'),
                _detailRow('Tax', '₹ ${_fmt(tax)}'),
                if (otherDeductions > 0)
                  _detailRow('Other Deductions', '₹ ${_fmt(otherDeductions)}'),
                _detailRow('Total Deductions', '₹ ${_fmt(totalDeductions)}',
                    bold: true, color: AppColors.error),
                const Divider(height: 16),
                _detailRow('Net Salary', '₹ ${_fmt(netSalary)}',
                    bold: true, color: AppColors.success),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(title,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.5)),
      ),
    );
  }

  Widget _detailRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: color ?? AppColors.navy)),
        ],
      ),
    );
  }

  Future<void> _markPaid(String id) async {
    try {
      await StaffApiService.markSalaryPaid(id);
      _loadSalaries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as paid: $e')),
        );
      }
    }
  }

  String _fmt(double v) => v.toStringAsFixed(0);

  String _monthName(int m) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[m];
  }
}
