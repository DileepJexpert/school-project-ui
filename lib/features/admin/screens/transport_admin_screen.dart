import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
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
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  final _currency = NumberFormat.currency(symbol: 'INR ', decimalDigits: 0);

  List<TransportBus> _buses = [];
  List<TransportRoute> _routes = [];
  List<StudentModel> _studentResults = [];
  TransportStats? _stats;
  Timer? _debounce;

  bool _loadingBuses = true;
  bool _loadingRoutes = true;
  bool _loadingStats = true;
  bool _searching = false;
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _searchCtrl.addListener(_onSearchChanged);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TransportBus> get _filteredBuses {
    if (_statusFilter == 'ALL') return _buses;
    return _buses.where((bus) => bus.status == _statusFilter).toList();
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
    } catch (e) {
      _snack('Could not load buses: $e', isError: true);
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
    } catch (e) {
      _snack('Could not load routes: $e', isError: true);
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
      // The metrics strip can fall back to locally loaded lists.
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final query = _searchCtrl.text.trim();
    if (query.length < 2) {
      setState(() => _studentResults = []);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchStudents(query),
    );
  }

  Future<void> _searchStudents(String query) async {
    if (!mounted) return;
    setState(() => _searching = true);
    try {
      final results = await StudentApiService.searchStudents(query);
      if (!mounted) return;
      setState(() => _studentResults = results);
    } catch (e) {
      _snack('Student search failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  TransportRoute? _routeById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final route in _routes) {
      if (route.id == id) return route;
    }
    return null;
  }

  Color _statusColor(String status) {
    return switch (status) {
      'ACTIVE' => AppColors.success,
      'MAINTENANCE' => AppColors.warning,
      'RETIRED' => AppColors.textSecondary,
      _ => AppColors.info,
    };
  }

  Future<void> _openBusDialog({TransportBus? existing}) async {
    final isEdit = existing != null;
    final busCtrl = TextEditingController(text: existing?.busNumber ?? '');
    final driverCtrl = TextEditingController(text: existing?.driverName ?? '');
    final mobileCtrl =
        TextEditingController(text: existing?.driverMobile ?? '');
    final capacityCtrl = TextEditingController(
      text: existing == null ? '' : existing.capacity.toString(),
    );
    final insuranceCtrl =
        TextEditingController(text: existing?.insuranceExpiry ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String status = existing?.status ?? 'ACTIVE';
    String? routeId = existing?.routeId;
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit() async {
            if (busCtrl.text.trim().isEmpty ||
                driverCtrl.text.trim().isEmpty ||
                mobileCtrl.text.trim().isEmpty) {
              _snack('Bus number, driver and mobile are required.',
                  isError: true);
              return;
            }

            setDialogState(() => saving = true);
            final payload = {
              'busNumber': busCtrl.text.trim(),
              'driverName': driverCtrl.text.trim(),
              'driverMobile': mobileCtrl.text.trim(),
              'capacity': int.tryParse(capacityCtrl.text.trim()) ?? 0,
              'status': status,
              if (routeId != null) 'routeId': routeId,
              if (insuranceCtrl.text.trim().isNotEmpty)
                'insuranceExpiry': insuranceCtrl.text.trim(),
              if (notesCtrl.text.trim().isNotEmpty)
                'notes': notesCtrl.text.trim(),
            };

            try {
              if (isEdit) {
                await TransportApiService.updateBus(existing.id!, payload);
                _snack('Bus updated.');
              } else {
                await TransportApiService.createBus(payload);
                _snack('Bus added.');
              }
              await _fetchBuses();
              await _fetchStats();
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              _snack('Could not save bus: $e', isError: true);
              setDialogState(() => saving = false);
            }
          }

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
            contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            actionsPadding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
            title: _DialogTitle(
              icon: Icons.directions_bus_outlined,
              title: isEdit ? 'Edit bus' : 'Add bus',
            ),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FormGrid(
                      children: [
                        TextField(
                          controller: busCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Bus number'),
                        ),
                        TextField(
                          controller: driverCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Driver name'),
                        ),
                        TextField(
                          controller: mobileCtrl,
                          keyboardType: TextInputType.phone,
                          decoration:
                              const InputDecoration(labelText: 'Driver mobile'),
                        ),
                        TextField(
                          controller: capacityCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Capacity'),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: status,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Status'),
                          items: ['ACTIVE', 'MAINTENANCE', 'RETIRED']
                              .map((item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(_pretty(item)),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => status = value ?? status),
                        ),
                        DropdownButtonFormField<String?>(
                          initialValue: routeId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Route'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('No route'),
                            ),
                            ..._routes.map(
                              (route) => DropdownMenuItem<String?>(
                                value: route.id,
                                child: Text(_routeName(route)),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setDialogState(() => routeId = value),
                        ),
                        TextField(
                          controller: insuranceCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Insurance expiry',
                            hintText: 'Example: Dec 2026',
                          ),
                        ),
                        TextField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(labelText: 'Notes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: saving ? null : submit,
                icon: saving
                    ? const _ButtonSpinner()
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(saving ? 'Saving...' : 'Save'),
              ),
            ],
          );
        },
      ),
    );

    busCtrl.dispose();
    driverCtrl.dispose();
    mobileCtrl.dispose();
    capacityCtrl.dispose();
    insuranceCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _deleteBus(TransportBus bus) async {
    final confirmed = await _confirm(
      title: 'Delete bus',
      message: 'Delete bus ${bus.busNumber}?',
    );
    if (confirmed != true || bus.id == null) return;

    try {
      await TransportApiService.deleteBus(bus.id!);
      await _fetchBuses();
      await _fetchStats();
      _snack('Bus deleted.');
    } catch (e) {
      _snack('Could not delete bus: $e', isError: true);
    }
  }

  Future<void> _openRouteDialog({TransportRoute? existing}) async {
    final isEdit = existing != null;
    final zoneCtrl = TextEditingController(text: existing?.zoneName ?? '');
    final displayCtrl =
        TextEditingController(text: existing?.displayName ?? '');
    final areasCtrl = TextEditingController(text: existing?.areasCovered ?? '');
    final stopsCtrl =
        TextEditingController(text: existing?.stops.join(', ') ?? '');
    final pickupCtrl =
        TextEditingController(text: existing?.firstPickupTime ?? '');
    final feeCtrl = TextEditingController(
      text: existing == null ? '' : existing.monthlyFee.toStringAsFixed(0),
    );
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit() async {
            if (zoneCtrl.text.trim().isEmpty) {
              _snack('Zone name is required.', isError: true);
              return;
            }
            setDialogState(() => saving = true);
            final payload = {
              'zoneName': zoneCtrl.text.trim(),
              if (displayCtrl.text.trim().isNotEmpty)
                'displayName': displayCtrl.text.trim(),
              'areasCovered': areasCtrl.text.trim(),
              'stops': stopsCtrl.text
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList(),
              'firstPickupTime': pickupCtrl.text.trim(),
              'monthlyFee': double.tryParse(feeCtrl.text.trim()) ?? 0,
            };

            try {
              if (isEdit) {
                await TransportApiService.updateRoute(existing.id!, payload);
                _snack('Route updated.');
              } else {
                await TransportApiService.createRoute(payload);
                _snack('Route added.');
              }
              await _fetchRoutes();
              await _fetchStats();
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              _snack('Could not save route: $e', isError: true);
              setDialogState(() => saving = false);
            }
          }

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
            contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            actionsPadding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
            title: _DialogTitle(
              icon: Icons.route_outlined,
              title: isEdit ? 'Edit route' : 'Add route',
            ),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: _FormGrid(
                  children: [
                    TextField(
                      controller: zoneCtrl,
                      decoration: const InputDecoration(labelText: 'Zone name'),
                    ),
                    TextField(
                      controller: displayCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Display name'),
                    ),
                    TextField(
                      controller: areasCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Areas covered'),
                    ),
                    TextField(
                      controller: stopsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Stops',
                        hintText: 'Comma separated',
                      ),
                    ),
                    TextField(
                      controller: pickupCtrl,
                      decoration: const InputDecoration(
                        labelText: 'First pickup time',
                        hintText: 'Example: 07:10 AM',
                      ),
                    ),
                    TextField(
                      controller: feeCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Monthly fee'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: saving ? null : submit,
                icon: saving
                    ? const _ButtonSpinner()
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(saving ? 'Saving...' : 'Save'),
              ),
            ],
          );
        },
      ),
    );

    zoneCtrl.dispose();
    displayCtrl.dispose();
    areasCtrl.dispose();
    stopsCtrl.dispose();
    pickupCtrl.dispose();
    feeCtrl.dispose();
  }

  Future<void> _deleteRoute(TransportRoute route) async {
    final confirmed = await _confirm(
      title: 'Delete route',
      message: 'Delete route ${_routeName(route)}?',
    );
    if (confirmed != true || route.id == null) return;

    try {
      await TransportApiService.deleteRoute(route.id!);
      await _fetchRoutes();
      await _fetchStats();
      _snack('Route deleted.');
    } catch (e) {
      _snack('Could not delete route: $e', isError: true);
    }
  }

  Future<void> _openAssignDialog(StudentModel student) async {
    if (student.id == null) return;

    StudentTransportAssignment? current =
        await TransportApiService.getStudentAssignment(student.id!);
    if (!mounted) return;

    String? selectedBusId = current?.busId;
    String? selectedRouteId = current?.routeId;
    final stopCtrl = TextEditingController(text: current?.pickupStop ?? '');
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> remove() async {
            if (current?.id == null) return;
            setDialogState(() => saving = true);
            try {
              await TransportApiService.removeAssignment(current!.id!);
              await _fetchBuses();
              await _fetchStats();
              _snack('Assignment removed.');
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              _snack('Could not remove assignment: $e', isError: true);
              setDialogState(() => saving = false);
            }
          }

          Future<void> save() async {
            if (selectedBusId == null || selectedRouteId == null) {
              _snack('Select both bus and route.', isError: true);
              return;
            }
            setDialogState(() => saving = true);
            try {
              await TransportApiService.assignStudent({
                'studentId': student.id,
                'studentName': student.fullName,
                'className': student.classForAdmission ?? '',
                'rollNumber': student.rollNumber,
                'busId': selectedBusId,
                'routeId': selectedRouteId,
                if (stopCtrl.text.trim().isNotEmpty)
                  'pickupStop': stopCtrl.text.trim(),
              });
              await _fetchBuses();
              await _fetchStats();
              _snack(current == null
                  ? 'Student assigned.'
                  : 'Student reassigned.');
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              _snack('Could not assign student: $e', isError: true);
              setDialogState(() => saving = false);
            }
          }

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
            contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            actionsPadding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
            title: _DialogTitle(
              icon: Icons.person_pin_circle_outlined,
              title: current == null ? 'Assign student' : 'Reassign student',
            ),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StudentMiniCard(student: student),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBusId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Bus'),
                    items: _buses
                        .where((bus) => bus.status == 'ACTIVE')
                        .map((bus) {
                      final route = _routeById(bus.routeId);
                      return DropdownMenuItem(
                        value: bus.id,
                        child: Text(
                          '${bus.busNumber} | ${_routeName(route)} | ${bus.assignedCount}/${bus.capacity}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedBusId = value;
                        final bus = _buses
                            .where((item) => item.id == value)
                            .firstOrNull;
                        selectedRouteId = bus?.routeId ?? selectedRouteId;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRouteId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Route'),
                    items: _routes
                        .map(
                          (route) => DropdownMenuItem(
                            value: route.id,
                            child: Text(_routeName(route)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedRouteId = value),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: stopCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Pickup stop',
                      hintText: 'Example: Main Gate',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (current != null)
                TextButton(
                  onPressed: saving ? null : remove,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Remove'),
                ),
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: saving ? null : save,
                icon: saving
                    ? const _ButtonSpinner()
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(saving ? 'Saving...' : 'Save'),
              ),
            ],
          );
        },
      ),
    );

    stopCtrl.dispose();
  }

  void _openRosterSheet(TransportBus bus) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RosterSheet(
        bus: bus,
        routeById: _routeById,
        onChanged: () async {
          await _fetchBuses();
          await _fetchStats();
        },
      ),
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.contentPadding(context);

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          _buildMetrics(),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: context.palette.surface,
              border: Border.all(color: context.palette.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              labelColor: context.palette.brand,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: context.palette.brand,
              labelStyle: GoogleFonts.nunitoSans(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
              tabs: const [
                Tab(icon: Icon(Icons.directions_bus_outlined), text: 'Fleet'),
                Tab(icon: Icon(Icons.route_outlined), text: 'Routes'),
                Tab(
                    icon: Icon(Icons.person_pin_circle_outlined),
                    text: 'Assign'),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: context.palette.heroGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transport',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage fleet, routes and student bus assignments from one compact desk.',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
            ),
            onPressed: _fetchAll,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    final stats = _stats;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final width = compact
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 40) / 5;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricCard(
              width: width,
              label: 'Buses',
              value: '${stats?.totalBuses ?? _buses.length}',
              icon: Icons.directions_bus_outlined,
              color: context.palette.brand,
              loading: _loadingStats && stats == null,
            ),
            _MetricCard(
              width: width,
              label: 'Active',
              value:
                  '${stats?.activeBuses ?? _buses.where((b) => b.status == 'ACTIVE').length}',
              icon: Icons.check_circle_outline,
              color: AppColors.success,
              loading: _loadingStats && stats == null,
            ),
            _MetricCard(
              width: width,
              label: 'Maintenance',
              value:
                  '${stats?.maintenanceBuses ?? _buses.where((b) => b.status == 'MAINTENANCE').length}',
              icon: Icons.build_outlined,
              color: AppColors.warning,
              loading: _loadingStats && stats == null,
            ),
            _MetricCard(
              width: width,
              label: 'Routes',
              value: '${stats?.totalRoutes ?? _routes.length}',
              icon: Icons.route_outlined,
              color: AppColors.info,
              loading: _loadingStats && stats == null,
            ),
            _MetricCard(
              width: width,
              label: 'Assigned',
              value:
                  '${stats?.totalStudentsAssigned ?? _buses.fold<int>(0, (sum, bus) => sum + bus.assignedCount)}',
              icon: Icons.groups_outlined,
              color: AppColors.success,
              loading: _loadingStats && stats == null,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFleetTab() {
    if (_loadingBuses && _buses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _FleetToolbar(
          selected: _statusFilter,
          onChanged: (value) => setState(() => _statusFilter = value),
          onAdd: () => _openBusDialog(),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _filteredBuses.isEmpty
              ? _StateCard(
                  icon: Icons.directions_bus_outlined,
                  title: _statusFilter == 'ALL'
                      ? 'No buses registered'
                      : 'No $_statusFilter buses',
                  subtitle: 'Add a bus to start building your fleet.',
                  actionLabel: 'Add bus',
                  onAction: () => _openBusDialog(),
                )
              : RefreshIndicator(
                  onRefresh: _fetchAll,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _filteredBuses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final bus = _filteredBuses[index];
                      return _BusRow(
                        bus: bus,
                        route: _routeById(bus.routeId),
                        statusColor: _statusColor(bus.status),
                        onEdit: () => _openBusDialog(existing: bus),
                        onDelete: () => _deleteBus(bus),
                        onRoster: () => _openRosterSheet(bus),
                        onToggleMaintenance: () => _toggleMaintenance(bus),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _toggleMaintenance(TransportBus bus) async {
    if (bus.id == null) return;
    final next = bus.status == 'MAINTENANCE' ? 'ACTIVE' : 'MAINTENANCE';
    try {
      await TransportApiService.updateBus(bus.id!, {
        ...bus.toJson(),
        'status': next,
      });
      await _fetchBuses();
      await _fetchStats();
      _snack('Bus marked ${_pretty(next)}.');
    } catch (e) {
      _snack('Could not update bus status: $e', isError: true);
    }
  }

  Widget _buildRoutesTab() {
    if (_loadingRoutes && _routes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_routes.isEmpty) {
      return _StateCard(
        icon: Icons.route_outlined,
        title: 'No routes configured',
        subtitle: 'Create transport zones, stops and monthly fees.',
        actionLabel: 'Add route',
        onAction: () => _openRouteDialog(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_routes.length} active route records',
                style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _openRouteDialog(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add route'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchAll,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _routes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _RouteRow(
                route: _routes[index],
                currency: _currency,
                onEdit: () => _openRouteDialog(existing: _routes[index]),
                onDelete: () => _deleteRoute(_routes[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignTab() {
    return Column(
      children: [
        _Panel(
          padding: const EdgeInsets.all(10),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search student by name...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _studentResults = []);
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        )
                      : null,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _searchCtrl.text.trim().length < 2
              ? const _StateCard(
                  icon: Icons.person_search_outlined,
                  title: 'Search a student',
                  subtitle:
                      'Type at least two characters to assign or reassign transport.',
                )
              : _studentResults.isEmpty && !_searching
                  ? const _StateCard(
                      icon: Icons.search_off_outlined,
                      title: 'No students found',
                      subtitle: 'Try a different name or roll number.',
                    )
                  : ListView.separated(
                      itemCount: _studentResults.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _StudentSearchRow(
                        student: _studentResults[index],
                        onAssign: () =>
                            _openAssignDialog(_studentResults[index]),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _FleetToolbar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final VoidCallback onAdd;

  const _FleetToolbar({
    required this.selected,
    required this.onChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    ['ALL', 'ACTIVE', 'MAINTENANCE', 'RETIRED'].map((status) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: selected == status,
                      label: Text(_pretty(status)),
                      onSelected: (_) => onChanged(status),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add bus'),
          ),
        ],
      ),
    );
  }
}

class _BusRow extends StatelessWidget {
  final TransportBus bus;
  final TransportRoute? route;
  final Color statusColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRoster;
  final VoidCallback onToggleMaintenance;

  const _BusRow({
    required this.bus,
    required this.route,
    required this.statusColor,
    required this.onEdit,
    required this.onDelete,
    required this.onRoster,
    required this.onToggleMaintenance,
  });

  @override
  Widget build(BuildContext context) {
    final occupancy = bus.capacity <= 0
        ? 0.0
        : (bus.assignedCount / bus.capacity).clamp(0.0, 1.0);
    final occupancyColor = occupancy >= 1
        ? AppColors.error
        : occupancy >= 0.8
            ? AppColors.warning
            : AppColors.success;

    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.directions_bus_outlined, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bus.busNumber,
                        style: GoogleFonts.nunitoSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _MiniChip(label: _pretty(bus.status), color: statusColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${bus.driverName} | ${bus.driverMobile}',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MiniChip(
                      label: _routeName(route),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    _MiniChip(
                      label: '${bus.assignedCount}/${bus.capacity} seats',
                      color: occupancyColor,
                    ),
                    if (bus.insuranceExpiry?.isNotEmpty == true)
                      _MiniChip(
                        label: 'Insurance ${bus.insuranceExpiry}',
                        color: AppColors.info,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: occupancy,
                    minHeight: 7,
                    backgroundColor: occupancyColor.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(occupancyColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (value) {
              if (value == 'roster') onRoster();
              if (value == 'edit') onEdit();
              if (value == 'maintenance') onToggleMaintenance();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'roster', child: Text('View roster')),
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: 'maintenance',
                child: Text(bus.status == 'MAINTENANCE'
                    ? 'Mark active'
                    : 'Mark maintenance'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final TransportRoute route;
  final NumberFormat currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RouteRow({
    required this.route,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.palette.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.route_outlined, color: context.palette.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _routeName(route),
                        style: GoogleFonts.nunitoSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _MiniChip(
                      label: currency.format(route.monthlyFee),
                      color: AppColors.success,
                    ),
                  ],
                ),
                if (route.areasCovered.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    route.areasCovered,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MiniChip(
                      label: '${route.assignedCount} students',
                      color: AppColors.info,
                    ),
                    if (route.firstPickupTime.isNotEmpty)
                      _MiniChip(
                        label: 'Pickup ${route.firstPickupTime}',
                        color: AppColors.warning,
                      ),
                    if (route.stops.isNotEmpty)
                      _MiniChip(
                        label: '${route.stops.length} stops',
                        color: context.palette.brand,
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentSearchRow extends StatelessWidget {
  final StudentModel student;
  final VoidCallback onAssign;

  const _StudentSearchRow({
    required this.student,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: context.palette.brand.withValues(alpha: 0.1),
            child: Text(
              student.fullName.isNotEmpty
                  ? student.fullName[0].toUpperCase()
                  : '?',
              style: GoogleFonts.nunitoSans(
                color: context.palette.brand,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${student.classForAdmission ?? '-'}${student.rollNumber == null ? '' : ' | Roll ${student.rollNumber}'}',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onAssign,
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: const Text('Assign'),
          ),
        ],
      ),
    );
  }
}

class _RosterSheet extends StatefulWidget {
  final TransportBus bus;
  final TransportRoute? Function(String?) routeById;
  final Future<void> Function() onChanged;

  const _RosterSheet({
    required this.bus,
    required this.routeById,
    required this.onChanged,
  });

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
    if (widget.bus.id == null) return;
    setState(() => _loading = true);
    try {
      final roster = await TransportApiService.getBusRoster(widget.bus.id!);
      if (!mounted) return;
      setState(() => _roster = roster);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(StudentTransportAssignment assignment) async {
    if (assignment.id == null) return;
    await TransportApiService.removeAssignment(assignment.id!);
    await widget.onChanged();
    await _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.routeById(widget.bus.routeId);
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Roster: ${widget.bus.busNumber}',
                            style: GoogleFonts.nunitoSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            _routeName(route),
                            style: GoogleFonts.nunitoSans(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _roster.isEmpty
                        ? const _StateCard(
                            icon: Icons.groups_outlined,
                            title: 'No students assigned',
                            subtitle: 'Assigned students will appear here.',
                          )
                        : ListView.separated(
                            controller: controller,
                            padding: const EdgeInsets.all(16),
                            itemCount: _roster.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = _roster[index];
                              return _Panel(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.studentName,
                                            style: GoogleFonts.nunitoSans(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          Text(
                                            '${item.className}${item.rollNumber == null ? '' : ' | Roll ${item.rollNumber}'}',
                                            style: GoogleFonts.nunitoSans(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          if (item.pickupStop?.isNotEmpty ==
                                              true)
                                            Text(
                                              'Stop: ${item.pickupStop}',
                                              style: GoogleFonts.nunitoSans(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove assignment',
                                      onPressed: () => _remove(item),
                                      color: AppColors.error,
                                      icon: const Icon(Icons.delete_outline),
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
      },
    );
  }
}

class _StudentMiniCard extends StatelessWidget {
  final StudentModel student;

  const _StudentMiniCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.canvas,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: context.palette.brand.withValues(alpha: 0.1),
            child: Text(
              student.fullName.isNotEmpty
                  ? student.fullName[0].toUpperCase()
                  : '?',
              style: GoogleFonts.nunitoSans(
                color: context.palette.brand,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${student.classForAdmission ?? '-'}${student.rollNumber == null ? '' : ' | Roll ${student.rollNumber}'}',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormGrid extends StatelessWidget {
  final List<Widget> children;

  const _FormGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 540;
        final width =
            compact ? constraints.maxWidth : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    );
  }
}

class _DialogTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _DialogTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: context.palette.brand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: context.palette.brand),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.nunitoSans(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool loading;

  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _Panel(
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: loading
                  ? const LinearProgressIndicator(minHeight: 4)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunitoSans(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunitoSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const _Panel({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.nunitoSans(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border.all(color: context.palette.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _routeName(TransportRoute? route) {
  if (route == null) return 'No route';
  if (route.displayName?.isNotEmpty == true) return route.displayName!;
  return route.zoneName.isEmpty ? 'Unnamed route' : route.zoneName;
}

String _pretty(String value) {
  if (value == 'ALL') return 'All';
  return value
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0]}${part.substring(1).toLowerCase()}')
      .join(' ');
}
