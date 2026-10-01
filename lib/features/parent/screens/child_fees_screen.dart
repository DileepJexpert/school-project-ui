import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/parent_api_service.dart';
import '../../../services/payment_gateway_service.dart';
import '../../payments/fee_payment_flow.dart';

class ChildFeesScreen extends StatefulWidget {
  final String? studentId;
  final String? studentName;

  const ChildFeesScreen({super.key, this.studentId, this.studentName});

  @override
  State<ChildFeesScreen> createState() => _ChildFeesScreenState();
}

class _ChildFeesScreenState extends State<ChildFeesScreen> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _feeData;
  bool _paymentsEnabled = false;

  @override
  void didUpdateWidget(ChildFeesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentId != widget.studentId && widget.studentId != null) {
      _loadFees();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.studentId != null) _loadFees();
  }

  Future<void> _loadFees() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ParentApiService.getChildFees(widget.studentId!);
      bool enabled = false;
      try {
        final cfg = await PaymentGatewayService.getConfig();
        enabled = cfg['enabled'] == true;
      } catch (_) {}
      if (mounted) {
        setState(() {
          _feeData = data;
          _paymentsEnabled = enabled;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load fees: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _payInstallment(Map<String, dynamic> inst) async {
    final paid = await startFeePayment(
      context,
      studentId: widget.studentId!,
      studentName: widget.studentName ?? 'Student',
      className: _feeData?['className'] as String? ?? '',
      installmentId: inst['installmentId'] as String? ?? '',
      installmentName: inst['installmentName'] as String? ?? '',
      amount: (inst['amountDue'] as num?)?.toDouble() ?? 0,
    );
    if (paid) _loadFees();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.studentId == null) {
      return Center(
        child: Text('Please select a child from the Overview tab.',
            style: GoogleFonts.poppins(color: AppColors.textSecondary)),
      );
    }

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

    final totalFee = (_feeData?['totalFees'] as num?)?.toDouble() ?? 0;
    final paidAmount = (_feeData?['paidFees'] as num?)?.toDouble() ?? 0;
    final pendingAmount = (_feeData?['dueFees'] as num?)?.toDouble() ??
        (totalFee - paidAmount);
    final installments =
        (_feeData?['feeInstallments'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadFees,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(Responsive.contentPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.studentName}\'s Fees',
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
                    return _installmentTile(
                        installments[index] as Map<String, dynamic>, index);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _installmentTile(Map<String, dynamic> inst, int index) {
    final name = inst['installmentName'] as String? ?? 'Installment ${index + 1}';
    final amount = (inst['amountDue'] as num?)?.toDouble() ?? 0;
    final status = inst['status'] as String? ?? 'PENDING';
    final dueDate = inst['dueDate'] as String? ?? '';
    final isPaid = status == 'PAID';

    return ListTile(
      title: Text(name, style: GoogleFonts.poppins(fontSize: 14)),
      subtitle: dueDate.isEmpty
          ? null
          : Text('Due: $dueDate',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecondary)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Rs ${amount.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          if (isPaid)
            Chip(
              label: Text('PAID', style: GoogleFonts.poppins(fontSize: 10)),
              backgroundColor: Colors.green.withOpacity(0.1),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          else if (_paymentsEnabled)
            SizedBox(
              height: 30,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: () => _payInstallment(inst),
                child: const Text('Pay Now'),
              ),
            )
          else
            Chip(
              label: Text(status, style: GoogleFonts.poppins(fontSize: 10)),
              backgroundColor: Colors.orange.withOpacity(0.1),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
