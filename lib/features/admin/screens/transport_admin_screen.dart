import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/student_model.dart';
import '../../../models/transport_models.dart';
import '../../../services/student_api_service.dart';
import '../../../services/transport_api_service.dart';

class TransportAdminScreen extends StatefulWidget {
  const TransportAdminScreen({super.key});

  @override
  State<TransportAdminScreen> createState() => _TransportAdminScreenState();
}

class _TransportAdminScreenState extends State<TransportAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // ── shared data ────────────────────────────────────────────────────────────
  List<TransportBus>   _buses  = [];
  List<TransportRoute> _routes = [];
  TransportStats?      _stats;

  bool _loadingBuses  = true;
  bool _loadingRoutes = true;
  bool _loadingStats  = true;

  // ── Fleet filter ───────────────────────────────────────────────────────────
  String _statusFilter = 'ALL';

  // ── Assign tab search ──────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  List<StudentModel> _studentResults = [];
  bool _searching = false;
  Timer? _debounce;

  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  // ── lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _fetchAll();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchBuses(), _fetchRoutes(), _fetchStats()]);
  }

  Future<void> _fetchBuses() async {
    if (!mounted) return;
    setState(() => _loadingBuses = true);
    try {
      final buses = await TransportApiService.getAllBuses();
      if (!mounted) return;
      setState(() => _buses = buses);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingBuses = false);
    }
  }

  Future<void> _fetchRoutes() async {
    if (!mounted) return;
    setState(() => _loadingRoutes = true);
    try {
      final routes = await TransportApiService.getAllRoutes();
      if (!mounted) return;
      setState(() => _routes = routes);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingRoutes = false);
    }
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() => _loadingStats = true);
    try {
      final stats = await TransportApiService.getStats();
      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  // ── Assign tab search ──────────────────────────────────────────────────────

  void _onSearchChanged() {
    _debounce?.cancel();
    final q = _searchCtrl.text.trim();
    if (q.length < 2) {
      setState(() => _studentResults = []);
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 380), () => _searchStudents(q));
  }

  Future<void> _searchStudents(String q) async {
    if (!mounted) return;
    setState(() => _searching = true);
    try {
      final results = await StudentApiService.searchStudents(q);
      if (!mounted) return;
      setState(() => _studentResults = results);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  List<TransportBus> get _filteredBuses => _statusFilter == 'ALL'
      ? _buses
      : _buses.where((b) => b.status == _statusFilter).toList();

  TransportRoute? _routeById(String? id) =>
      id == null
          ? null
          : _routes.cast<TransportRoute?>().firstWhere(
                (r) => r?.id == id, orElse: () => null);

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE':      return AppColors.success;
      case 'MAINTENANCE': return AppColors.warning;
      default:            return AppColors.textLight;
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  InputDecoration _dlgDeco(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.nunitoSans(fontSize: 13),
        isDense: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            borderSide: const BorderSide(color: AppColors.navy, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  Widget _dlgField(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType type = TextInputType.text,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          decoration: _dlgDeco(label, hint: hint),
          style: GoogleFonts.nunitoSans(fontSize: 13),
        ),
      );

  // ── Bus dialogs ────────────────────────────────────────────────────────────

  void _openBusDialog({TransportBus? existing}) {
    final isEdit     = existing != null;
    final busCtrl    = TextEditingController(text: existing?.busNumber    ?? '');
    final driverCtrl = TextEditingController(text: existing?.driverName   ?? '');
    final mobileCtrl = TextEditingController(text: existing?.driverMobile ?? '');
    final capCtrl    = TextEditingController(
        text: existing != null ? existing.capacity.toString() : '');
    final insCtrl    = TextEditingController(text: existing?.insuranceExpiry ?? '');
    final notesCtrl  = TextEditingController(text: existing?.notes ?? '');
    String? routeId  = existing?.routeId;
    String  status   = existing?.status ?? 'ACTIVE';
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
          title: Text(isEdit ? 'Edit Bus' : 'Add New Bus',
              style: GoogleFonts.cormorantGaramond(
                  fontWeight: FontWeight.w700, fontSize: 20)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _dlgField(busCtrl,    'Bus Number *',       'e.g. SIA-001'),
                _dlgField(driverCtrl, 'Driver Name *',      'e.g. Ramesh Kumar'),
                _dlgField(mobileCtrl, 'Driver Mobile *',    '+91 98765 43210',
                    type: TextInputType.phone),
                _dlgField(capCtrl,    'Capacity (seats) *', 'e.g. 45',
                    type: TextInputType.number),
                const SizedBox(height: 4),
                DropdownButtonFormField<String?>(
                  value: routeId,
                  decoration: _dlgDeco('Assign Route (optional)'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('— No route —')),
                    ..._routes.map((r) => DropdownMenuItem(
                        value: r.id,
                        child: Text(r.displayName ?? r.zoneName))),
                  ],
                  onChanged: (v) => setDlg(() => routeId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: _dlgDeco('Status'),
                  items: ['ACTIVE', 'MAINTENANCE', 'RETIRED']
                      .map((s) => DropdownMenuItem(
                          value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setDlg(() => status = v ?? status),
                ),
                const SizedBox(height: 12),
                _dlgField(insCtrl,   'Insurance Expiry', 'e.g. Dec 2025'),
                _dlgField(notesCtrl, 'Notes',             'Optional'),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white),
              onPressed: saving
                  ? null
                  : () async {
                      final num = busCtrl.text.trim();
                      final drv = driverCtrl.text.trim();
                      final mob = mobileCtrl.text.trim();
                      final cap = int.tryParse(capCtrl.text.trim()) ?? 0;
                      if (num.isEmpty || drv.isEmpty ||
                          mob.isEmpty || cap <= 0) {
                        _showSnack('Fill all required fields.',
                            isError: true);
                        return;
                      }
                      setDlg(() => saving = true);
                      try {
                        final data = {
                          'busNumber':       num,
                          'driverName':      drv,
                          'driverMobile':    mob,
                          'capacity':        cap,
                          if (routeId != null) 'routeId': routeId,
                          'status':          status,
                          if (insCtrl.text.trim().isNotEmpty)
                            'insuranceExpiry': insCtrl.text.trim(),
                          if (notesCtrl.text.trim().isNotEmpty)
                            'notes': notesCtrl.text.trim(),
                        };
                        if (isEdit) {
                          final updated = await TransportApiService.updateBus(
                              existing!.id!, data);
                          if (!mounted) return;
                          setState(() {
                            final i =
                                _buses.indexWhere((b) => b.id == existing.id);
                            if (i != -1) _buses[i] = updated;
                          });
                        } else {
                          final created =
                              await TransportApiService.createBus(data);
                          if (!mounted) return;
                          setState(() => _buses.add(created));
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSnack(
                            isEdit ? 'Bus updated.' : 'Bus added.');
                        _fetchStats();
                      } catch (e) {
                        _showSnack('Error: $e', isError: true);
                      } finally {
                        setDlg(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(isEdit ? 'Update' : 'Add Bus'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBus(TransportBus bus) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bus'),
        content: Text(
            'Remove bus ${bus.busNumber}? Students on this bus will be unassigned.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await TransportApiService.deleteBus(bus.id!);
      setState(() => _buses.removeWhere((b) => b.id == bus.id));
      _showSnack('Bus ${bus.busNumber} removed.');
      _fetchStats();
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  void _openRosterSheet(TransportBus bus) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _RosterSheet(bus: bus, routeById: _routeById),
    );
  }

  // ── Route dialogs ──────────────────────────────────────────────────────────

  void _openRouteDialog({TransportRoute? existing}) {
    final isEdit    = existing != null;
    final zoneCtrl  = TextEditingController(text: existing?.zoneName       ?? '');
    final nameCtrl  = TextEditingController(text: existing?.displayName    ?? '');
    final areasCtrl = TextEditingController(text: existing?.areasCovered   ?? '');
    final stopsCtrl = TextEditingController(
        text: existing?.stops.join(', ') ?? '');
    final timeCtrl  = TextEditingController(
        text: existing?.firstPickupTime ?? '');
    final feeCtrl   = TextEditingController(
        text: existing != null
            ? existing.monthlyFee.toStringAsFixed(0) : '');
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
          title: Text(isEdit ? 'Edit Route' : 'Add New Route',
              style: GoogleFonts.cormorantGaramond(
                  fontWeight: FontWeight.w700, fontSize: 20)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _dlgField(zoneCtrl,  'Zone Name *',
                    'e.g. Zone A'),
                _dlgField(nameCtrl,  'Display Name',
                    'e.g. Zone A – North'),
                _dlgField(areasCtrl, 'Areas Covered *',
                    'e.g. Rajpur, Saket, Vasant Kunj'),
                _dlgField(stopsCtrl, 'Stops (comma-separated) *',
                    'e.g. School Gate, Stop 1, Stop 2'),
                _dlgField(timeCtrl,  'First Pickup Time *',
                    'e.g. 7:10 AM'),
                _dlgField(feeCtrl,   'Monthly Fee (₹) *', 'e.g. 800',
                    type: TextInputType.number),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white),
              onPressed: saving
                  ? null
                  : () async {
                      final zone  = zoneCtrl.text.trim();
                      final areas = areasCtrl.text.trim();
                      final stops = stopsCtrl.text.trim();
                      final time  = timeCtrl.text.trim();
                      final fee   =
                          double.tryParse(feeCtrl.text.trim()) ?? 0;
                      if (zone.isEmpty || areas.isEmpty ||
                          stops.isEmpty || time.isEmpty || fee <= 0) {
                        _showSnack('Fill all required fields.',
                            isError: true);
                        return;
                      }
                      setDlg(() => saving = true);
                      try {
                        final data = {
                          'zoneName':       zone,
                          if (nameCtrl.text.trim().isNotEmpty)
                            'displayName': nameCtrl.text.trim(),
                          'areasCovered':   areas,
                          'stops':          stops
                              .split(',')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList(),
                          'firstPickupTime': time,
                          'monthlyFee':      fee,
                        };
                        if (isEdit) {
                          final updated =
                              await TransportApiService.updateRoute(
                                  existing!.id!, data);
                          if (!mounted) return;
                          setState(() {
                            final i = _routes
                                .indexWhere((r) => r.id == existing.id);
                            if (i != -1) _routes[i] = updated;
                          });
                        } else {
                          final created =
                              await TransportApiService.createRoute(data);
                          if (!mounted) return;
                          setState(() => _routes.add(created));
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSnack(
                            isEdit ? 'Route updated.' : 'Route added.');
                        _fetchStats();
                      } catch (e) {
                        _showSnack('Error: $e', isError: true);
                      } finally {
                        setDlg(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(isEdit ? 'Update' : 'Add Route'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRoute(TransportRoute route) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text(
            'Remove "${route.displayName ?? route.zoneName}"? '
            'Buses linked to this route will become unassigned.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await TransportApiService.deleteRoute(route.id!);
      setState(() => _routes.removeWhere((r) => r.id == route.id));
      _showSnack('Route removed.');
      _fetchStats();
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  // ── Assign dialog ──────────────────────────────────────────────────────────

  Future<void> _openAssignDialog(StudentModel student) async {
    StudentTransportAssignment? current;
    try {
      current = await TransportApiService.getStudentAssignment(student.id!);
    } catch (_) {}
    if (!mounted) return;

    String? selectedBusId   = current?.busId;
    String? selectedRouteId = current?.routeId;
    final stopCtrl = TextEditingController(text: current?.pickupStop ?? '');
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          // Find bus name for current assignment display
          String currentBusLabel = 'Unknown';
          if (current != null) {
            try {
              final b = _buses.firstWhere((b) => b.id == current!.busId);
              currentBusLabel = b.busNumber;
            } catch (_) {}
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
            title: Text(
              current != null ? 'Reassign Student' : 'Assign to Bus',
              style: GoogleFonts.cormorantGaramond(
                  fontWeight: FontWeight.w700, fontSize: 20),
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Student card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withOpacity(0.06),
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMD),
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          backgroundColor: AppColors.navy,
                          radius: 20,
                          child: Text(
                            student.fullName.isNotEmpty
                                ? student.fullName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(student.fullName,
                                  style: GoogleFonts.nunitoSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              Text(
                                '${student.classForAdmission ?? "—"}'
                                '${student.rollNumber != null ? " · Roll ${student.rollNumber}" : ""}',
                                style: GoogleFonts.nunitoSans(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                    if (current != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.12),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD),
                          border: Border.all(
                              color: AppColors.warning.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 14, color: AppColors.warning),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Currently on bus $currentBusLabel. '
                              'Saving will reassign.',
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 11, color: AppColors.warning),
                            ),
                          ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Bus picker
                    DropdownButtonFormField<String?>(
                      value: selectedBusId,
                      decoration: _dlgDeco('Select Bus *'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('— Choose bus —')),
                        ..._buses
                            .where((b) => b.status == 'ACTIVE')
                            .map((b) {
                          final r = _routeById(b.routeId);
                          final routeLabel = r?.displayName ??
                              r?.zoneName ?? 'No route';
                          return DropdownMenuItem(
                            value: b.id,
                            child: Text(
                              '${b.busNumber}  ·  $routeLabel  ·  ${b.assignedCount}/${b.capacity}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (v) {
                        setDlg(() {
                          selectedBusId = v;
                          if (v != null) {
                            try {
                              final bus =
                                  _buses.firstWhere((b) => b.id == v);
                              selectedRouteId = bus.routeId;
                            } catch (_) {}
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Route picker
                    DropdownButtonFormField<String?>(
                      value: selectedRouteId,
                      decoration: _dlgDeco('Route'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('— Choose route —')),
                        ..._routes.map((r) => DropdownMenuItem(
                            value: r.id,
                            child: Text(r.displayName ?? r.zoneName))),
                      ],
                      onChanged: (v) =>
                          setDlg(() => selectedRouteId = v),
                    ),
                    const SizedBox(height: 12),
                    _dlgField(stopCtrl, 'Boarding Stop',
                        'e.g. Saket Bus Stop'),
                  ],
                ),
              ),
            ),
            actions: [
              if (current != null)
                TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.error),
                  onPressed: saving
                      ? null
                      : () async {
                          setDlg(() => saving = true);
                          try {
                            await TransportApiService.removeAssignment(
                                current!.id!);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showSnack('Assignment removed.');
                            _fetchBuses();
                            _fetchStats();
                          } catch (e) {
                            _showSnack('Error: $e', isError: true);
                          } finally {
                            setDlg(() => saving = false);
                          }
                        },
                  child: const Text('Remove'),
                ),
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white),
                onPressed: saving || selectedBusId == null
                    ? null
                    : () async {
                        setDlg(() => saving = true);
                        try {
                          await TransportApiService.assignStudent({
                            'studentId':   student.id,
                            'studentName': student.fullName,
                            'className':   student.classForAdmission ?? '',
                            'rollNumber':  student.rollNumber,
                            'busId':       selectedBusId,
                            if (selectedRouteId != null)
                              'routeId': selectedRouteId,
                            if (stopCtrl.text.trim().isNotEmpty)
                              'pickupStop': stopCtrl.text.trim(),
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          _showSnack('Student assigned successfully.');
                          _fetchBuses();
                          _fetchStats();
                        } catch (e) {
                          _showSnack('Error: $e', isError: true);
                        } finally {
                          setDlg(() => saving = false);
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(current != null ? 'Reassign' : 'Assign'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Transport Management',
            style: GoogleFonts.cormorantGaramond(
                fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: AppColors.gold,
          labelStyle: GoogleFonts.nunitoSans(
              fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.directions_bus_rounded, size: 18),
                text: 'Fleet'),
            Tab(icon: Icon(Icons.route_rounded, size: 18),
                text: 'Routes'),
            Tab(icon: Icon(Icons.person_pin_circle_rounded, size: 18),
                text: 'Assign'),
          ],
        ),
      ),
      body: Column(children: [
        _buildStatsStrip(),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _buildFleetTab(),
              _buildRoutesTab(),
              _buildAssignTab(),
            ],
          ),
        ),
      ]),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (_, __) {
          if (_tabs.index == 0) {
            return FloatingActionButton.extended(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Bus'),
              onPressed: () => _openBusDialog(),
            );
          }
          if (_tabs.index == 1) {
            return FloatingActionButton.extended(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Route'),
              onPressed: () => _openRouteDialog(),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // ── stats strip ────────────────────────────────────────────────────────────

  Widget _buildStatsStrip() {
    if (_loadingStats && _stats == null) {
      return Container(
          height: 50,
          color: AppColors.navyDark,
          child: const Center(
              child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white38))));
    }
    final s = _stats;
    return Container(
      color: AppColors.navyDark,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(children: [
        _statCell('Total Buses',   '${s?.totalBuses ?? _buses.length}', Colors.white),
        _vDivider(),
        _statCell('Active',        '${s?.activeBuses ?? 0}',            AppColors.goldLight),
        _vDivider(),
        _statCell('Maintenance',   '${s?.maintenanceBuses ?? 0}',       Colors.orange.shade300),
        _vDivider(),
        _statCell('Routes',        '${s?.totalRoutes ?? _routes.length}', Colors.white),
        _vDivider(),
        _statCell('Students\nAssigned', '${s?.totalStudentsAssigned ?? 0}', AppColors.goldLight),
      ]),
    );
  }

  Widget _statCell(String label, String value, Color vc) => Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(value,
              style: GoogleFonts.nunitoSans(
                  color: vc, fontWeight: FontWeight.w800, fontSize: 14)),
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                  color: Colors.white54, fontSize: 9)),
        ]),
      );

  Widget _vDivider() => Container(
      width: 1, height: 28,
      color: Colors.white12,
      margin: const EdgeInsets.symmetric(horizontal: 2));

  // ── Fleet tab ──────────────────────────────────────────────────────────────

  Widget _buildFleetTab() {
    return Column(children: [
      Container(
        color: AppColors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          Text('Filter:',
              style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          ...['ALL', 'ACTIVE', 'MAINTENANCE', 'RETIRED'].map((s) {
            final active = _statusFilter == s;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() => _statusFilter = s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: active ? AppColors.navy : Colors.transparent,
                    border: Border.all(
                        color: active ? AppColors.navy : AppColors.border),
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusMD),
                  ),
                  child: Text(s,
                      style: GoogleFonts.nunitoSans(
                          fontSize: 12,
                          color: active
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w500)),
                ),
              ),
            );
          }),
        ]),
      ),
      Expanded(
        child: _loadingBuses && _buses.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _filteredBuses.isEmpty
                ? _emptyState(
                    Icons.directions_bus_outlined,
                    _statusFilter == 'ALL'
                        ? 'No buses added yet'
                        : 'No buses with status $_statusFilter',
                    'Tap "+ Add Bus" to register a vehicle',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredBuses.length,
                    itemBuilder: (_, i) {
                      final bus = _filteredBuses[i];
                      return _BusCard(
                        bus:         bus,
                        route:       _routeById(bus.routeId),
                        statusColor: _statusColor(bus.status),
                        onEdit:      () => _openBusDialog(existing: bus),
                        onDelete:    () => _deleteBus(bus),
                        onRoster:    () => _openRosterSheet(bus),
                        onMaintenance: () async {
                          final newStatus = bus.status == 'MAINTENANCE'
                              ? 'ACTIVE' : 'MAINTENANCE';
                          try {
                            final updated = await TransportApiService
                                .updateBus(bus.id!, {
                              ...bus.toJson(),
                              'status': newStatus,
                            });
                            if (!mounted) return;
                            setState(() {
                              final idx = _buses
                                  .indexWhere((b) => b.id == bus.id);
                              if (idx != -1) _buses[idx] = updated;
                            });
                            _showSnack('Status → $newStatus');
                          } catch (e) {
                            _showSnack('Error: $e', isError: true);
                          }
                        },
                      );
                    },
                  ),
      ),
    ]);
  }

  // ── Routes tab ─────────────────────────────────────────────────────────────

  Widget _buildRoutesTab() {
    if (_loadingRoutes && _routes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_routes.isEmpty) {
      return _emptyState(
        Icons.route_rounded,
        'No routes configured',
        'Tap "+ Add Route" to create a transport zone',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _routes.length,
      itemBuilder: (_, i) => _RouteCard(
        route:    _routes[i],
        currency: _currency,
        onEdit:   () => _openRouteDialog(existing: _routes[i]),
        onDelete: () => _deleteRoute(_routes[i]),
      ),
    );
  }

  // ── Assign tab ─────────────────────────────────────────────────────────────

  Widget _buildAssignTab() {
    return Column(children: [
      Container(
        color: AppColors.white,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search student by name…',
            hintStyle: GoogleFonts.nunitoSans(
                fontSize: 13, color: AppColors.textLight),
            prefixIcon: const Icon(Icons.search_rounded,
                size: 18, color: AppColors.textLight),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            size: 18, color: AppColors.textLight),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _studentResults = []);
                        })
                    : null,
            isDense: true,
            filled: true,
            fillColor: AppColors.cream,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                borderSide:
                    const BorderSide(color: AppColors.navy, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
      Expanded(
        child: _searchCtrl.text.length < 2
            ? _assignHint()
            : _studentResults.isEmpty && !_searching
                ? _emptyState(
                    Icons.search_off_rounded,
                    'No students found',
                    'Try a different name',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _studentResults.length,
                    itemBuilder: (_, i) {
                      final s = _studentResults[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppSizes.radiusLG)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.navy.withOpacity(0.1),
                            child: Text(
                              s.fullName.isNotEmpty
                                  ? s.fullName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(s.fullName,
                              style: GoogleFonts.nunitoSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          subtitle: Text(
                            '${s.classForAdmission ?? "—"}'
                            '${s.rollNumber != null ? " · Roll ${s.rollNumber}" : ""}',
                            style: GoogleFonts.nunitoSans(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              textStyle: GoogleFonts.nunitoSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                            onPressed: () => _openAssignDialog(s),
                            child: const Text('Assign'),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }

  Widget _assignHint() => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(Icons.person_search_rounded,
              size: 64,
              color: AppColors.textLight.withOpacity(0.35)),
          const SizedBox(height: 16),
          Text('Search a student',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 6),
          Text(
            'Type at least 2 characters to find a student\nand assign them to a bus route.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary, fontSize: 13),
          ),
        ]),
      );

  Widget _emptyState(IconData icon, String title, String sub) => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(icon, size: 56,
              color: AppColors.textLight.withOpacity(0.35)),
          const SizedBox(height: 14),
          Text(title,
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 6),
          Text(sub,
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 13)),
        ]),
      );
}

// ─── Bus Card ─────────────────────────────────────────────────────────────────

class _BusCard extends StatelessWidget {
  final TransportBus    bus;
  final TransportRoute? route;
  final Color           statusColor;
  final VoidCallback    onEdit;
  final VoidCallback    onDelete;
  final VoidCallback    onRoster;
  final VoidCallback    onMaintenance;

  const _BusCard({
    required this.bus,
    required this.route,
    required this.statusColor,
    required this.onEdit,
    required this.onDelete,
    required this.onRoster,
    required this.onMaintenance,
  });

  @override
  Widget build(BuildContext context) {
    final pct      = bus.capacity > 0 ? bus.assignedCount / bus.capacity : 0.0;
    final barColor = pct >= 1.0
        ? AppColors.error
        : pct > 0.8
            ? AppColors.warning
            : AppColors.success;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── header row ──
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.navy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
              child: const Icon(Icons.directions_bus_rounded,
                  color: AppColors.navy, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(bus.busNumber,
                    style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.navy)),
                Text(
                  route?.displayName ?? route?.zoneName ??
                      'No route assigned',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: statusColor.withOpacity(0.4)),
              ),
              child: Text(bus.status,
                  style: GoogleFonts.nunitoSans(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.w700)),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: 20, color: AppColors.textLight),
              onSelected: (v) {
                switch (v) {
                  case 'edit':        onEdit();        break;
                  case 'roster':      onRoster();      break;
                  case 'maintenance': onMaintenance(); break;
                  case 'delete':      onDelete();      break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit Bus'))),
                const PopupMenuItem(
                    value: 'roster',
                    child: ListTile(
                        dense: true,
                        leading: Icon(Icons.people_outlined),
                        title: Text('View Roster'))),
                PopupMenuItem(
                    value: 'maintenance',
                    child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.build_outlined),
                        title: Text(bus.status == 'MAINTENANCE'
                            ? 'Mark Active'
                            : 'Mark Maintenance'))),
                const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                        dense: true,
                        leading: Icon(Icons.delete_outline,
                            color: AppColors.error),
                        title: Text('Delete',
                            style:
                                TextStyle(color: AppColors.error)))),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          // ── driver row ──
          Row(children: [
            const Icon(Icons.person_outline_rounded,
                size: 14, color: AppColors.textLight),
            const SizedBox(width: 5),
            Text(bus.driverName,
                style: GoogleFonts.nunitoSans(fontSize: 12)),
            const SizedBox(width: 16),
            const Icon(Icons.phone_outlined,
                size: 14, color: AppColors.textLight),
            const SizedBox(width: 5),
            Text(bus.driverMobile,
                style: GoogleFonts.nunitoSans(
                    fontSize: 12, color: AppColors.info)),
          ]),
          const SizedBox(height: 10),
          // ── capacity bar ──
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                  Text('Occupancy',
                      style: GoogleFonts.nunitoSans(
                          fontSize: 11, color: AppColors.textLight)),
                  Text('${bus.assignedCount} / ${bus.capacity}',
                      style: GoogleFonts.nunitoSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: barColor)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ]),
            ),
            if (bus.insuranceExpiry != null) ...[
              const SizedBox(width: 16),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                Text('Insurance',
                    style: GoogleFonts.nunitoSans(
                        fontSize: 10, color: AppColors.textLight)),
                Text(bus.insuranceExpiry!,
                    style: GoogleFonts.nunitoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
              ]),
            ],
          ]),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onRoster,
            child: Text(
              'View ${bus.assignedCount} students on this bus →',
              style: GoogleFonts.nunitoSans(
                  fontSize: 11,
                  color: AppColors.navy,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Route Card ───────────────────────────────────────────────────────────────

class _RouteCard extends StatefulWidget {
  final TransportRoute route;
  final NumberFormat   currency;
  final VoidCallback   onEdit;
  final VoidCallback   onDelete;

  const _RouteCard({
    required this.route,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<_RouteCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.route;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
              child: const Icon(Icons.route_rounded,
                  color: AppColors.gold, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(r.displayName ?? r.zoneName,
                    style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.navy)),
                Text(r.areasCovered,
                    style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: 20, color: AppColors.textLight),
              onSelected: (v) {
                if (v == 'edit') widget.onEdit();
                if (v == 'delete') widget.onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit Route'))),
                const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                        dense: true,
                        leading: Icon(Icons.delete_outline,
                            color: AppColors.error),
                        title: Text('Delete',
                            style:
                                TextStyle(color: AppColors.error)))),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 16, children: [
            _chip(Icons.schedule_rounded, r.firstPickupTime),
            _chip(Icons.currency_rupee_rounded,
                '${widget.currency.format(r.monthlyFee).replaceFirst("₹", "").trim()} / month'),
            _chip(Icons.group_rounded,
                '${r.assignedCount} students'),
          ]),
          if (r.stops.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(children: [
                Text('${r.stops.length} stops',
                    style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        color: AppColors.navy,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18, color: AppColors.navy,
                ),
              ]),
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: r.stops
                    .map((s) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.creamDark,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.border),
                          ),
                          child: Text(s,
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 11)),
                        ))
                    .toList(),
              ),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.nunitoSans(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      );
}

