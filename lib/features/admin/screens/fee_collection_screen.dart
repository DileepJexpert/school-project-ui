import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/fee_models.dart';
import '../../../services/fee_api_service.dart';
import '../../../services/receipt_print_service.dart';
import '../../../services/whatsapp_share_service.dart';
import '../../../core/widgets/searchable_dropdown.dart';

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
      final profile = await FeeApiService.getStudentFeeProfile(
          widget.preSelectedStudentId!);
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
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final r =
          await FeeApiService.searchStudents(name: q, className: _classFilter);
      if (seq != _searchSeq)
        return; // a newer search has already fired — discard this
      setState(() => _results = r);
    } catch (_) {
      if (seq != _searchSeq) return;
      setState(() => _error = 'Student search is temporarily unavailable.');
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
    if (_payMode == 'CHEQUE' && _chequeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the cheque number and bank details.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (_payMode == 'DIGITAL_PAYMENT' && _txnCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the digital payment transaction ID or UTR.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final discount = double.tryParse(_discountCtrl.text.trim());
    if (discount == null ||
        !discount.isFinite ||
        discount < 0 ||
        discount > _selectedTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Enter a valid discount no greater than the selected total.'),
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
        remarks:
            _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
        chequeDetails:
            _payMode == 'CHEQUE' && _chequeCtrl.text.trim().isNotEmpty
                ? _chequeCtrl.text.trim()
                : null,
        transactionId:
            _payMode == 'DIGITAL_PAYMENT' && _txnCtrl.text.trim().isNotEmpty
                ? _txnCtrl.text.trim()
                : null,
      );
      final currentStudent = _selected!;
      final record = await FeeApiService.collectFee(req);
      if (mounted) {
        _showSuccessDialog(record, currentStudent);
        _profileGeneration++;
        _searchSeq++;
        _resetPaymentDetails();
        setState(() {
          _selected = null;
          _results = [];
          _searchCtrl.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Payment could not be recorded. Please retry.'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _selectAllDueInstallments() {
    if (_selected == null) return;
    setState(() {
      for (final f in _selected!.feeInstallments) {
        if (f.status.toUpperCase() != 'PAID') {
          f.isSelectedForPayment = true;
        }
      }
    });
  }

  void _clearSelectedInstallments() {
    if (_selected == null) return;
    setState(() {
      for (final f in _selected!.feeInstallments) {
        f.isSelectedForPayment = false;
      }
      _discountCtrl.text = '0.00';
      _discount = 0.0;
    });
  }

  void _applyDiscountPercent(double percent) {
    if (_selectedTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Select at least one installment before applying discount.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final disc = (_selectedTotal * percent);
    setState(() {
      _discountCtrl.text = disc.toStringAsFixed(2);
      _discount = disc;
    });
  }

  Widget _discountChip(String label, double percent) {
    return ActionChip(
      label: Text(label,
          style: GoogleFonts.nunitoSans(
              fontSize: 11, fontWeight: FontWeight.w600)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      backgroundColor: context.palette.brand.withValues(alpha: 0.07),
      side: BorderSide(color: context.palette.brand.withValues(alpha: 0.2)),
      onPressed: () => _applyDiscountPercent(percent),
    );
  }

  void _showSuccessDialog(PaymentRecord r, StudentFeeProfile s) {
    final phoneCtrl = TextEditingController(text: s.parentPhone);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fee Payment Recorded',
                    style: GoogleFonts.cormorantGaramond(
                        fontWeight: FontWeight.w700, fontSize: 20)),
                Text('Transaction completed successfully',
                    style: GoogleFonts.nunitoSans(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ]),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dlgContext.palette.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  border: Border.all(color: dlgContext.palette.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('RECEIPT NUMBER',
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          SelectableText(r.receiptNumber,
                              style: GoogleFonts.nunitoSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: dlgContext.palette.brand)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy Receipt Number',
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: r.receiptNumber));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Receipt number copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _receiptRow('Student Name', s.name),
              _receiptRow('Class & Roll',
                  '${s.className}${s.rollNumber.isNotEmpty ? ' • Roll: ${s.rollNumber}' : ''}'),
              _receiptRow(
                  'Installments',
                  r.paidForInstallments.isEmpty
                      ? 'General Tuition'
                      : r.paidForInstallments.join(', ')),
              _receiptRow('Payment Mode', r.paymentMode),
              _receiptRow('Payment Date', _dateFmt.format(r.paymentDate)),
              if (r.discount > 0)
                _receiptRow('Discount', _fmt.format(r.discount),
                    valueColor: AppColors.warning),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Amount Paid',
                      style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary)),
                  Text(_fmt.format(r.amountPaid),
                      style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.success)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  border: Border.all(
                      color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_rounded,
                        size: 18, color: Color(0xFF25D366)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.nunitoSans(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Parent WhatsApp (e.g. 9876543210)',
                          hintStyle: GoogleFonts.nunitoSans(
                              fontSize: 12, color: AppColors.textSecondary),
                          labelText: 'WhatsApp Phone Number',
                          labelStyle: GoogleFonts.nunitoSans(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dlgContext),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: const Text('Share on WhatsApp'),
            onPressed: () {
              WhatsAppShareService.shareFeeReceipt(
                schoolName: AppStrings.schoolName,
                receiptNumber: r.receiptNumber,
                studentName: s.name,
                className: s.className,
                rollNumber: s.rollNumber,
                paymentDate: _dateFmt.format(r.paymentDate),
                paymentMode: r.paymentMode,
                amountPaid: r.amountPaid,
                discount: r.discount,
                installments: r.paidForInstallments,
                parentPhone: phoneCtrl.text.trim().isNotEmpty
                    ? phoneCtrl.text.trim()
                    : null,
                remarks: r.remarks,
              );
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: dlgContext.palette.brand,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Print Receipt'),
            onPressed: () {
              ReceiptPrintService.printFeeReceipt(
                schoolName: AppStrings.schoolName,
                receiptNumber: r.receiptNumber,
                studentName: s.name,
                className: s.className,
                rollNumber: s.rollNumber,
                admissionNumber: s.id,
                paymentDate: _dateFmt.format(r.paymentDate),
                paymentMode: r.paymentMode,
                amountPaid: r.amountPaid,
                discount: r.discount,
                installments: r.paidForInstallments,
                remarks: r.remarks,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value,
          {Color? valueColor, bool isBold = false}) =>
      Padding(
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
                    fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                    color: valueColor ?? AppColors.textPrimary,
                    fontSize: 13)),
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
            style: GoogleFonts.cormorantGaramond(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: Colors.white)),
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        if (wide) {
          return Row(children: [
            Expanded(
                flex: 2, child: _buildSearchPanel(context, isDesktop: true)),
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
        ? (_searchCtrl.text.isNotEmpty || _classFilter != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('No students found matching your criteria.',
                      style: GoogleFonts.nunitoSans(
                          color: AppColors.textSecondary)),
                ),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Search by student name or filter by class.',
                      style: GoogleFonts.nunitoSans(
                          color: AppColors.textSecondary)),
                ),
              ))
        : ListView.separated(
            shrinkWrap: !isDesktop,
            physics: isDesktop ? null : const NeverScrollableScrollPhysics(),
            itemCount: _results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final s = _results[i];
              final isSelected = _selected?.id == s.id;
              final initials = s.name.trim().isNotEmpty
                  ? s.name.trim().substring(0, 1).toUpperCase()
                  : '?';
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  onTap: _processing ? null : () => _selectStudent(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? palette.brand.withValues(alpha: 0.08)
                          : palette.canvas,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                      border: Border.all(
                        color: isSelected ? palette.brand : palette.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? palette.brand
                                : palette.brand.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color:
                                    isSelected ? Colors.white : palette.brand,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.name,
                                style: GoogleFonts.nunitoSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: palette.brand,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          palette.brand.withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      s.className,
                                      style: GoogleFonts.nunitoSans(
                                        color: palette.brand,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (s.rollNumber.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      'Roll: ${s.rollNumber}',
                                      style: GoogleFonts.nunitoSans(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (s.dueFees > 0
                                        ? AppColors.error
                                        : AppColors.success)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _fmt.format(s.dueFees),
                                style: GoogleFonts.nunitoSans(
                                  color: s.dueFees > 0
                                      ? AppColors.error
                                      : AppColors.success,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.dueFees > 0 ? 'Due' : 'Cleared',
                              style: GoogleFonts.nunitoSans(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: palette.brand)),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Name or roll number…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
            ),
          ),
          const SizedBox(height: 12),
          SearchableDropdownFormField<String>(
            labelText: 'Filter by Class',
            hintText: 'Select or type class name…',
            initialValue: _classFilter ?? 'All Classes',
            items: ['All Classes', ..._classes],
            onChanged: (v) {
              setState(() =>
                  _classFilter = (v == null || v == 'All Classes') ? null : v);
              _search();
            },
          ),
          const SizedBox(height: 12),
          if (_searching) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: GoogleFonts.nunitoSans(color: AppColors.error)),
            ),
          const SizedBox(height: 10),
          if (isDesktop) Expanded(child: resultsList) else resultsList,
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
          const Icon(Icons.point_of_sale_outlined,
              size: 64, color: AppColors.textLight),
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
            backgroundColor: palette.brand.withValues(alpha: 0.1),
            child: Text(
                s.name.trim().isEmpty
                    ? '?'
                    : s.name.trim().substring(0, 1).toUpperCase(),
                style: GoogleFonts.cormorantGaramond(
                    color: palette.brand, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name,
                  style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              Text(
                  '${s.className} · Roll: ${s.rollNumber} · Parent: ${s.parentName}',
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary, fontSize: 12)),
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
          _summaryChip(
              'Total', _fmt.format(s.totalFees), AppColors.textPrimary),
          const SizedBox(width: 8),
          _summaryChip('Paid', _fmt.format(s.paidFees), AppColors.success),
          const SizedBox(width: 8),
          _summaryChip('Due', _fmt.format(s.dueFees), AppColors.error),
        ]),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Select Installments',
                style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w700, color: palette.brand)),
            if (s.feeInstallments.any((f) => f.status.toUpperCase() != 'PAID'))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.select_all, size: 16),
                    label: const Text('Select All Due',
                        style: TextStyle(fontSize: 12)),
                    onPressed: _selectAllDueInstallments,
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.clear_all, size: 16),
                    label:
                        const Text('Clear', style: TextStyle(fontSize: 12)),
                    onPressed: _clearSelectedInstallments,
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
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
        ...s.feeInstallments.map((f) {
          final isPaid = f.status.toUpperCase() == 'PAID';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isPaid
                  ? palette.canvas
                  : (f.isSelectedForPayment
                      ? palette.brand.withValues(alpha: 0.04)
                      : palette.surface),
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              border: Border.all(
                color: isPaid
                    ? palette.border
                    : (f.isSelectedForPayment ? palette.brand : palette.border),
                width: f.isSelectedForPayment ? 1.5 : 1,
              ),
            ),
            child: CheckboxListTile(
              value: f.isSelectedForPayment,
              title: Text(f.installmentName,
                  style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w600,
                      decoration: isPaid ? TextDecoration.lineThrough : null,
                      color: isPaid
                          ? AppColors.textSecondary
                          : AppColors.textPrimary)),
              subtitle: Text('Due: ${_fmt.format(f.amountDue)}',
                  style: GoogleFonts.nunitoSans(
                      color: AppColors.textSecondary, fontSize: 12)),
              secondary: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isPaid ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(f.status,
                    style: GoogleFonts.nunitoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isPaid ? AppColors.success : AppColors.warning)),
              ),
              onChanged: isPaid
                  ? null
                  : (v) => setState(() => f.isSelectedForPayment = v ?? false),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            ),
          );
        }),
        const SizedBox(height: 16),
        // Payment details
        Text('Payment Details',
            style: GoogleFonts.nunitoSans(
                fontWeight: FontWeight.w700, color: palette.brand)),
        const SizedBox(height: 8),
        SearchableDropdownFormField<String>(
          initialValue: _payMode,
          labelText: 'Payment Mode *',
          hintText: 'Select payment mode…',
          items: _payModes,
          onChanged: (v) => setState(() => _payMode = v),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _discountCtrl,
          decoration: InputDecoration(
            labelText: 'Discount Amount (₹)',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Quick Presets:',
                style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            _discountChip('5% Sibling', 0.05),
            _discountChip('10% Staff', 0.10),
            _discountChip('15% Merit', 0.15),
            if (_discount > 0)
              ActionChip(
                label: Text('Reset',
                    style: GoogleFonts.nunitoSans(
                        fontSize: 11, color: AppColors.error)),
                avatar:
                    const Icon(Icons.close, size: 13, color: AppColors.error),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                backgroundColor: AppColors.error.withValues(alpha: 0.08),
                side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.2)),
                onPressed: () {
                  _discountCtrl.text = '0.00';
                  setState(() => _discount = 0.0);
                },
              ),
          ],
        ),
        if (_payMode == 'CHEQUE') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _chequeCtrl,
            decoration: InputDecoration(
              labelText: 'Cheque Details (No. / Bank) *',
              helperText: 'Required for cheque payments',
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
              labelText: 'Transaction ID / UTR *',
              helperText: 'Required for digital payments',
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
        const SizedBox(height: 16),
        // Amount summary
        Card(
          color: palette.brand.withValues(alpha: 0.04),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              side: BorderSide(color: palette.border)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _amtRow('Selected Total', _fmt.format(_selectedTotal),
                  AppColors.textPrimary),
              _amtRow(
                  'Discount', '- ${_fmt.format(_discount)}', AppColors.warning),
              const Divider(),
              _amtRow('Net Payable', _fmt.format(_netAmount), palette.brand,
                  bold: true),
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
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_outline),
            label: Text(
                _processing
                    ? 'Processing…'
                    : 'Collect ${_fmt.format(_netAmount)}',
                style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w700, fontSize: 16)),
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

  Widget _amtRow(String label, String value, Color color,
          {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: GoogleFonts.nunitoSans(color: AppColors.textSecondary)),
          Text(value,
              style: GoogleFonts.nunitoSans(
                  color: color,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  fontSize: bold ? 16 : 14)),
        ]),
      );
}
