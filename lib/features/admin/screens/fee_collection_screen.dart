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
  int _profileGeneration = 0;
  double _discount = 0.0;
  String? _payMode;
  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  final _dateFmt = DateFormat('dd MMM yyyy');

  final _payModes = ['CASH', 'CHEQUE', 'DIGITAL_PAYMENT', 'CHALLAN'];

  // Class filter list sourced from SchoolConstants — same values stored in MongoDB
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
    final generation = _profileGeneration;
    try {
      final profile = await FeeApiService.getStudentFeeProfile(widget.preSelectedStudentId!);
      if (mounted && generation == _profileGeneration) {
        setState(() => _selected = profile);
      }
    } catch (_) {} // silently fall through — admin can search manually
  }

  void _resetPaymentDetails() {
    _discountCtrl.text = '0.00';
    _remarksCtrl.clear();
    _chequeCtrl.clear();
    _txnCtrl.clear();
    _discount = 0.0;
    _payMode = null;
  }

  void _clearSelection() {
    _profileGeneration++;
    _resetPaymentDetails();
    setState(() => _selected = null);
  }

  /// Called when the admin taps a student from the search results.
  /// Fetches the full fee profile (auto-generating it from fee_structures if it
  /// doesn't exist yet) instead of using the zero-fee stub returned by search.
  Future<void> _selectStudent(StudentFeeProfile stub) async {
    if (_processing) return;
    final generation = ++_profileGeneration;
    _searchSeq++;
    _resetPaymentDetails();
    setState(() {
      _selected = null;
      _results = [];
      _searching = false;
      _searchCtrl.clear();
      _loadingProfile = true;
    });
    try {
      final full = await FeeApiService.getStudentFeeProfile(stub.id);
      if (mounted && generation == _profileGeneration) {
        setState(() => _selected = full);
      }
    } catch (_) {
      // Fallback to the search stub so the screen at least shows the student
      if (mounted && generation == _profileGeneration) {
        setState(() => _selected = stub);
      }
    } finally {
      if (mounted && generation == _profileGeneration) {
        setState(() => _loadingProfile = false);
      }
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _search);
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty && _classFilter == null) {
      _searchSeq++;
      setState(() {
        _results = [];
        _searching = false;
        _error = null;
      }); // keep _selected intact
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
        .fold<double>(0.0, (s, f) => s + f.amountDue);
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
    final discount = double.tryParse(_discountCtrl.text.trim());
    if (discount == null || !discount.isFinite ||
        discount < 0 || discount > _selectedTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid discount no greater than the selected total.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      final req = FeePaymentRequest(
        studentId: _selected!.id,
        amount: _selectedTotal - discount,
        discount: discount,
        installmentNames: installments.map((f) => f.installmentName).toList(),
        paymentMode: _payMode!,
        remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
        chequeDetails: _payMode == 'CHEQUE' && _chequeCtrl.text.trim().isNotEmpty
            ? _chequeCtrl.text.trim()
            : null,
        transactionId: _payMode == 'DIGITAL_PAYMENT' && _txnCtrl.text.trim().isNotEmpty
            ? _txnCtrl.text.trim()
            : null,
      );
      final record = await FeeApiService.collectFee(req);
      if (mounted) {
        _showSuccessDialog(record);
        _profileGeneration++;
        _searchSeq++;
        _resetPaymentDetails();
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
            style: ElevatedButton.styleFrom(backgroundColor: context.palette.brand, foregroundColor: Colors.white),
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
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.brand,
        foregroundColor: Colors.white,
        title: Text('Collect Fees',
            style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white)),
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        if (wide) {
          return Row(children: [
            Expanded(flex: 2, child: _buildSearchPanel(context, isDesktop: true)),
            VerticalDivider(width: 1, color: palette.border),
            Expanded(flex: 3, child: _buildPaymentPanel(context)),
          ]);
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _buildSearchPanel(context, isDesktop: false),
            const SizedBox(height: 16),
            _buildPaymentPanel(context),
          ]),
        );
      }),
    );
  }

  Widget _buildSearchPanel(BuildContext context, {required bool isDesktop}) {
    final palette = context.palette;
    final resultsList = _results.isEmpty && !_searching
        ? (_searchCtrl.text.isNotEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('No students found matching "${_searchCtrl.text}".',
                      style: GoogleFonts.nunitoSans(color: AppColors.textSecondary)),
                ),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Search by student name or roll number.',
                      style: GoogleFonts.nunitoSans(color: AppColors.textSecondary)),
                ),
              ))
        : ListView.separated(
            shrinkWrap: !isDesktop,
            physics: isDesktop ? null : const NeverScrollableScrollPhysics(),
            itemCount: _results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final s = _results[i];
              final isSelected = _selected?.id == s.id;
              return ListTile(
                title: Text(s.name, style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
                subtitle: Text('${s.className} · Roll: ${s.rollNumber}',
                    style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12)),
                trailing: Text(_fmt.format(s.dueFees),
                    style: GoogleFonts.nunitoSans(
                        color: s.dueFees > 0 ? AppColors.error : AppColors.success,
                        fontWeight: FontWeight.w700)),
                onTap: _processing ? null : () => _selectStudent(s),
                tileColor: isSelected ? palette.brand.withOpacity(0.1) : palette.canvas,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  side: isSelected ? BorderSide(color: palette.brand) : BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              );
            },
          );

    return Container(
      color: palette.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Find Student',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 20, fontWeight: FontWeight.w700, color: palette.brand)),
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
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: GoogleFonts.nunitoSans(color: AppColors.error)),
            ),
          const SizedBox(height: 10),
          if (isDesktop)
            Expanded(child: resultsList)
          else
            resultsList,
        ],
      ),
    );
  }

  Widget _buildPaymentPanel(BuildContext context) {
    final palette = context.palette;
    if (_loadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }
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
            backgroundColor: palette.brand.withOpacity(0.1),
            child: Text(s.name.substring(0, 1).toUpperCase(),
                style: GoogleFonts.cormorantGaramond(color: palette.brand, fontWeight: FontWeight.w700)),
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
            onPressed: _processing ? null : _clearSelection,
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
            style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, color: palette.brand)),
        const SizedBox(height: 8),
        if (s.feeInstallments.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No fee installments found for this student. '
                  'Please set up a fee structure for ${s.className} in the Fee Structure Setup screen first, '
                  'then re-admit or re-assign the student.',
                  style: GoogleFonts.nunitoSans(color: AppColors.warning, fontSize: 13),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
        ],
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
            tileColor: palette.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          );
        }),
        const SizedBox(height: 16),
        // Payment details
        Text('Payment Details',
            style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, color: palette.brand)),
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
          color: palette.brand.withOpacity(0.04),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              side: BorderSide(color: palette.border)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _amtRow('Selected Total', _fmt.format(_selectedTotal), AppColors.textPrimary),
              _amtRow('Discount', '- ${_fmt.format(_discount)}', AppColors.warning),
              const Divider(),
              _amtRow('Net Payable', _fmt.format(_netAmount), palette.brand, bold: true),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: palette.brand,
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
