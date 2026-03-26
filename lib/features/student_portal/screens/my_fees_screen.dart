import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/student_portal_api_service.dart';

class MyFeesScreen extends StatefulWidget {
  const MyFeesScreen({super.key});

  @override
  State<MyFeesScreen> createState() => _MyFeesScreenState();
}

class _MyFeesScreenState extends State<MyFeesScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _feeData;

  @override
  void initState() {
    super.initState();
    _loadFees();
  }

  Future<void> _loadFees() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await StudentPortalApiService.getMyFees();
      if (mounted) setState(() => _feeData = data);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load fees: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: Text(_error!, style: GoogleFonts.poppins(color: Colors.red)));
    }
    if (_feeData == null) {
      return Center(
          child: Text('No fee data available.',
              style: GoogleFonts.poppins(color: AppColors.textSecondary)));
    }

    final totalFee = (_feeData?['totalFee'] as num?)?.toDouble() ?? 0;
    final paidAmount = (_feeData?['paidAmount'] as num?)?.toDouble() ?? 0;
    final pendingAmount = totalFee - paidAmount;
    final installments =
        (_feeData?['installments'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Fees',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _feeCard('Total Fee', totalFee, AppColors.navy),
              _feeCard('Paid', paidAmount, Colors.green),
              _feeCard('Pending', pendingAmount,
                  pendingAmount > 0 ? Colors.red : Colors.green),
            ],
          ),
          const SizedBox(height: 24),
          Text('Installments',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (installments.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                    child: Text('No installments found.',
                        style: GoogleFonts.poppins(
                            color: AppColors.textSecondary))),
              ),
            )
          else
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: installments.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final inst = installments[index] as Map<String, dynamic>;
                  final name =
                      inst['name'] as String? ?? 'Installment ${index + 1}';
                  final amount =
                      (inst['amount'] as num?)?.toDouble() ?? 0;
                  final status = inst['status'] as String? ?? 'PENDING';
                  final dueDate = inst['dueDate'] as String? ?? '';

                  return ListTile(
                    title:
                        Text(name, style: GoogleFonts.poppins(fontSize: 14)),
                    subtitle: Text('Due: $dueDate',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textSecondary)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Rs ${amount.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600)),
                        Chip(
                          label: Text(status,
                              style: GoogleFonts.poppins(fontSize: 10)),
                          backgroundColor: status == 'PAID'
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _feeCard(String label, double amount, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text('Rs ${amount.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
