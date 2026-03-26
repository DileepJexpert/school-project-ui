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
    } catch (_) {}
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
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _salaries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
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
    final netSalary = (sal['netSalary'] as num?)?.toDouble() ?? 0;
    final status = sal['status'] as String? ?? 'GENERATED';
    final id = sal['id'] as String? ?? '';

    return ListTile(
      title: Text(staffName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      subtitle: Text('Net: Rs ${netSalary.toStringAsFixed(0)}',
          style:
              GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
      trailing: status == 'PAID'
          ? Chip(
              label: Text('PAID', style: GoogleFonts.poppins(fontSize: 11)),
              backgroundColor: Colors.green.withOpacity(0.1),
            )
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              onPressed: () => _markPaid(id),
              child: Text('Mark Paid',
                  style: GoogleFonts.poppins(fontSize: 12)),
            ),
    );
  }

  Future<void> _markPaid(String id) async {
    try {
      await StaffApiService.markSalaryPaid(id);
      _loadSalaries();
    } catch (_) {}
  }

  String _monthName(int m) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[m];
  }
}
