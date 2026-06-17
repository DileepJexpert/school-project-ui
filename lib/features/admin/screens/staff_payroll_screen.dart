import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/staff_attendance_api_service.dart';
import '../../../services/payroll_api_service.dart';

class StaffPayrollScreen extends StatefulWidget {
  const StaffPayrollScreen({super.key});

  @override
  State<StaffPayrollScreen> createState() => _StaffPayrollScreenState();
}

class _StaffPayrollScreenState extends State<StaffPayrollScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Tab 1: Staff Attendance state ─────────────────────────────────────
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _attendanceList = [];
  Map<String, dynamic> _todayStats = {};
  bool _attLoading = false;
  String? _attError;

  // ── Tab 2: Payroll state ──────────────────────────────────────────────
  String _payMonth = DateFormat('MMMM').format(DateTime.now());
  late final TextEditingController _payYearCtrl;
  List<dynamic> _payrollList = [];
  bool _payLoading = false;
  bool _payGenerating = false;
  String? _payError;

  // ── Tab 3: Summary state ──────────────────────────────────────────────
  String _sumMonth = DateFormat('MMMM').format(DateTime.now());
  late final TextEditingController _sumYearCtrl;
  Map<String, dynamic> _summaryStats = {};
  bool _sumLoading = false;
  String? _sumError;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _statusColors = {
    'PRESENT': Color(0xFF059669),
    'ABSENT': Color(0xFFDC2626),
    'HALF_DAY': Color(0xFFF59E0B),
    'ON_LEAVE': Color(0xFF3B82F6),
    'LATE': Color(0xFFEAB308),
  };

  static const _payrollStatusColors = {
    'DRAFT': Color(0xFF94A3B8),
    'PROCESSED': Color(0xFF3B82F6),
    'PAID': Color(0xFF059669),
  };

  // ─────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _payYearCtrl = TextEditingController(text: '${DateTime.now().year}');
    _sumYearCtrl = TextEditingController(text: '${DateTime.now().year}');
    _loadAttendance();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _payYearCtrl.dispose();
    _sumYearCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════
  //  ATTENDANCE HELPERS
  // ══════════════════════════════════════════════════════════════════════

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.navy, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadAttendance();
    }
  }

  Future<void> _loadAttendance() async {
    setState(() {
      _attLoading = true;
      _attError = null;
    });
    try {
      final dateStr = _fmtDate(_selectedDate);
      final results = await Future.wait([
        StaffAttendanceApiService.getByDate(dateStr),
        StaffAttendanceApiService.getTodayStats(),
      ]);
      if (!mounted) return;
      setState(() {
        _attendanceList = results[0] as List<dynamic>;
        _todayStats = results[1] as Map<String, dynamic>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _attError = e.toString());
    } finally {
      if (mounted) setState(() => _attLoading = false);
    }
  }

  Future<void> _showMarkAttendanceDialog() async {
    // Load staff list from current attendance (or empty if none)
    final List<Map<String, dynamic>> staffEntries = [];
    for (final item in _attendanceList) {
      final m = item as Map<String, dynamic>;
      staffEntries.add({
        'staffId': m['staffId'] ?? m['userId'] ?? '',
        'staffName': m['staffName'] ?? m['name'] ?? 'Unknown',
        'status': m['status'] ?? 'PRESENT',
      });
    }

    if (staffEntries.isEmpty) {
      _showSnack('No staff records found for this date. '
          'Ensure staff data exists in the system.', isError: true);
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _MarkAttendanceDialog(
        date: _fmtDate(_selectedDate),
        entries: staffEntries,
      ),
    );
    if (result == true) {
      _showSnack('Attendance marked successfully!');
      _loadAttendance();
    }
  }

  Future<void> _showEditStatusDialog(Map<String, dynamic> record) async {
    String currentStatus = record['status'] ?? 'PRESENT';
    final id = record['_id'] ?? record['id'] ?? '';

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String selected = currentStatus;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
            title: Text('Edit Status',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, color: AppColors.navy)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: _statusColors.keys.map((status) {
                return RadioListTile<String>(
                  title: Text(status.replaceAll('_', ' '),
                      style: GoogleFonts.poppins(fontSize: 14)),
                  value: status,
                  groupValue: selected,
                  activeColor: _statusColors[status],
                  onChanged: (v) => setDialogState(() => selected = v!),
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: GoogleFonts.poppins(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, selected),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white),
                child: Text('Update', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && result != currentStatus && id.toString().isNotEmpty) {
      try {
        await StaffAttendanceApiService.updateAttendance(
            id.toString(), {'status': result});
        _showSnack('Status updated!');
        _loadAttendance();
      } catch (e) {
        _showSnack('Failed to update: $e', isError: true);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PAYROLL HELPERS
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _loadPayroll() async {
    final year = int.tryParse(_payYearCtrl.text.trim()) ?? DateTime.now().year;
    setState(() {
      _payLoading = true;
      _payError = null;
    });
    try {
      final list = await PayrollApiService.getByMonth(_payMonth, year);
      if (!mounted) return;
      setState(() => _payrollList = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _payError = e.toString());
    } finally {
      if (mounted) setState(() => _payLoading = false);
    }
  }

  Future<void> _generatePayroll() async {
    final year = int.tryParse(_payYearCtrl.text.trim()) ?? DateTime.now().year;
    setState(() => _payGenerating = true);
    try {
      await PayrollApiService.generatePayroll(_payMonth, year);
      if (!mounted) return;
      _showSnack('Payroll generated for $_payMonth $year!');
      _loadPayroll();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to generate: $e', isError: true);
    } finally {
      if (mounted) setState(() => _payGenerating = false);
    }
  }

  Future<void> _processPayroll(String id) async {
    try {
      await PayrollApiService.processPayroll(id);
      _showSnack('Payroll processed!');
      _loadPayroll();
    } catch (e) {
      _showSnack('Failed: $e', isError: true);
    }
  }

  Future<void> _markPaid(String id) async {
    try {
      await PayrollApiService.markAsPaid(id);
      _showSnack('Marked as paid!');
      _loadPayroll();
    } catch (e) {
      _showSnack('Failed: $e', isError: true);
    }
  }

  Future<void> _showEditPayrollDialog(Map<String, dynamic> payroll) async {
    final id = (payroll['_id'] ?? payroll['id'] ?? '').toString();
    final basicCtrl =
        TextEditingController(text: '${payroll['basicSalary'] ?? 0}');
    final hraCtrl = TextEditingController(text: '${payroll['hra'] ?? 0}');
    final daCtrl = TextEditingController(text: '${payroll['da'] ?? 0}');
    final taCtrl = TextEditingController(text: '${payroll['ta'] ?? 0}');
    final pfCtrl = TextEditingController(text: '${payroll['pf'] ?? 0}');
    final taxCtrl = TextEditingController(text: '${payroll['tax'] ?? 0}');
    final bonusCtrl = TextEditingController(text: '${payroll['bonus'] ?? 0}');
    final deductionsCtrl =
        TextEditingController(text: '${payroll['otherDeductions'] ?? 0}');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
        title: Text('Edit Payroll',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: AppColors.navy)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField('Basic Salary', basicCtrl),
              _dialogField('HRA', hraCtrl),
              _dialogField('DA', daCtrl),
              _dialogField('TA', taCtrl),
              _dialogField('PF', pfCtrl),
              _dialogField('Tax', taxCtrl),
              _dialogField('Bonus', bonusCtrl),
              _dialogField('Other Deductions', deductionsCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.white),
            child: Text('Save', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await PayrollApiService.updatePayroll(id, {
          'basicSalary': double.tryParse(basicCtrl.text) ?? 0,
          'hra': double.tryParse(hraCtrl.text) ?? 0,
          'da': double.tryParse(daCtrl.text) ?? 0,
          'ta': double.tryParse(taCtrl.text) ?? 0,
          'pf': double.tryParse(pfCtrl.text) ?? 0,
          'tax': double.tryParse(taxCtrl.text) ?? 0,
          'bonus': double.tryParse(bonusCtrl.text) ?? 0,
          'otherDeductions': double.tryParse(deductionsCtrl.text) ?? 0,
        });
        _showSnack('Payroll updated!');
        _loadPayroll();
      } catch (e) {
        _showSnack('Failed: $e', isError: true);
      }
    }

    basicCtrl.dispose();
    hraCtrl.dispose();
    daCtrl.dispose();
    taCtrl.dispose();
    pfCtrl.dispose();
    taxCtrl.dispose();
    bonusCtrl.dispose();
    deductionsCtrl.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════
  //  SUMMARY HELPERS
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _loadSummary() async {
    final year = int.tryParse(_sumYearCtrl.text.trim()) ?? DateTime.now().year;
    setState(() {
      _sumLoading = true;
      _sumError = null;
    });
    try {
      final stats = await PayrollApiService.getStats(_sumMonth, year);
      if (!mounted) return;
      setState(() => _summaryStats = stats);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sumError = e.toString());
    } finally {
      if (mounted) setState(() => _sumLoading = false);
    }
  }

  // ── Shared helpers ────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  Widget _dialogField(String label, TextEditingController ctrl) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.textSecondary),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              borderSide: const BorderSide(color: AppColors.navy, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      );

  InputDecoration _inputDecor(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.poppins(color: AppColors.textLight, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: AppColors.navy),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          borderSide: const BorderSide(color: AppColors.navy, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        isDense: true,
      );

  // ══════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Staff Attendance & Payroll',
              style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          Text('Manage staff attendance, payroll and salary disbursement',
              style: GoogleFonts.poppins(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          // ── Tab bar ─────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.creamDark,
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Staff Attendance'),
                Tab(text: 'Payroll'),
                Tab(text: 'Summary'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAttendanceTab(),
                _buildPayrollTab(),
                _buildSummaryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  TAB 1: STAFF ATTENDANCE
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildAttendanceTab() => Column(children: [
        _buildAttendanceHeader(),
        const SizedBox(height: 12),
        _buildStatsRow(),
        const SizedBox(height: 12),
        Expanded(child: _buildAttendanceBody()),
      ]);

  Widget _buildAttendanceHeader() => Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Date picker
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    color: Colors.white,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: AppColors.navy),
                    const SizedBox(width: 8),
                    Text(DateFormat('dd MMM yyyy').format(_selectedDate),
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: AppColors.textPrimary)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down,
                        color: AppColors.textSecondary),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _attLoading ? null : _loadAttendance,
                icon: _attLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(_attLoading ? 'Loading...' : 'Refresh',
                    style: GoogleFonts.poppins(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showMarkAttendanceDialog,
                icon: const Icon(Icons.how_to_reg_rounded, size: 18),
                label:
                    Text('Mark Attendance', style: GoogleFonts.poppins(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12)),
              ),
            ],
          ),
        ),
      );

  Widget _buildStatsRow() {
    final present = _todayStats['present'] ?? 0;
    final absent = _todayStats['absent'] ?? 0;
    final halfDay = _todayStats['halfDay'] ?? 0;
    final onLeave = _todayStats['onLeave'] ?? 0;
    final late_ = _todayStats['late'] ?? 0;

    return Row(
      children: [
        _statCard('Present', '$present', const Color(0xFF059669)),
        const SizedBox(width: 8),
        _statCard('Absent', '$absent', const Color(0xFFDC2626)),
        const SizedBox(width: 8),
        _statCard('Half Day', '$halfDay', const Color(0xFFF59E0B)),
        const SizedBox(width: 8),
        _statCard('On Leave', '$onLeave', const Color(0xFF3B82F6)),
        const SizedBox(width: 8),
        _statCard('Late', '$late_', const Color(0xFFEAB308)),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            children: [
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: color.withOpacity(0.8)),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _buildAttendanceBody() {
    if (_attLoading) return _buildShimmer();
    if (_attError != null) {
      return _buildError(_attError!, _loadAttendance);
    }
    if (_attendanceList.isEmpty) {
      return _buildIdle(
          'No attendance records for ${DateFormat('dd MMM yyyy').format(_selectedDate)}');
    }
    return ListView.separated(
      itemCount: _attendanceList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) {
        final rec = _attendanceList[i] as Map<String, dynamic>;
        final name = rec['staffName'] ?? rec['name'] ?? 'Unknown';
        final dept = rec['department'] ?? '';
        final designation = rec['designation'] ?? '';
        final status = rec['status'] ?? 'PRESENT';
        final checkIn = rec['checkInTime'] ?? '';
        final checkOut = rec['checkOutTime'] ?? '';
        final statusColor = _statusColors[status] ?? AppColors.textSecondary;

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.navy.withOpacity(0.1),
                  child: Text(
                    name.toString().isNotEmpty
                        ? name.toString()[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$name',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Row(children: [
                        if (dept.toString().isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.navy.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('$dept',
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: AppColors.navy)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (designation.toString().isNotEmpty)
                          Text('$designation',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                      ]),
                      if (checkIn.toString().isNotEmpty ||
                          checkOut.toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          if (checkIn.toString().isNotEmpty)
                            Text('In: $checkIn',
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          if (checkIn.toString().isNotEmpty &&
                              checkOut.toString().isNotEmpty)
                            const SizedBox(width: 12),
                          if (checkOut.toString().isNotEmpty)
                            Text('Out: $checkOut',
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                        ]),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(status.toString().replaceAll('_', ' '),
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.navy),
                  tooltip: 'Edit status',
                  onPressed: () => _showEditStatusDialog(rec),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  TAB 2: PAYROLL
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildPayrollTab() => Column(children: [
        _buildPayrollHeader(),
        const SizedBox(height: 12),
        Expanded(child: _buildPayrollBody()),
      ]);

  Widget _buildPayrollHeader() => Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: _payMonth,
                  decoration:
                      _inputDecor('Month', Icons.calendar_month_outlined),
                  isExpanded: true,
                  items: _months
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(m,
                                style: GoogleFonts.poppins(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _payMonth = v ?? _payMonth),
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                    controller: _payYearCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        _inputDecor('Year', Icons.date_range_outlined)),
              ),
              ElevatedButton.icon(
                onPressed: _payLoading ? null : _loadPayroll,
                icon: _payLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search_rounded, size: 16),
                label: Text(_payLoading ? 'Loading...' : 'Load',
                    style: GoogleFonts.poppins(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12)),
              ),
              ElevatedButton.icon(
                onPressed: _payGenerating ? null : _generatePayroll,
                icon: _payGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_fix_high_rounded, size: 16),
                label: Text(
                    _payGenerating ? 'Generating...' : 'Generate Payroll',
                    style: GoogleFonts.poppins(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12)),
              ),
            ],
          ),
        ),
      );

  Widget _buildPayrollBody() {
    if (_payLoading) return _buildShimmer();
    if (_payError != null) return _buildError(_payError!, _loadPayroll);
    if (_payrollList.isEmpty) {
      return _buildIdle(
          'Select month/year and tap Load, or Generate Payroll');
    }
    return ListView.separated(
      itemCount: _payrollList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final p = _payrollList[i] as Map<String, dynamic>;
        final name = p['staffName'] ?? p['name'] ?? 'Unknown';
        final dept = p['department'] ?? '';
        final designation = p['designation'] ?? '';
        final basic = _toDouble(p['basicSalary']);
        final hra = _toDouble(p['hra']);
        final da = _toDouble(p['da']);
        final ta = _toDouble(p['ta']);
        final gross = _toDouble(p['grossSalary']);
        final pf = _toDouble(p['pf']);
        final tax = _toDouble(p['tax']);
        final deductions = pf + tax;
        final net = _toDouble(p['netSalary']);
        final workDays = p['workingDays'] ?? 0;
        final presentDays = p['presentDays'] ?? 0;
        final leaveDays = p['leaveDays'] ?? 0;
        final status = p['status'] ?? 'DRAFT';
        final id = (p['_id'] ?? p['id'] ?? '').toString();
        final statusColor =
            _payrollStatusColors[status] ?? AppColors.textSecondary;

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: name + status
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.navy.withOpacity(0.1),
                      child: Text(
                        name.toString().isNotEmpty
                            ? name.toString()[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$name',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.textPrimary)),
                          Row(children: [
                            if (dept.toString().isNotEmpty)
                              Text('$dept',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            if (dept.toString().isNotEmpty &&
                                designation.toString().isNotEmpty)
                              Text(' | ',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textLight)),
                            if (designation.toString().isNotEmpty)
                              Text('$designation',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                          ]),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: statusColor.withOpacity(0.4)),
                      ),
                      child: Text(status.toString(),
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                // Salary breakdown
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _salaryItem('Basic', basic),
                    _salaryItem('HRA', hra),
                    _salaryItem('DA', da),
                    _salaryItem('TA', ta),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _salaryLabel('Gross: ', gross, AppColors.textPrimary, true),
                    const SizedBox(width: 16),
                    _salaryLabel(
                        'Deductions (PF+Tax): ', deductions, AppColors.error, false),
                    const Spacer(),
                    Text('Net: ',
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: AppColors.textSecondary)),
                    Text(_formatCurrency(net),
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold)),
                  ],
                ),
                const SizedBox(height: 8),
                // Days row
                Row(
                  children: [
                    _dayChip('Working', '$workDays', AppColors.navy),
                    const SizedBox(width: 8),
                    _dayChip('Present', '$presentDays', AppColors.success),
                    const SizedBox(width: 8),
                    _dayChip('Leave', '$leaveDays', AppColors.warning),
                    const Spacer(),
                    // Actions
                    if (status == 'DRAFT') ...[
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: AppColors.navy,
                        tooltip: 'Edit',
                        onPressed: () => _showEditPayrollDialog(p),
                      ),
                      const SizedBox(width: 4),
                      _actionButton(
                          'Process', Icons.check_circle_outline, AppColors.info,
                          () => _processPayroll(id)),
                    ],
                    if (status == 'PROCESSED')
                      _actionButton(
                          'Mark Paid', Icons.payments_outlined, AppColors.success,
                          () => _markPaid(id)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _salaryItem(String label, double value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecondary)),
          Text(_formatCurrency(value),
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
        ],
      );

  Widget _salaryLabel(
          String label, double value, Color color, bool bold) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(_formatCurrency(value),
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: color)),
        ],
      );

  Widget _dayChip(String label, String value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label: ',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: color.withOpacity(0.7))),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      );

  Widget _actionButton(
          String label, IconData icon, Color color, VoidCallback onTap) =>
      TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════
  //  TAB 3: SUMMARY
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildSummaryTab() => Column(children: [
        _buildSummaryHeader(),
        const SizedBox(height: 12),
        Expanded(child: _buildSummaryBody()),
      ]);

  Widget _buildSummaryHeader() => Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: _sumMonth,
                  decoration:
                      _inputDecor('Month', Icons.calendar_month_outlined),
                  isExpanded: true,
                  items: _months
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(m,
                                style: GoogleFonts.poppins(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _sumMonth = v ?? _sumMonth),
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                    controller: _sumYearCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        _inputDecor('Year', Icons.date_range_outlined)),
              ),
              ElevatedButton.icon(
                onPressed: _sumLoading ? null : _loadSummary,
                icon: _sumLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.bar_chart_rounded, size: 16),
                label: Text(_sumLoading ? 'Loading...' : 'Load Summary',
                    style: GoogleFonts.poppins(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12)),
              ),
            ],
          ),
        ),
      );

  Widget _buildSummaryBody() {
    if (_sumLoading) return _buildShimmer();
    if (_sumError != null) return _buildError(_sumError!, _loadSummary);
    if (_summaryStats.isEmpty) {
      return _buildIdle('Select month/year and tap Load Summary');
    }

    final totalStaff = _summaryStats['totalStaff'] ?? 0;
    final totalGross = _toDouble(_summaryStats['totalGrossSalary']);
    final totalNet = _toDouble(_summaryStats['totalNetSalary']);
    final paidCount = _summaryStats['paidCount'] ?? 0;
    final pendingCount = _summaryStats['pendingCount'] ?? 0;
    final statusBreakdown =
        _summaryStats['statusBreakdown'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary stat cards
          Row(
            children: [
              _summaryCard('Total Staff', '$totalStaff',
                  Icons.people_outline, AppColors.navy),
              const SizedBox(width: 12),
              _summaryCard('Total Gross', _formatCurrency(totalGross),
                  Icons.account_balance_wallet_outlined, AppColors.info),
              const SizedBox(width: 12),
              _summaryCard('Total Net', _formatCurrency(totalNet),
                  Icons.payments_outlined, AppColors.gold),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryCard('Paid', '$paidCount',
                  Icons.check_circle_outline, AppColors.success),
              const SizedBox(width: 12),
              _summaryCard('Pending', '$pendingCount',
                  Icons.hourglass_empty_rounded, AppColors.warning),
              const SizedBox(width: 12),
              // Spacer card to balance the row
              Expanded(child: Container()),
            ],
          ),
          const SizedBox(height: 24),
          // Status breakdown
          Text('Status Breakdown',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 12),
          if (statusBreakdown.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: statusBreakdown.entries.map((e) {
                final color =
                    _payrollStatusColors[e.key] ?? AppColors.textSecondary;
                return Container(
                  width: 180,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(e.key,
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color)),
                      ),
                      const SizedBox(height: 8),
                      Text('${e.value}',
                          style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: color)),
                      Text('records',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                );
              }).toList(),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No status breakdown available',
                    style: GoogleFonts.poppins(
                        color: AppColors.textSecondary, fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard(
          String label, String value, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            border: Border.all(color: color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis),
                    Text(label,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildIdle(String message) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 60, color: AppColors.textLight.withOpacity(0.4)),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );

  Widget _buildShimmer() => ListView.builder(
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.creamDark,
            borderRadius: BorderRadius.circular(AppSizes.radiusLG),
          ),
        ),
      );

  Widget _buildError(String error, VoidCallback retry) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppColors.error, size: 52),
            const SizedBox(height: 12),
            Text('Failed to load',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error)),
            const SizedBox(height: 6),
            Text(error,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: retry,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white),
              child: Text('Retry', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );

  // ── Utility ───────────────────────────────────────────────────────────

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _formatCurrency(double value) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
          .format(value);
}

