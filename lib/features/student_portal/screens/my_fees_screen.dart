import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/student_portal_api_service.dart';
import '../../../services/payment_gateway_service.dart';
import '../../../services/auth_service.dart';
import '../../payments/fee_payment_flow.dart';

class MyFeesScreen extends StatefulWidget {
  const MyFeesScreen({super.key});

  @override
  State<MyFeesScreen> createState() => _MyFeesScreenState();
}

class _MyFeesScreenState extends State<MyFeesScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _feeData;
  bool _paymentsEnabled = false;

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
    final user = AuthService.instance.currentUser;
    final paid = await startFeePayment(
      context,
      studentId: user?.linkedEntityId ?? user?.userId ?? '',
      studentName: user?.fullName ?? 'Student',
      className: _feeData?['className'] as String? ?? '',
      installmentId: inst['installmentId'] as String? ?? '',
      installmentName: inst['installmentName'] as String? ?? '',
      amount: (inst['amountDue'] as num?)?.toDouble() ?? 0,
    );
    if (paid) _loadFees();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 460),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppColors.error.withValues(alpha: 0.8)),
              const SizedBox(height: 12),
              Text('Could not load fee records',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.brand)),
              const SizedBox(height: 6),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadFees,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_feeData == null) {
      return Center(
        child: Text('No fee records found.',
            style: GoogleFonts.poppins(color: AppColors.textSecondary)),
      );
    }

    final totalFee = (_feeData?['totalFees'] as num?)?.toDouble() ?? 0;
    final paidAmount = (_feeData?['paidFees'] as num?)?.toDouble() ?? 0;
    final pendingAmount = (_feeData?['dueFees'] as num?)?.toDouble() ??
        (totalFee - paidAmount).clamp(0, double.infinity);
    final installments =
        (_feeData?['installments'] as List<dynamic>?) ?? [];
    final feeCleared = pendingAmount <= 0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Fee Clearance & Invoices',
                        style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: palette.brand)),
                    const SizedBox(height: 4),
                    Text(
                      'View term installment schedules, paid receipts, and clear dues online.',
                      style: GoogleFonts.nunitoSans(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh fees',
                onPressed: _loadFees,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Fee KPI Cards
          LayoutBuilder(builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 620;
            final width = isNarrow
                ? (constraints.maxWidth - 8) / 2
                : (constraints.maxWidth - 24) / 3;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _feeMetricCard('Total Fees', totalFee, palette.brand,
                    Icons.account_balance_outlined, width),
                _feeMetricCard('Paid to Date', paidAmount, const Color(0xFF059669),
                    Icons.check_circle_outline_rounded, width),
                _feeMetricCard(
                    'Outstanding Dues',
                    pendingAmount,
                    feeCleared ? const Color(0xFF059669) : AppColors.error,
                    Icons.pending_actions_outlined,
                    width,
                    statusTag: feeCleared ? 'Account Cleared' : 'Pending Payment'),
              ],
            );
          }),
          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: totalFee > 0 ? (paidAmount / totalFee).clamp(0.0, 1.0) : 0.0,
              minHeight: 10,
              backgroundColor: AppColors.error.withValues(alpha: 0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            totalFee > 0
                ? '${((paidAmount / totalFee) * 100).toStringAsFixed(1)}% paid of total school fees'
                : 'No fees assigned',
            style: GoogleFonts.nunitoSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // Installments Section
          Text('Installment Schedule',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.brand)),
          const SizedBox(height: 12),

          if (installments.isEmpty)
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: palette.border.withValues(alpha: 0.6)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No installment records scheduled.')),
              ),
            )
          else
            ...installments.map((inst) =>
                _buildInstallmentTile(inst as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _feeMetricCard(String label, double amount, Color color,
      IconData icon, double width, {String? statusTag}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
                  '₹${amount.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (statusTag != null)
                  Text(
                    statusTag,
                    style: GoogleFonts.nunitoSans(
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
    );
  }

  Widget _buildInstallmentTile(Map<String, dynamic> inst) {
    final name = inst['installmentName'] as String? ?? 'Installment';
    final amount = (inst['amountDue'] as num?)?.toDouble() ?? 0;
    final dueDate = inst['dueDate'] as String? ?? '';
    final status = (inst['status'] as String? ?? 'PENDING').toUpperCase();
    final isPaid = status == 'PAID';
    final palette = context.palette;

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPaid
              ? const Color(0xFF059669).withValues(alpha: 0.3)
              : const Color(0xFFD97706).withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: (isPaid
                      ? const Color(0xFF059669)
                      : const Color(0xFFD97706))
                  .withValues(alpha: 0.12),
              child: Icon(
                isPaid ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                color: isPaid ? const Color(0xFF059669) : const Color(0xFFD97706),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: palette.brand,
                      decoration: isPaid ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (dueDate.isNotEmpty)
                    Text(
                      'Due Date: $dueDate',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${amount.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isPaid ? const Color(0xFF059669) : AppColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                if (isPaid)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PAID',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  )
                else if (_paymentsEnabled)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _payInstallment(inst),
                    child: Text(
                      'Pay Now',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
