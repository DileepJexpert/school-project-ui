import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/visitor_api_service.dart';

class VisitorManagementScreen extends StatefulWidget {
  const VisitorManagementScreen({super.key});

  @override
  State<VisitorManagementScreen> createState() =>
      _VisitorManagementScreenState();
}

class _VisitorManagementScreenState extends State<VisitorManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Today tab state ---
  bool _loadingToday = true;
  List<Map<String, dynamic>> _todayVisitors = [];
  String _searchQuery = '';

  // --- Stats state ---
  bool _loadingStats = true;
  Map<String, dynamic> _stats = {};

  // --- History tab state ---
  bool _loadingHistory = false;
  List<Map<String, dynamic>> _historyVisitors = [];
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadTodayVisitors();
    _loadStats();
  }

  Future<void> _loadTodayVisitors() async {
    setState(() => _loadingToday = true);
    try {
      final data = await VisitorApiService.getTodayVisitors();
      if (mounted) {
        setState(() => _todayVisitors = List<Map<String, dynamic>>.from(
            data.map((e) => Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingToday = false);
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final data = await VisitorApiService.getStats();
      if (mounted) setState(() => _stats = data);
    } catch (_) {}
    if (mounted) setState(() => _loadingStats = false);
  }

  Future<void> _loadHistory() async {
    if (_dateFrom == null || _dateTo == null) return;
    setState(() => _loadingHistory = true);
    try {
      final from = DateFormat('yyyy-MM-dd').format(_dateFrom!);
      final to = DateFormat('yyyy-MM-dd').format(_dateTo!);
      final data = await VisitorApiService.getByDateRange(from, to);
      if (mounted) {
        setState(() => _historyVisitors = List<Map<String, dynamic>>.from(
            data.map((e) => Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingHistory = false);
  }

  Future<void> _searchVisitors(String query) async {
    if (query.isEmpty) {
      _loadTodayVisitors();
      return;
    }
    setState(() => _loadingToday = true);
    try {
      final data = await VisitorApiService.search(query);
      if (mounted) {
        setState(() => _todayVisitors = List<Map<String, dynamic>>.from(
            data.map((e) => Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingToday = false);
  }

  List<Map<String, dynamic>> get _filteredToday {
    if (_searchQuery.isEmpty) return _todayVisitors;
    final q = _searchQuery.toLowerCase();
    return _todayVisitors.where((v) {
      final name = (v['visitorName'] as String? ?? '').toLowerCase();
      final phone = (v['phone'] as String? ?? '').toLowerCase();
      final purpose = (v['purpose'] as String? ?? '').toLowerCase();
      final personToMeet = (v['personToMeet'] as String? ?? '').toLowerCase();
      return name.contains(q) ||
          phone.contains(q) ||
          purpose.contains(q) ||
          personToMeet.contains(q);
    }).toList();
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          color: AppColors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.navy,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.gold,
            indicatorWeight: 3,
            labelStyle:
                GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
            tabs: const [
              Tab(text: "Today's Visitors"),
              Tab(text: 'Visitor Log'),
              Tab(text: 'Dashboard'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTodayTab(),
              _buildHistoryTab(),
              _buildDashboardTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────── TAB 1: Today's Visitors ─────────────────────

  Widget _buildTodayTab() {
    final todayCount =
        ((_stats['todayCount'] as num?)?.toInt()) ?? _todayVisitors.length;
    final currentlyIn = ((_stats['currentlyIn'] as num?)?.toInt()) ??
        _todayVisitors
            .where((v) => v['status'] == 'CHECKED_IN')
            .length;
    final weekTotal = ((_stats['weekTotal'] as num?)?.toInt()) ?? 0;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.contentPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Today's Visitors",
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              const SizedBox(height: 4),
              Text('Manage visitor check-in and check-out.',
                  style: GoogleFonts.poppins(
                      color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 20),

              // Stat cards row
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      Responsive.gridColumns(context).clamp(1, 3);
                  final cardWidth =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _statCard(
                          "Today's Count",
                          '$todayCount',
                          Icons.people_alt_rounded,
                          AppColors.navy,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _statCard(
                          'Currently In Building',
                          '$currentlyIn',
                          Icons.login_rounded,
                          AppColors.success,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _statCard(
                          'Week Total',
                          '$weekTotal',
                          Icons.date_range_rounded,
                          AppColors.gold,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Search bar
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Search visitors...',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 14, color: AppColors.textLight),
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    borderSide:
                        const BorderSide(color: AppColors.navy, width: 1.5),
                  ),
                ),
                style: GoogleFonts.poppins(fontSize: 14),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 16),

              // Visitor list
              if (_loadingToday)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_filteredToday.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.person_off_outlined,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('No visitors found',
                            style: GoogleFonts.poppins(
                                color: AppColors.textLight, fontSize: 14)),
                      ],
                    ),
                  ),
                )
              else
                _buildVisitorList(_filteredToday, showCheckout: true),

              // Bottom padding for FAB
              const SizedBox(height: 80),
            ],
          ),
        ),
        // Register Visitor FAB
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            heroTag: 'register_visitor',
            onPressed: () => _showVisitorDialog(),
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.person_add),
            label: Text('Register Visitor',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ───────────────────── TAB 2: Visitor Log (History) ─────────────────────

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Visitor Log',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text('View visitor history by date range.',
              style: GoogleFonts.poppins(
                  color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),

          // Date range filter
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dialogLabel('From'),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dateFrom ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _dateFrom = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: _inputDecoration('Select date'),
                        child: Text(
                          _dateFrom != null
                              ? DateFormat('dd MMM yyyy').format(_dateFrom!)
                              : 'Select date',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _dateFrom != null
                                ? AppColors.textPrimary
                                : AppColors.textLight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dialogLabel('To'),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dateTo ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _dateTo = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: _inputDecoration('Select date'),
                        child: Text(
                          _dateTo != null
                              ? DateFormat('dd MMM yyyy').format(_dateTo!)
                              : 'Select date',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _dateTo != null
                                ? AppColors.textPrimary
                                : AppColors.textLight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed:
                    (_dateFrom != null && _dateTo != null) ? _loadHistory : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  ),
                ),
                child: Text('Filter',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // History list
          if (_loadingHistory)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_historyVisitors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history_rounded,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      _dateFrom == null
                          ? 'Select a date range to view visitor log'
                          : 'No visitors found in this range',
                      style: GoogleFonts.poppins(
                          color: AppColors.textLight, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildVisitorList(_historyVisitors, showCheckout: false),
        ],
      ),
    );
  }

  // ───────────────────── TAB 3: Dashboard ─────────────────────

  Widget _buildDashboardTab() {
    if (_loadingStats && _loadingToday) {
      return const Center(child: CircularProgressIndicator());
    }

    final todayCount =
        ((_stats['todayCount'] as num?)?.toInt()) ?? _todayVisitors.length;
    final currentlyIn = ((_stats['currentlyIn'] as num?)?.toInt()) ??
        _todayVisitors
            .where((v) => v['status'] == 'CHECKED_IN')
            .length;
    final weekTotal = ((_stats['weekTotal'] as num?)?.toInt()) ?? 0;

    final purposeBreakdown =
        _stats['purposeBreakdown'] as Map<String, dynamic>? ??
            _buildLocalPurposeBreakdown();

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Visitor Dashboard',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text('Overview of visitor activity.',
              style: GoogleFonts.poppins(
                  color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),

          // Stat cards
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  Responsive.gridColumns(context).clamp(1, 3);
              final cardWidth =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _statCard(
                      "Today's Count",
                      '$todayCount',
                      Icons.people_alt_rounded,
                      AppColors.navy,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _statCard(
                      'Currently In Building',
                      '$currentlyIn',
                      Icons.login_rounded,
                      AppColors.success,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _statCard(
                      'Week Total',
                      '$weekTotal',
                      Icons.date_range_rounded,
                      AppColors.gold,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Purpose breakdown
          _buildPurposeBreakdownCard(purposeBreakdown),
        ],
      ),
    );
  }

  // ───────────────────── Shared Widgets ─────────────────────

  Widget _buildVisitorList(List<Map<String, dynamic>> visitors,
      {required bool showCheckout}) {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);
    final columns = isDesktop ? 2 : (isTablet ? 2 : 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: visitors.map((visitor) {
            return SizedBox(
              width: cardWidth,
              child: _buildVisitorCard(visitor, showCheckout: showCheckout),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildVisitorCard(Map<String, dynamic> visitor,
      {required bool showCheckout}) {
    final name = visitor['visitorName'] as String? ?? 'Unknown';
    final phone = visitor['phone'] as String? ?? '';
    final purpose = visitor['purpose'] as String? ?? 'OTHER';
    final personToMeet = visitor['personToMeet'] as String? ?? '';
    final department = visitor['department'] as String? ?? '';
    final status = visitor['status'] as String? ?? 'EXPECTED';
    final gatePass = visitor['gatePassNumber'] as String? ?? '';
    final checkInTime = visitor['checkInTime'] as String?;
    final id = visitor['_id'] as String? ?? visitor['id'] as String? ?? '';

    String checkInStr = '';
    if (checkInTime != null) {
      try {
        final dt = DateTime.parse(checkInTime);
        checkInStr = DateFormat('hh:mm a').format(dt.toLocal());
      } catch (_) {
        checkInStr = checkInTime;
      }
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: name + gate pass badge + menu
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (gatePass.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.goldPale,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    ),
                    child: Text(gatePass,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold)),
                  ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 18, color: AppColors.textSecondary),
                  onSelected: (v) {
                    if (v == 'edit') {
                      _showVisitorDialog(visitor: visitor);
                    } else if (v == 'delete') {
                      _confirmDelete(id, name);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit', style: GoogleFonts.poppins())),
                    PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style:
                                GoogleFonts.poppins(color: AppColors.error))),
                  ],
                ),
              ],
            ),

            // Phone
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone_outlined,
                      size: 14, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(phone,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
            const SizedBox(height: 8),

            // Purpose chip + Status badge
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(_purposeLabel(purpose), _purposeColor(purpose)),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 10),

            // Person to meet + department
            if (personToMeet.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 14, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      department.isNotEmpty
                          ? '$personToMeet ($department)'
                          : personToMeet,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

            // Check-in time
            if (checkInStr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 14, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text('Check-in: $checkInStr',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],

            // Check Out button
            if (showCheckout && status == 'CHECKED_IN') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _checkoutVisitor(id, name),
                  icon: const Icon(Icons.logout, size: 16),
                  label: Text('Check Out',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    bool showPulseDot = false;

    switch (status) {
      case 'CHECKED_IN':
        color = AppColors.success;
        label = 'Checked In';
        showPulseDot = true;
        break;
      case 'CHECKED_OUT':
        color = AppColors.textSecondary;
        label = 'Checked Out';
        break;
      case 'EXPECTED':
        color = AppColors.info;
        label = 'Expected';
        break;
      default:
        color = AppColors.textSecondary;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPulseDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  Text(title,
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurposeBreakdownCard(Map<String, dynamic> breakdown) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Purpose Breakdown',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
            const SizedBox(height: 16),
            if (breakdown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('No data',
                      style: GoogleFonts.poppins(
                          color: AppColors.textLight, fontSize: 14)),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: breakdown.entries.map((e) {
                  final count = (e.value as num?)?.toInt() ?? 0;
                  final color = _purposeColor(e.key);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text('$count',
                            style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: color)),
                        Text(_purposeLabel(e.key),
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color)),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────────── Dialogs / Actions ─────────────────────

  Future<void> _showVisitorDialog({Map<String, dynamic>? visitor}) async {
    final isEdit = visitor != null;
    final nameC = TextEditingController(
        text: visitor?['visitorName'] as String? ?? '');
    final phoneC =
        TextEditingController(text: visitor?['phone'] as String? ?? '');
    final emailC =
        TextEditingController(text: visitor?['email'] as String? ?? '');
    final purposeDetailsC = TextEditingController(
        text: visitor?['purposeDetails'] as String? ?? '');
    final personToMeetC = TextEditingController(
        text: visitor?['personToMeet'] as String? ?? '');
    final departmentC =
        TextEditingController(text: visitor?['department'] as String? ?? '');
    final numVisitorsC = TextEditingController(
        text: '${(visitor?['numberOfVisitors'] as num?)?.toInt() ?? 1}');
    final idProofNumberC = TextEditingController(
        text: visitor?['idProofNumber'] as String? ?? '');
    final vehicleNumberC = TextEditingController(
        text: visitor?['vehicleNumber'] as String? ?? '');
    final remarksC =
        TextEditingController(text: visitor?['remarks'] as String? ?? '');

    String purpose = visitor?['purpose'] as String? ?? 'PARENT_MEETING';
    String idProofType = visitor?['idProofType'] as String? ?? 'AADHAAR';
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              ),
              title: Text(
                  isEdit ? 'Edit Visitor' : 'Register Visitor',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dialogField('Visitor Name *', nameC, 'Full name'),
                      const SizedBox(height: 12),
                      _dialogField('Phone *', phoneC, 'Phone number',
                          keyboardType: TextInputType.phone),
                      const SizedBox(height: 12),
                      _dialogField('Email', emailC, 'Email address (optional)',
                          keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 12),
                      _dialogLabel('Purpose *'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: purpose,
                        decoration: _inputDecoration('Select purpose'),
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: AppColors.textPrimary),
                        items: _purposes
                            .map((p) => DropdownMenuItem(
                                value: p, child: Text(_purposeLabel(p))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => purpose = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _dialogField(
                          'Purpose Details', purposeDetailsC, 'Details'),
                      const SizedBox(height: 12),
                      _dialogField(
                          'Person to Meet *', personToMeetC, 'Name of person'),
                      const SizedBox(height: 12),
                      _dialogField(
                          'Department', departmentC, 'Department (optional)'),
                      const SizedBox(height: 12),
                      _dialogField('Number of Visitors', numVisitorsC, '1',
                          keyboardType: TextInputType.number),
                      const SizedBox(height: 12),
                      _dialogLabel('ID Proof Type'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: idProofType,
                        decoration: _inputDecoration('Select ID type'),
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: AppColors.textPrimary),
                        items: _idProofTypes
                            .map((t) => DropdownMenuItem(
                                value: t, child: Text(_idProofLabel(t))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => idProofType = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _dialogField(
                          'ID Proof Number', idProofNumberC, 'ID number'),
                      const SizedBox(height: 12),
                      _dialogField('Vehicle Number', vehicleNumberC,
                          'Vehicle number (optional)'),
                      const SizedBox(height: 12),
                      _dialogField('Remarks', remarksC, 'Additional notes',
                          maxLines: 3),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (nameC.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Visitor name is required')),
                            );
                            return;
                          }
                          if (phoneC.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Phone number is required')),
                            );
                            return;
                          }
                          if (personToMeetC.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Person to meet is required')),
                            );
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            final data = <String, dynamic>{
                              'visitorName': nameC.text.trim(),
                              'phone': phoneC.text.trim(),
                              'purpose': purpose,
                              'personToMeet': personToMeetC.text.trim(),
                              'numberOfVisitors':
                                  int.tryParse(numVisitorsC.text) ?? 1,
                              'idProofType': idProofType,
                            };
                            if (emailC.text.trim().isNotEmpty) {
                              data['email'] = emailC.text.trim();
                            }
                            if (purposeDetailsC.text.trim().isNotEmpty) {
                              data['purposeDetails'] =
                                  purposeDetailsC.text.trim();
                            }
                            if (departmentC.text.trim().isNotEmpty) {
                              data['department'] = departmentC.text.trim();
                            }
                            if (idProofNumberC.text.trim().isNotEmpty) {
                              data['idProofNumber'] =
                                  idProofNumberC.text.trim();
                            }
                            if (vehicleNumberC.text.trim().isNotEmpty) {
                              data['vehicleNumber'] =
                                  vehicleNumberC.text.trim();
                            }
                            if (remarksC.text.trim().isNotEmpty) {
                              data['remarks'] = remarksC.text.trim();
                            }

                            if (isEdit) {
                              final id = visitor['_id'] as String? ??
                                  visitor['id'] as String? ??
                                  '';
                              await VisitorApiService.update(id, data);
                            } else {
                              await VisitorApiService.create(data);
                            }
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEdit
                                      ? 'Visitor updated!'
                                      : 'Visitor registered!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              _loadTodayVisitors();
                              _loadStats();
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                          setDialogState(() => saving = false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    ),
                  ),
                  child: Text(
                    saving
                        ? 'Saving...'
                        : (isEdit ? 'Update' : 'Register'),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        ),
        title: Text('Delete Visitor',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete "$name"?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
            ),
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await VisitorApiService.delete(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Visitor deleted'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadTodayVisitors();
          _loadStats();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _checkoutVisitor(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        ),
        title: Text('Check Out Visitor',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Check out "$name"?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
            ),
            child: Text('Check Out', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await VisitorApiService.checkout(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Visitor checked out!'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadTodayVisitors();
          _loadStats();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to check out: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  // ───────────────────── Helpers ─────────────────────

  static const _purposes = [
    'PARENT_MEETING',
    'VENDOR',
    'OFFICIAL',
    'OTHER',
  ];

  static const _idProofTypes = [
    'AADHAAR',
    'PAN',
    'DRIVING_LICENSE',
    'PASSPORT',
    'OTHER',
  ];

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Color _purposeColor(String purpose) {
    return switch (purpose) {
      'PARENT_MEETING' => AppColors.info,
      'VENDOR' => AppColors.warning,
      'OFFICIAL' => const Color(0xFF7C3AED),
      'OTHER' => AppColors.textSecondary,
      _ => AppColors.textSecondary,
    };
  }

  String _purposeLabel(String purpose) {
    return switch (purpose) {
      'PARENT_MEETING' => 'Parent Meeting',
      'VENDOR' => 'Vendor',
      'OFFICIAL' => 'Official',
      'OTHER' => 'Other',
      _ => purpose,
    };
  }

  String _idProofLabel(String type) {
    return switch (type) {
      'AADHAAR' => 'Aadhaar',
      'PAN' => 'PAN Card',
      'DRIVING_LICENSE' => 'Driving License',
      'PASSPORT' => 'Passport',
      'OTHER' => 'Other',
      _ => type,
    };
  }

  Map<String, dynamic> _buildLocalPurposeBreakdown() {
    final map = <String, int>{};
    for (final v in _todayVisitors) {
      final purpose = v['purpose'] as String? ?? 'OTHER';
      map[purpose] = (map[purpose] ?? 0) + 1;
    }
    return map.map((k, v) => MapEntry(k, v));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight),
      filled: true,
      fillColor: AppColors.cream,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
      ),
    );
  }

  Widget _dialogLabel(String label) {
    return Text(label,
        style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary));
  }

  Widget _dialogField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dialogLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: _inputDecoration(hint),
          style: GoogleFonts.poppins(fontSize: 14),
        ),
      ],
    );
  }
}