// ══════════════════════════════════════════════════════════════════════════
//  MARK ATTENDANCE DIALOG (extracted as a separate widget for state mgmt)
// ══════════════════════════════════════════════════════════════════════════

class _MarkAttendanceDialog extends StatefulWidget {
  final String date;
  final List<Map<String, dynamic>> entries;

  const _MarkAttendanceDialog({
    required this.date,
    required this.entries,
  });

  @override
  State<_MarkAttendanceDialog> createState() => _MarkAttendanceDialogState();
}

class _MarkAttendanceDialogState extends State<_MarkAttendanceDialog> {
  late final List<Map<String, dynamic>> _entries;
  bool _submitting = false;

  static const _statuses = [
    'PRESENT',
    'ABSENT',
    'HALF_DAY',
    'ON_LEAVE',
    'LATE',
  ];

  @override
  void initState() {
    super.initState();
    _entries = widget.entries
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final payload = _entries
          .map((e) => {
                'staffId': e['staffId'],
                'staffName': e['staffName'],
                'date': widget.date,
                'status': e['status'],
              })
          .toList();
      await StaffAttendanceApiService.markBulkAttendance(payload);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: $e', style: GoogleFonts.poppins()),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      title: Row(
        children: [
          const Icon(Icons.how_to_reg_rounded,
              color: AppColors.gold, size: 22),
          const SizedBox(width: 8),
          Text('Mark Attendance - ${widget.date}',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: AppColors.navy)),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: ListView.separated(
          itemCount: _entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final entry = _entries[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.navy.withOpacity(0.1),
                    child: Text(
                      (entry['staffName'] ?? '?')[0].toUpperCase(),
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${entry['staffName']}',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary)),
                  ),
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      value: entry['status'] ?? 'PRESENT',
                      isDense: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMD)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                      items: _statuses
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.replaceAll('_', ' '),
                                    style:
                                        GoogleFonts.poppins(fontSize: 11)),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _entries[i]['status'] = v),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: Text('Cancel',
              style: GoogleFonts.poppins(color: AppColors.textSecondary)),
        ),
        ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_rounded, size: 16),
          label: Text(_submitting ? 'Saving...' : 'Submit All',
              style: GoogleFonts.poppins()),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.white),
        ),
      ],
    );
  }
}
