import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../services/staff_api_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              DropdownButton<int>(
                value: _selectedMonth,
                items: List.generate(12, (i) {
                  final m = i + 1;
                  return DropdownMenuItem(
                      value: m, child: Text(_monthName(m)));
                }),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedMonth = v);
                    _loadSalaries();
                  }
                },
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _selectedYear,
                items: List.generate(5, (i) {
                  final y = DateTime.now().year - 2 + i;
                  return DropdownMenuItem(value: y, child: Text('$y'));
                }),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedYear = v);
                    _loadSalaries();
                  }
                },
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                ),
                onPressed: _loading ? null : _generateSalaries,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text('Generate',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _salaries.isEmpty
                  ? Center(
                      child: Text(
                          'No salary records for ${_monthName(_selectedMonth)} $_selectedYear.',
                          style: GoogleFonts.poppins(
                              color: AppColors.textSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _salaries.length,
                      itemBuilder: (context, index) {
                        final sal =
                            _salaries[index] as Map<String, dynamic>;
                        return _buildSalaryTile(sal);
                      },
                    ),
        ),
      ],
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.navy.withOpacity(0.1),
          child: Text(staffName.isNotEmpty ? staffName[0] : '?',
              style: const TextStyle(
                  color: AppColors.navy, fontWeight: FontWeight.w600)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(staffName,
                  style:
                      GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
            status == 'PAID'
                ? Chip(
                    label: Text('PAID',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.green)),
                    backgroundColor: Colors.green.withOpacity(0.1),
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero),
                    onPressed: () => _markPaid(id),
                    child: Text('Mark Paid',
                        style: GoogleFonts.poppins(fontSize: 11)),
                  ),
          ],
        ),
        subtitle: Text(
            '${department.isNotEmpty ? department : 'N/A'}  |  Net: Rs ${_fmt(netSalary)}',
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textSecondary)),
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                if (designation.isNotEmpty)
                  _detailRow('Designation', designation),
                const Divider(height: 16),
                _sectionHeader('Earnings'),
                _detailRow('Basic Pay', 'Rs ${_fmt(basicPay)}'),
                _detailRow('HRA', 'Rs ${_fmt(hra)}'),
                _detailRow('DA', 'Rs ${_fmt(da)}'),
                _detailRow('TA', 'Rs ${_fmt(ta)}'),
                if (otherAllowances > 0)
                  _detailRow(
                      'Other Allowances', 'Rs ${_fmt(otherAllowances)}'),
                _detailRow('Gross Salary', 'Rs ${_fmt(grossSalary)}',
                    bold: true),
                const Divider(height: 16),
                _sectionHeader('Deductions'),
                _detailRow('PF', 'Rs ${_fmt(pf)}'),
                _detailRow('Tax', 'Rs ${_fmt(tax)}'),
                if (otherDeductions > 0)
                  _detailRow(
                      'Other Deductions', 'Rs ${_fmt(otherDeductions)}'),
                _detailRow(
                    'Total Deductions', 'Rs ${_fmt(totalDeductions)}',
                    bold: true, color: Colors.red),
                const Divider(height: 16),
                _detailRow('Net Salary', 'Rs ${_fmt(netSalary)}',
                    bold: true, color: Colors.green[700]!),
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