// ─── Roster Bottom Sheet ──────────────────────────────────────────────────────

class _RosterSheet extends StatefulWidget {
  final TransportBus                      bus;
  final TransportRoute? Function(String?) routeById;

  const _RosterSheet({required this.bus, required this.routeById});

  @override
  State<_RosterSheet> createState() => _RosterSheetState();
}

class _RosterSheetState extends State<_RosterSheet> {
  List<StudentTransportAssignment> _roster = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await TransportApiService.getBusRoster(widget.bus.id!);
      if (mounted) setState(() => _roster = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(StudentTransportAssignment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text('Remove ${a.studentName} from this bus?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await TransportApiService.removeAssignment(a.id!);
      if (!mounted) return;
      setState(() => _roster.removeWhere((r) => r.id == a.id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Student removed from bus.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.routeById(widget.bus.routeId);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Column(children: [
        // drag handle
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Bus ${widget.bus.busNumber} — Roster',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy)),
                Text(
                  route?.displayName ?? route?.zoneName ??
                      widget.bus.driverName,
                  style: GoogleFonts.nunitoSans(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.navy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _loading
                    ? '— / ${widget.bus.capacity}'
                    : '${_roster.length} / ${widget.bus.capacity}',
                style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.navy),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _roster.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.person_off_outlined,
                            size: 48,
                            color: AppColors.textLight.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text('No students assigned yet',
                            style: GoogleFonts.nunitoSans(
                                color: AppColors.textSecondary)),
                      ]),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _roster.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final a = _roster[i];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                AppColors.navy.withOpacity(0.08),
                            child: Text(
                              a.studentName.isNotEmpty
                                  ? a.studentName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ),
                          title: Text(a.studentName,
                              style: GoogleFonts.nunitoSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          subtitle: Text(
                            '${a.className}'
                            '${a.rollNumber != null ? " · Roll ${a.rollNumber}" : ""}'
                            '${a.pickupStop != null ? " · ${a.pickupStop}" : ""}',
                            style: GoogleFonts.nunitoSans(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                                Icons.remove_circle_outline,
                                color: AppColors.error, size: 20),
                            tooltip: 'Remove from bus',
                            onPressed: () => _remove(a),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
