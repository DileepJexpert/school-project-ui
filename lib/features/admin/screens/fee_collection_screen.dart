import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';

class FeeCollectionScreen extends StatefulWidget {
  const FeeCollectionScreen({super.key});

  @override
  State<FeeCollectionScreen> createState() => _FeeCollectionScreenState();
}

class _FeeCollectionScreenState extends State<FeeCollectionScreen> {
  final _searchCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0.00');
  final _remarksCtrl = TextEditingController();
  final _chequeCtrl = TextEditingController();
  final _txnCtrl = TextEditingController();

  String? _classFilter;
  List<StudentFeeProfile> _results = [];
  StudentFeeProfile? _selected;
  bool _searching = false;
  bool _processing = false;
  String? _error;
  Timer? _debounce;
  // Sequence counter to discard stale async search responses
  int _searchSeq = 0;
  double _discount = 0.0;
  DateTime _payDate = DateTime.now();
  String? _payMode;
  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  final _dateFmt = DateFormat('dd MMM yyyy');

  final _payModes = ['CASH', 'CHEQUE', 'DIGITAL_PAYMENT', 'CHALLAN'];

  // Full class list matching StudentFeeProfile.className values in the DB
  static const _classes = [
    'Nursery', 'LKG', 'UKG',
    'Class 1 - A', 'Class 1 - B',
    'Class 2 - A', 'Class 2 - B',
    'Class 3 - A', 'Class 3 - B',
    'Class 4 - A', 'Class 4 - B',
    'Class 5 - A', 'Class 5 - B',
    'Class 6 - A', 'Class 6 - B',
    'Class 7 - A', 'Class 7 - B',
    'Class 8 - A', 'Class 8 - B',
    'Class 9 - A', 'Class 9 - B',
    'Class 10 - A', 'Class 10 - B',
    'Class 11 - A', 'Class 11 - B',
    'Class 12 - A', 'Class 12 - B',
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _discountCtrl.addListener(() {
      setState(() => _discount = double.tryParse(_discountCtrl.text) ?? 0.0);
    });
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _search);
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty && _classFilter == null) {
      setState(() { _results = []; _selected = null; _error = null; });
      return;
    }
    // Capture sequence BEFORE the async gap so stale responses are ignored.
    // Each new search call increments the counter; only the latest response applies.
    final seq = ++_searchSeq;
    setState(() { _searching = true; _error = null; });
    try {
      final r = await FeeApiService.searchStudents(name: q, className: _classFilter);
      if (seq != _searchSeq) return; // a newer search has already fired — discard this
      setState(() => _results = r);
    } catch (e) {
      if (seq != _searchSeq) return;
      setState(() => _error = 'Search failed: $e');
    } finally {
      if (seq == _searchSeq) setState(() => _searching = false);
    }
  }

  double get _selectedTotal {
    if (_selected == null) return 0.0;
    return _selected!.feeInstallments
        .where((f) => f.isSelectedForPayment)
        .fold<double>(0.0, (s, f) => s + (f.amountDue ?? 0.0));
  }

  double get _netAmount => (_selectedTotal - _discount).clamp(0.0, double.infinity);

  Future<void> _collectFee() async {
    final installments = _selected?.feeInstallments.where((f) => f.isSelectedForPayment).toList() ?? [];
    if (installments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one installment.'), backgroundColor: AppColors.warning),
      );
      return;
    }
    if (_payMode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a payment mode.'), backgroundColor: AppColors.warning),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      final req = FeePaymentRequest(
        studentId: _selected!.id,
        amount: _netAmount,
        discount: _discount,
        installmentNames: installments.map((f) => f.installmentName).toList(),
        paymentMode: _payMode!,
        remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
        chequeDetails: _chequeCtrl.text.trim().isEmpty ? null : _chequeCtrl.text.trim(),
        transactionId: _txnCtrl.text.trim().isEmpty ? null : _txnCtrl.text.trim(),
      );
      final record = await FeeApiService.collectFee(req);
      if (mounted) {
        _showSuccessDialog(record);
        setState(() {
          _selected = null;
          _results = [];
          _searchCtrl.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showSuccessDialog(PaymentRecord r) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
        title: Row(children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 28),
          const SizedBox(width: 10),
          Text('Payment Successful', style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _receiptRow('Student', r.studentName),
          _receiptRow('Receipt No.', r.receiptNumber),
          _receiptRow('Amount Paid', _fmt.format(r.amountPaid)),
          if (r.discount > 0) _receiptRow('Discount', _fmt.format(r.discount)),
          _receiptRow('Mode', r.paymentMode),
          _receiptRow('Date', _dateFmt.format(r.paymentDate)),
        ]),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
            width: 110,
            child: Text(label, style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ]),
      );

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    _remarksCtrl.dispose();
    _chequeCtrl.dispose();
    _txnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text('Collect Fees',
            style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        if (wide) {
          return Row(children: [
            Expanded(flex: 2, child: _buildSearchPanel()),
            const VerticalDivider(width: 1),
            Expanded(flex: 3, child: _buildPaymentPanel()),
          ]);
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _buildSearchPanel(),
            const SizedBox(height: 16),
            _buildPaymentPanel(),
          ]),
        );
      }),
    );
  }

  Widget _buildSearchPanel() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Find Student',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.navy)),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Name or roll number…',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Filter by Class',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          value: _classFilter,
          items: [
            const DropdownMenuItem(value: null, child: Text('All Classes')),
            ..._classes.map((c) => DropdownMenuItem(value: c, child: Text(c))),
          ],
          onChanged: (v) { setState(() => _classFilter = v); _search(); },
        ),
        const SizedBox(height: 12),
        if (_searching) const LinearProgressIndicator(),
        if (_error != null)
          Text(_error!, style: GoogleFonts.nunitoSans(color: AppColors.error)),
        ..._results.map((s) => ListTile(
              title: Text(s.name, style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
              subtitle: Text('${s.className} · Roll: ${s.rollNumber}',
                  style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12)),
              trailing: Text(_fmt.format(s.dueFees),
                  style: GoogleFonts.nunitoSans(
                      color: s.dueFees > 0 ? AppColors.error : AppColors.success,
                      fontWeight: FontWeight.w700)),
              onTap: () => setState(() { _selected = s; _results = []; _searchCtrl.clear(); }),
              tileColor: AppColors.cream,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            )),
      ]),
    );
  }

  Widget _buildPaymentPanel() {
    if (_selected == null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.point_of_sale_outlined, size: 64, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text('Search and select a student\nto collect fees.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(color: AppColors.textSecondary)),
        ]),
      );
    }
    final s = _selected!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Student info
        Row(children: [
          CircleAvatar(
            backgroundColor: AppColors.navy.withOpacity(0.1),
            child: Text(s.name.substring(0, 1).toUpperCase(),
                style: GoogleFonts.cormorantGaramond(color: AppColors.navy, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 16)),
              Text('${s.className} · Roll: ${s.rollNumber} · Parent: ${s.parentName}',
                  style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _selected = null),
          ),
        ]),
        const SizedBox(height: 12),
        // Summary row
        Row(children: [
          _summaryChip('Total', _fmt.format(s.totalFees), AppColors.textPrimary),
          const SizedBox(width: 8),
          _summaryChip('Paid', _fmt.format(s.paidFees), AppColors.success),
          const SizedBox(width: 8),
          _summaryChip('Due', _fmt.format(s.dueFees), AppColors.error),
        ]),
        const SizedBox(height: 16),
        Text('Select Installments',
            style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, color: AppColors.navy)),
        const SizedBox(height: 8),
        ...s.feeInstallments.map((f) {
          final isPaid = f.status.toUpperCase() == 'PAID';
          return CheckboxListTile(
            value: f.isSelectedForPayment,
            title: Text(f.installmentName,
                style: GoogleFonts.nunitoSans(
                    decoration: isPaid ? TextDecoration.lineThrough : null)),
            subtitle: Text(_fmt.format(f.amountDue),
                style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12)),
            secondary: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (isPaid ? AppColors.success : AppColors.warning).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(f.status,
                  style: GoogleFonts.nunitoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPaid ? AppColors.success : AppColors.warning)),
            ),
            onChanged: isPaid
                ? null
                : (v) => setState(() => f.isSelectedForPayment = v ?? false),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
            tileColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          );
        }),
        const SizedBox(height: 16),
        // Payment details
        Text('Payment Details',
            style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, color: AppColors.navy)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _payMode,
          decoration: InputDecoration(
            labelText: 'Payment Mode *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
          ),
          items: _payModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) => setState(() => _payMode = v),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _discountCtrl,
          decoration: InputDecoration(
            labelText: 'Discount Amount (₹)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        if (_payMode == 'CHEQUE') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _chequeCtrl,
            decoration: InputDecoration(
              labelText: 'Cheque Details (No. / Bank)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
            ),
          ),
        ],
        if (_payMode == 'DIGITAL_PAYMENT') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _txnCtrl,
            decoration: InputDecoration(
              labelText: 'Transaction ID / UTR',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: _remarksCtrl,
          decoration: InputDecoration(
            labelText: 'Remarks (Optional)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        // Amount summary
        Card(
          color: AppColors.navy.withOpacity(0.04),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              side: const BorderSide(color: AppColors.border)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _amtRow('Selected Total', _fmt.format(_selectedTotal), AppColors.textPrimary),
              _amtRow('Discount', '- ${_fmt.format(_discount)}', AppColors.warning),
              const Divider(),
              _amtRow('Net Payable', _fmt.format(_netAmount), AppColors.navy, bold: true),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16)),
            icon: _processing
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_outline),
            label: Text(_processing ? 'Processing…' : 'Collect ${_fmt.format(_netAmount)}',
                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 16)),
            onPressed: _processing ? null : _collectFee,
          ),
        ),
      ]),
    );
  }

  Widget _summaryChip(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Text(value,
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            Text(label,
                style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ),
      );

  Widget _amtRow(String label, String value, Color color, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: GoogleFonts.nunitoSans(color: AppColors.textSecondary)),
          Text(value,
              style: GoogleFonts.nunitoSans(
                  color: color,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  fontSize: bold ? 16 : 14)),
        ]),
      );
}
