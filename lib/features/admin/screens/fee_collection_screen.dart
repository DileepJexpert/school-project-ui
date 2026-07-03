import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';

class FeeCollectionScreen extends StatefulWidget {
  /// When provided, the screen loads and pre-selects this student's fee profile.
  final String? preSelectedStudentId;
  const FeeCollectionScreen({super.key, this.preSelectedStudentId});

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
  bool _loadingProfile = false; // true while fetching full profile after tap
  bool _processing = false;
  String? _error;
  Timer? _debounce;
  // Sequence counter to discard stale async search responses
  int _searchSeq = 0;
  double _discount = 0.0;
  String? _payMode;
  final _fmt = NumberFormat.currency(symbol: '\u20B9', decimalDigits: 2);
  final _dateFmt = DateFormat('dd MMM yyyy');

  final _payModes = ['CASH', 'CHEQUE', 'DIGITAL_PAYMENT', 'CHALLAN'];

  // Class filter list sourced from SchoolConstants, same values stored in MongoDB.
  static List<String> get _classes => SchoolConstants.allClasses;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _discountCtrl.addListener(() {
      setState(() => _discount = double.tryParse(_discountCtrl.text) ?? 0.0);
    });
    if (widget.preSelectedStudentId != null) _preSelectStudent();
  }

  Future<void> _preSelectStudent() async {
    try {
      final profile = await FeeApiService.getStudentFeeProfile(
          widget.preSelectedStudentId!);
      setState(() => _selected = profile);
    } catch (_) {} // silently fall through, admin can search manually
  }

  /// Called when the admin taps a student from the search results.
  /// Fetches the full fee profile (auto-generating it from fee_structures if it
  /// doesn't exist yet) instead of using the zero-fee stub returned by search.
  Future<void> _selectStudent(StudentFeeProfile stub) async {
    setState(() {
      _results = [];
      _searchCtrl.clear();
      _loadingProfile = true;
    });
    try {
      final full = await FeeApiService.getStudentFeeProfile(stub.id);
      setState(() => _selected = full);
    } catch (_) {
      // Fallback to the search stub so the screen at least shows the student
      setState(() => _selected = stub);
    } finally {
      setState(() => _loadingProfile = false);
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _search);
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty && _classFilter == null) {
      setState(() {
        _results = [];
        _error = null;
      }); // keep _selected intact
      return;
    }
    // Capture sequence BEFORE the async gap so stale responses are ignored.
    // Each new search call increments the counter; only the latest response applies.
    final seq = ++_searchSeq;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final r =
          await FeeApiService.searchStudents(name: q, className: _classFilter);
      if (seq != _searchSeq)
        return; // a newer search has already fired, discard this
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
        .fold<double>(0.0, (s, f) => s + f.amountDue);
  }

  double get _netAmount =>
      (_selectedTotal - _discount).clamp(0.0, double.infinity);

  int get _selectedInstallmentCount =>
      _selected?.feeInstallments.where((f) => f.isSelectedForPayment).length ??
      0;

  Future<void> _collectFee() async {
    final installments = _selected?.feeInstallments
            .where((f) => f.isSelectedForPayment)
            .toList() ??
        [];
    if (installments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select at least one installment.'),
            backgroundColor: AppColors.warning),
      );
      return;
    }
    if (_payMode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select a payment mode.'),
            backgroundColor: AppColors.warning),
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
        remarks:
            _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
        chequeDetails:
            _chequeCtrl.text.trim().isEmpty ? null : _chequeCtrl.text.trim(),
        transactionId:
            _txnCtrl.text.trim().isEmpty ? null : _txnCtrl.text.trim(),
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
          SnackBar(
              content: Text('Payment failed: $e'),
              backgroundColor: AppColors.error),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
        title: Row(children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 28),
          const SizedBox(width: 10),
          Text('Payment Successful',
              style:
                  GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700)),
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
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy, foregroundColor: Colors.white),
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
            child: Text(label,
                style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
      backgroundColor: context.palette.canvas,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: context.palette.border)),
        title: Text('Collect Fees',
            style: GoogleFonts.nunitoSans(
                fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      bottomNavigationBar: _selected == null ? null : _buildStickyPayableBar(),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        if (wide) {
          return Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              SizedBox(width: 340, child: _buildSearchPanel()),
              const SizedBox(width: 14),
              Expanded(child: _buildPaymentPanel()),
            ]),
          );
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        border: Border.all(color: context.palette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.palette.brand.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
              child: Icon(Icons.person_search_outlined,
                  color: context.palette.brand, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Find Student',
                      style: GoogleFonts.nunitoSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy)),
                  Text('Use name, roll number or class filter',
                      style: GoogleFonts.nunitoSans(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Name or roll number...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Filter by Class',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          initialValue: _classFilter,
          items: [
            const DropdownMenuItem(value: null, child: Text('All Classes')),
            ..._classes.map((c) => DropdownMenuItem(value: c, child: Text(c))),
          ],
          onChanged: (v) {
            setState(() => _classFilter = v);
            _search();
          },
        ),
        const SizedBox(height: 12),
        if (_searching) const LinearProgressIndicator(),
        if (_error != null)
          Text(_error!, style: GoogleFonts.nunitoSans(color: AppColors.error)),
        ..._results.map((s) => ListTile(
              title: Text(s.name,
                  style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
              subtitle: Text('${s.className} - Roll: ${s.rollNumber}',
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary, fontSize: 12)),
              trailing: Text(_fmt.format(s.dueFees),
                  style: GoogleFonts.nunitoSans(
                      color:
                          s.dueFees > 0 ? AppColors.error : AppColors.success,
                      fontWeight: FontWeight.w700)),
              onTap: () => _selectStudent(s),
              tileColor: context.palette.canvas,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                side: BorderSide(color: context.palette.border),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            )),
      ]),
    );
  }

  Widget _buildPaymentPanel() {
    if (_loadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_selected == null) {
      return Card(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: context.palette.brand.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.point_of_sale_outlined,
                        size: 38, color: context.palette.brand),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Ready to collect fees',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunitoSans(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a student from the left panel. Their pending installments and payment form will appear here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _emptyHint(Icons.search_rounded, 'Search'),
                      _emptyHint(Icons.check_circle_outline, 'Select dues'),
                      _emptyHint(Icons.receipt_long_outlined, 'Receipt'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final s = _selected!;
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Student info
          Row(children: [
            CircleAvatar(
              backgroundColor: AppColors.navy.withValues(alpha: 0.1),
              child: Text(s.name.substring(0, 1).toUpperCase(),
                  style: GoogleFonts.cormorantGaramond(
                      color: AppColors.navy, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        style: GoogleFonts.nunitoSans(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(
                        '${s.className} - Roll: ${s.rollNumber} - Parent: ${s.parentName}',
                        style: GoogleFonts.nunitoSans(
                            color: AppColors.textSecondary, fontSize: 12)),
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
            _summaryChip(
                'Total', _fmt.format(s.totalFees), AppColors.textPrimary),
            const SizedBox(width: 8),
            _summaryChip('Paid', _fmt.format(s.paidFees), AppColors.success),
            const SizedBox(width: 8),
            _summaryChip('Due', _fmt.format(s.dueFees), AppColors.error),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('Select fee components',
                    style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w800, color: AppColors.navy)),
              ),
              if (s.feeInstallments
                  .any((f) => f.status.toUpperCase() != 'PAID'))
                TextButton(
                  onPressed: () => setState(() {
                    final shouldSelect = s.feeInstallments.any((f) =>
                        f.status.toUpperCase() != 'PAID' &&
                        !f.isSelectedForPayment);
                    for (final f in s.feeInstallments) {
                      if (f.status.toUpperCase() != 'PAID') {
                        f.isSelectedForPayment = shouldSelect;
                      }
                    }
                  }),
                  child: const Text('Select due'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (s.feeInstallments.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No fee installments found for this student. '
                    'Please set up a fee structure for ${s.className} in the Fee Structure Setup screen first, '
                    'then re-admit or re-assign the student.',
                    style: GoogleFonts.nunitoSans(
                        color: AppColors.warning, fontSize: 13),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            decoration: BoxDecoration(
              color: context.palette.canvas,
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              border: Border.all(color: context.palette.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < s.feeInstallments.length; i++) ...[
                  _installmentRow(s.feeInstallments[i]),
                  if (i != s.feeInstallments.length - 1)
                    Divider(height: 1, color: context.palette.border),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Payment details
          Text('Payment Details',
              style: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w700, color: AppColors.navy)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _payMode,
            decoration: InputDecoration(
              labelText: 'Payment Mode *',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
            ),
            items: _payModes
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() => _payMode = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _discountCtrl,
            decoration: InputDecoration(
              labelText: 'Discount Amount (\u20B9)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          if (_payMode == 'CHEQUE') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _chequeCtrl,
              decoration: InputDecoration(
                labelText: 'Cheque Details (No. / Bank)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
              ),
            ),
          ],
          if (_payMode == 'DIGITAL_PAYMENT') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _txnCtrl,
              decoration: InputDecoration(
                labelText: 'Transaction ID / UTR',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _remarksCtrl,
            decoration: InputDecoration(
              labelText: 'Remarks (Optional)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Widget _buildStickyPayableBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border(top: BorderSide(color: context.palette.border)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 18,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final amountItems = [
              _stickyAmount('Selected', _fmt.format(_selectedTotal),
                  AppColors.textPrimary),
              _stickyAmount(
                  'Discount', '- ${_fmt.format(_discount)}', AppColors.warning),
              _stickyAmount('Payable', _fmt.format(_netAmount), AppColors.navy,
                  prominent: true),
            ];
            final action = ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                ),
              ),
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.receipt_long_outlined, size: 18),
              label: Text(
                _processing
                    ? 'Processing...'
                    : 'Collect ${_fmt.format(_netAmount)}',
                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w800),
              ),
              onPressed: _processing ? null : _collectFee,
            );

            if (compact) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(spacing: 10, runSpacing: 8, children: amountItems),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$_selectedInstallmentCount fee component${_selectedInstallmentCount == 1 ? '' : 's'} selected',
                          style: GoogleFonts.nunitoSans(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      action,
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                ...amountItems,
                const Spacer(),
                Text(
                  '$_selectedInstallmentCount component${_selectedInstallmentCount == 1 ? '' : 's'} selected',
                  style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 14),
                action,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _stickyAmount(String label, String value, Color color,
      {bool prominent = false}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: prominent ? 0.1 : 0.055),
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.nunitoSans(
              color: color,
              fontSize: prominent ? 17 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text(value,
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            Text(label,
                style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ),
      );

  Widget _installmentRow(FeeInstallment f) {
    final isPaid = f.status.toUpperCase() == 'PAID';
    final color = isPaid ? AppColors.success : AppColors.warning;
    return InkWell(
      onTap: isPaid
          ? null
          : () =>
              setState(() => f.isSelectedForPayment = !f.isSelectedForPayment),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Checkbox(
                value: f.isSelectedForPayment,
                onChanged: isPaid
                    ? null
                    : (v) =>
                        setState(() => f.isSelectedForPayment = v ?? false),
                visualDensity: VisualDensity.compact,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                f.status,
                style: GoogleFonts.nunitoSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                f.installmentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  decoration: isPaid ? TextDecoration.lineThrough : null,
                  color: isPaid ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _fmt.format(f.amountDue),
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isPaid ? AppColors.textLight : AppColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyHint(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: context.palette.canvas,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: context.palette.brand),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.nunitoSans(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
