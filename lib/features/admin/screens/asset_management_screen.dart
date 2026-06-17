import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/asset_api_service.dart';

class AssetManagementScreen extends StatefulWidget {
  const AssetManagementScreen({super.key});

  @override
  State<AssetManagementScreen> createState() => _AssetManagementScreenState();
}

class _AssetManagementScreenState extends State<AssetManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Inventory state ---
  bool _loadingAssets = true;
  List<Map<String, dynamic>> _assets = [];
  String _searchQuery = '';
  String? _categoryFilter;

  // --- Maintenance state ---
  bool _loadingMaintenance = true;
  List<Map<String, dynamic>> _upcomingMaintenance = [];

  // --- Maintenance form ---
  String? _maintAssetId;
  String _maintType = 'REPAIR';
  DateTime? _maintDate;
  final _maintDescController = TextEditingController();
  final _maintPerformedByController = TextEditingController();
  final _maintCostController = TextEditingController();
  bool _submittingMaintenance = false;

  // --- Dashboard state ---
  bool _loadingStats = true;
  Map<String, dynamic> _stats = {};

  static const _categories = [
    null,
    'FURNITURE',
    'ELECTRONICS',
    'LAB_EQUIPMENT',
    'SPORTS',
    'VEHICLE',
    'STATIONERY',
    'OTHER',
  ];
  static const _categoryLabels = [
    'All',
    'Furniture',
    'Electronics',
    'Lab Equipment',
    'Sports',
    'Vehicle',
    'Stationery',
    'Other',
  ];
  static const _conditions = ['NEW', 'GOOD', 'FAIR', 'POOR', 'DAMAGED'];
  static const _maintenanceTypes = [
    'REPAIR',
    'SERVICING',
    'REPLACEMENT',
    'INSPECTION',
  ];

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
    _maintDescController.dispose();
    _maintPerformedByController.dispose();
    _maintCostController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadAssets();
    _loadMaintenance();
    _loadStats();
  }

  Future<void> _loadAssets() async {
    setState(() => _loadingAssets = true);
    try {
      final data = await AssetApiService.getAllAssets();
      if (mounted) setState(() => _assets = data);
    } catch (_) {}
    if (mounted) setState(() => _loadingAssets = false);
  }

  Future<void> _loadMaintenance() async {
    setState(() => _loadingMaintenance = true);
    try {
      final data = await AssetApiService.getUpcomingMaintenance();
      if (mounted) setState(() => _upcomingMaintenance = data);
    } catch (_) {}
    if (mounted) setState(() => _loadingMaintenance = false);
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final data = await AssetApiService.getAssetStats();
      if (mounted) setState(() => _stats = data);
    } catch (_) {}
    if (mounted) setState(() => _loadingStats = false);
  }

  List<Map<String, dynamic>> get _filteredAssets {
    var list = _assets;
    if (_categoryFilter != null) {
      list = list.where((a) => a['category'] == _categoryFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        final code = (a['assetCode'] as String? ?? '').toLowerCase();
        final loc = (a['location'] as String? ?? '').toLowerCase();
        return name.contains(q) || code.contains(q) || loc.contains(q);
      }).toList();
    }
    return list;
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
              Tab(text: 'Inventory'),
              Tab(text: 'Maintenance'),
              Tab(text: 'Dashboard'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInventoryTab(),
              _buildMaintenanceTab(),
              _buildDashboardTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────── TAB 1: Inventory ─────────────────────

  Widget _buildInventoryTab() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.contentPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Asset Inventory',
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              const SizedBox(height: 4),
              Text('Manage school assets and inventory.',
                  style: GoogleFonts.poppins(
                      color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 20),

              // Search bar
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Search assets...',
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

              // Category filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_categories.length, (i) {
                    final cat = _categories[i];
                    final selected = _categoryFilter == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_categoryLabels[i],
                            style: GoogleFonts.poppins(fontSize: 12)),
                        selected: selected,
                        selectedColor: AppColors.gold.withOpacity(0.2),
                        labelStyle: GoogleFonts.poppins(
                          color: selected
                              ? AppColors.navy
                              : AppColors.textSecondary,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        onSelected: (_) =>
                            setState(() => _categoryFilter = cat),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // Asset list
              if (_loadingAssets)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_filteredAssets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('No assets found',
                            style: GoogleFonts.poppins(
                                color: AppColors.textLight, fontSize: 14)),
                      ],
                    ),
                  ),
                )
              else
                _buildAssetGrid(),

              // Bottom padding for FAB
              const SizedBox(height: 80),
            ],
          ),
        ),
        // FAB
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            heroTag: 'add_asset',
            onPressed: () => _showAssetDialog(),
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text('Add Asset',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetGrid() {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);
    final columns = isDesktop ? 3 : (isTablet ? 2 : 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _filteredAssets.map((asset) {
            return SizedBox(
              width: cardWidth,
              child: _buildAssetCard(asset),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAssetCard(Map<String, dynamic> asset) {
    final name = asset['name'] as String? ?? 'Unnamed';
    final code = asset['assetCode'] as String? ?? '';
    final category = asset['category'] as String? ?? 'OTHER';
    final quantity = (asset['quantity'] as num?)?.toInt() ?? 0;
    final condition = asset['condition'] as String? ?? 'GOOD';
    final location = asset['location'] as String? ?? '';
    final id = asset['_id'] as String? ?? asset['id'] as String? ?? '';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        onTap: () => _showAssetDialog(asset: asset),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        size: 18, color: AppColors.textSecondary),
                    onSelected: (v) {
                      if (v == 'edit') {
                        _showAssetDialog(asset: asset);
                      } else if (v == 'delete') {
                        _confirmDelete(id, name);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                          value: 'edit',
                          child:
                              Text('Edit', style: GoogleFonts.poppins())),
                      PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete',
                              style: GoogleFonts.poppins(
                                  color: AppColors.error))),
                    ],
                  ),
                ],
              ),
              if (code.isNotEmpty) ...[
                Text(code,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textLight)),
                const SizedBox(height: 8),
              ] else
                const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip(_categoryLabel(category), AppColors.navy),
                  _chip(condition, _conditionColor(condition)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.numbers, size: 14, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text('Qty: $quantity',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecondary)),
                  if (location.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(location,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────── TAB 2: Maintenance ─────────────────────

  Widget _buildMaintenanceTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Maintenance',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text('Schedule and track asset maintenance.',
              style: GoogleFonts.poppins(
                  color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),

          // Upcoming Maintenance section
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Upcoming Maintenance',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        color: AppColors.textSecondary,
                        onPressed: _loadMaintenance,
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  if (_loadingMaintenance)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_upcomingMaintenance.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text('No upcoming maintenance scheduled',
                            style: GoogleFonts.poppins(
                                color: AppColors.textLight, fontSize: 14)),
                      ),
                    )
                  else
                    ...List.generate(_upcomingMaintenance.length, (i) {
                      return _buildMaintenanceItem(
                        _upcomingMaintenance[i],
                        i < _upcomingMaintenance.length - 1,
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Schedule Maintenance form
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Schedule Maintenance',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy)),
                  const SizedBox(height: 20),

                  // Asset selector
                  Text('Asset',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _maintAssetId,
                    decoration: _inputDecoration('Select asset'),
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppColors.textPrimary),
                    isExpanded: true,
                    items: _assets.map((a) {
                      final id =
                          a['_id'] as String? ?? a['id'] as String? ?? '';
                      final name = a['name'] as String? ?? 'Unnamed';
                      return DropdownMenuItem(value: id, child: Text(name));
                    }).toList(),
                    onChanged: (v) => setState(() => _maintAssetId = v),
                  ),
                  const SizedBox(height: 16),

                  // Type
                  Text('Type',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _maintType,
                    decoration: _inputDecoration('Select type'),
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppColors.textPrimary),
                    items: _maintenanceTypes
                        .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _maintType = v);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Scheduled Date
                  Text('Scheduled Date',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _maintDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) setState(() => _maintDate = picked);
                    },
                    child: InputDecorator(
                      decoration: _inputDecoration('Select date'),
                      child: Text(
                        _maintDate != null
                            ? DateFormat('dd MMM yyyy').format(_maintDate!)
                            : 'Select date',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _maintDate != null
                              ? AppColors.textPrimary
                              : AppColors.textLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text('Description',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _maintDescController,
                    maxLines: 3,
                    decoration: _inputDecoration('Describe the maintenance'),
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Performed By
                  Text('Performed By',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _maintPerformedByController,
                    decoration: _inputDecoration('Name or vendor'),
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Cost
                  Text('Cost (Rs)',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _maintCostController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('0'),
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _submittingMaintenance ? null : _submitMaintenance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD),
                        ),
                      ),
                      child: Text(
                        _submittingMaintenance
                            ? 'Scheduling...'
                            : 'Schedule Maintenance',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceItem(Map<String, dynamic> maint, bool showDivider) {
    final assetName = maint['assetName'] as String? ?? 'Unknown Asset';
    final type = maint['type'] as String? ?? 'REPAIR';
    final description = maint['description'] as String? ?? '';
    final scheduledDate = maint['scheduledDate'] as String?;
    final id = maint['_id'] as String? ?? maint['id'] as String? ?? '';

    String dateStr = '';
    if (scheduledDate != null) {
      try {
        final dt = DateTime.parse(scheduledDate);
        dateStr = DateFormat('dd MMM yyyy').format(dt.toLocal());
      } catch (_) {
        dateStr = scheduledDate;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(assetName,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _chip(type, _maintenanceTypeColor(type)),
                        if (dateStr.isNotEmpty)
                          Text(dateStr,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(description,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _completeMaintenance(id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  ),
                ),
                child: Text('Complete',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }

  // ───────────────────── TAB 3: Dashboard ─────────────────────

  Widget _buildDashboardTab() {
    if (_loadingStats && _loadingAssets) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalAssets = ((_stats['totalAssets'] as num?)?.toInt()) ?? _assets.length;
    final totalValue = ((_stats['totalValue'] as num?)?.toDouble()) ?? 0.0;
    final needRepair = ((_stats['needRepair'] as num?)?.toInt()) ??
        _assets.where((a) {
          final c = a['condition'] as String? ?? '';
          return c == 'POOR' || c == 'DAMAGED';
        }).length;

    // Category breakdown
    final categoryBreakdown =
        _stats['categoryBreakdown'] as Map<String, dynamic>? ??
            _buildLocalCategoryBreakdown();

    // Condition breakdown
    final conditionBreakdown =
        _stats['conditionBreakdown'] as Map<String, dynamic>? ??
            _buildLocalConditionBreakdown();

    final isWide = Responsive.isDesktop(context) || Responsive.isTablet(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Asset Dashboard',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text('Overview of asset inventory and conditions.',
              style: GoogleFonts.poppins(
                  color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),

          // Stat cards
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = Responsive.gridColumns(context).clamp(1, 3);
              final cardWidth =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _statCard(
                      'Total Assets',
                      '$totalAssets',
                      Icons.inventory_2_rounded,
                      AppColors.navy,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _statCard(
                      'Total Value',
                      _formatRupee(totalValue),
                      Icons.monetization_on_rounded,
                      AppColors.gold,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _statCard(
                      'Need Repair',
                      '$needRepair',
                      Icons.build_circle_rounded,
                      AppColors.error,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _buildCategoryBreakdownCard(categoryBreakdown)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildConditionBreakdownCard(conditionBreakdown)),
              ],
            )
          else ...[
            _buildCategoryBreakdownCard(categoryBreakdown),
            const SizedBox(height: 16),
            _buildConditionBreakdownCard(conditionBreakdown),
          ],
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

  Widget _buildCategoryBreakdownCard(Map<String, dynamic> breakdown) {
    final total = breakdown.values.fold<int>(
        0, (sum, v) => sum + ((v as num?)?.toInt() ?? 0));

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
            Text('Category Breakdown',
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
              ...breakdown.entries.map((e) {
                final count = (e.value as num?)?.toInt() ?? 0;
                final fraction = total > 0 ? count / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_categoryLabel(e.key),
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.textPrimary)),
                          Text('$count',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.navy)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 8,
                          backgroundColor: AppColors.border.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation(AppColors.navy),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionBreakdownCard(Map<String, dynamic> breakdown) {
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
            Text('Condition Breakdown',
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
                  final color = _conditionColor(e.key);
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
                        Text(e.key,
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

  Future<void> _showAssetDialog({Map<String, dynamic>? asset}) async {
    final isEdit = asset != null;
    final nameC = TextEditingController(text: asset?['name'] as String? ?? '');
    final descC =
        TextEditingController(text: asset?['description'] as String? ?? '');
    final locationC =
        TextEditingController(text: asset?['location'] as String? ?? '');
    final quantityC = TextEditingController(
        text: '${(asset?['quantity'] as num?)?.toInt() ?? 1}');
    final priceC = TextEditingController(
        text: '${(asset?['purchasePrice'] as num?)?.toDouble() ?? ''}');
    final vendorC =
        TextEditingController(text: asset?['vendor'] as String? ?? '');
    final assignedC =
        TextEditingController(text: asset?['assignedTo'] as String? ?? '');
    final remarksC =
        TextEditingController(text: asset?['remarks'] as String? ?? '');

    String category = asset?['category'] as String? ?? 'FURNITURE';
    String condition = asset?['condition'] as String? ?? 'NEW';
    DateTime? purchaseDate;
    DateTime? warrantyExpiry;

    if (asset?['purchaseDate'] != null) {
      try {
        purchaseDate = DateTime.parse(asset!['purchaseDate'] as String);
      } catch (_) {}
    }
    if (asset?['warrantyExpiry'] != null) {
      try {
        warrantyExpiry = DateTime.parse(asset!['warrantyExpiry'] as String);
      } catch (_) {}
    }

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
              title: Text(isEdit ? 'Edit Asset' : 'Add Asset',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dialogField('Name *', nameC, 'Asset name'),
                      const SizedBox(height: 12),
                      _dialogLabel('Category *'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: _inputDecoration('Select category'),
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: AppColors.textPrimary),
                        items: _categories
                            .where((c) => c != null)
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(_categoryLabel(c!))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => category = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _dialogField(
                          'Description', descC, 'Asset description',
                          maxLines: 2),
                      const SizedBox(height: 12),
                      _dialogField('Location', locationC, 'Building / Room'),
                      const SizedBox(height: 12),
                      _dialogField(
                          'Quantity *', quantityC, '1',
                          keyboardType: TextInputType.number),
                      const SizedBox(height: 12),
                      _dialogField(
                          'Purchase Price', priceC, '0',
                          keyboardType: TextInputType.number),
                      const SizedBox(height: 12),
                      _dialogLabel('Purchase Date'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: purchaseDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => purchaseDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: _inputDecoration('Select date'),
                          child: Text(
                            purchaseDate != null
                                ? DateFormat('dd MMM yyyy')
                                    .format(purchaseDate!)
                                : 'Select date',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: purchaseDate != null
                                  ? AppColors.textPrimary
                                  : AppColors.textLight,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _dialogField('Vendor', vendorC, 'Vendor name'),
                      const SizedBox(height: 12),
                      _dialogLabel('Condition *'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: condition,
                        decoration: _inputDecoration('Select condition'),
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: AppColors.textPrimary),
                        items: _conditions
                            .map((c) => DropdownMenuItem(
                                value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => condition = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _dialogLabel('Warranty Expiry'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: warrantyExpiry ??
                                DateTime.now()
                                    .add(const Duration(days: 365)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 10)),
                          );
                          if (picked != null) {
                            setDialogState(() => warrantyExpiry = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: _inputDecoration('Select date'),
                          child: Text(
                            warrantyExpiry != null
                                ? DateFormat('dd MMM yyyy')
                                    .format(warrantyExpiry!)
                                : 'Select date',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: warrantyExpiry != null
                                  ? AppColors.textPrimary
                                  : AppColors.textLight,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _dialogField(
                          'Assigned To', assignedC, 'Person or department'),
                      const SizedBox(height: 12),
                      _dialogField('Remarks', remarksC, 'Additional notes',
                          maxLines: 2),
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
                                  content: Text('Name is required')),
                            );
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            final data = <String, dynamic>{
                              'name': nameC.text.trim(),
                              'category': category,
                              'condition': condition,
                              'quantity': int.tryParse(quantityC.text) ?? 1,
                            };
                            if (descC.text.trim().isNotEmpty) {
                              data['description'] = descC.text.trim();
                            }
                            if (locationC.text.trim().isNotEmpty) {
                              data['location'] = locationC.text.trim();
                            }
                            if (priceC.text.trim().isNotEmpty) {
                              data['purchasePrice'] =
                                  double.tryParse(priceC.text) ?? 0;
                            }
                            if (purchaseDate != null) {
                              data['purchaseDate'] =
                                  purchaseDate!.toIso8601String();
                            }
                            if (vendorC.text.trim().isNotEmpty) {
                              data['vendor'] = vendorC.text.trim();
                            }
                            if (warrantyExpiry != null) {
                              data['warrantyExpiry'] =
                                  warrantyExpiry!.toIso8601String();
                            }
                            if (assignedC.text.trim().isNotEmpty) {
                              data['assignedTo'] = assignedC.text.trim();
                            }
                            if (remarksC.text.trim().isNotEmpty) {
                              data['remarks'] = remarksC.text.trim();
                            }

                            if (isEdit) {
                              final id = asset['_id'] as String? ??
                                  asset['id'] as String? ??
                                  '';
                              await AssetApiService.updateAsset(id, data);
                            } else {
                              await AssetApiService.addAsset(data);
                            }
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEdit
                                      ? 'Asset updated!'
                                      : 'Asset added!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              _loadAssets();
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
                        : (isEdit ? 'Update' : 'Add'),
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
        title: Text('Delete Asset',
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
        await AssetApiService.deleteAsset(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Asset deleted'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadAssets();
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

  Future<void> _submitMaintenance() async {
    if (_maintAssetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an asset')),
      );
      return;
    }
    if (_maintDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a scheduled date')),
      );
      return;
    }

    setState(() => _submittingMaintenance = true);
    try {
      final data = <String, dynamic>{
        'assetId': _maintAssetId,
        'type': _maintType,
        'scheduledDate': _maintDate!.toIso8601String(),
      };
      if (_maintDescController.text.trim().isNotEmpty) {
        data['description'] = _maintDescController.text.trim();
      }
      if (_maintPerformedByController.text.trim().isNotEmpty) {
        data['performedBy'] = _maintPerformedByController.text.trim();
      }
      if (_maintCostController.text.trim().isNotEmpty) {
        data['cost'] = double.tryParse(_maintCostController.text) ?? 0;
      }

      await AssetApiService.addMaintenance(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maintenance scheduled!'),
            backgroundColor: AppColors.success,
          ),
        );
        _maintDescController.clear();
        _maintPerformedByController.clear();
        _maintCostController.clear();
        setState(() {
          _maintAssetId = null;
          _maintDate = null;
          _maintType = 'REPAIR';
        });
        _loadMaintenance();
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
    if (mounted) setState(() => _submittingMaintenance = false);
  }

  Future<void> _completeMaintenance(String id) async {
    try {
      await AssetApiService.completeMaintenance(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maintenance marked as completed!'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadMaintenance();
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
  }

  // ───────────────────── Helpers ─────────────────────

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

  Color _conditionColor(String condition) {
    return switch (condition) {
      'NEW' => AppColors.success,
      'GOOD' => AppColors.info,
      'FAIR' => AppColors.warning,
      'POOR' => AppColors.error,
      'DAMAGED' => AppColors.error,
      _ => AppColors.textSecondary,
    };
  }

  Color _maintenanceTypeColor(String type) {
    return switch (type) {
      'REPAIR' => AppColors.error,
      'SERVICING' => AppColors.info,
      'REPLACEMENT' => AppColors.warning,
      'INSPECTION' => AppColors.success,
      _ => AppColors.textSecondary,
    };
  }

  String _categoryLabel(String category) {
    return switch (category) {
      'FURNITURE' => 'Furniture',
      'ELECTRONICS' => 'Electronics',
      'LAB_EQUIPMENT' => 'Lab Equipment',
      'SPORTS' => 'Sports',
      'VEHICLE' => 'Vehicle',
      'STATIONERY' => 'Stationery',
      'OTHER' => 'Other',
      _ => category,
    };
  }

  String _formatRupee(double amount) {
    if (amount >= 10000000) return 'Rs ${(amount / 10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000) return 'Rs ${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return 'Rs ${(amount / 1000).toStringAsFixed(1)}K';
    return 'Rs ${amount.toStringAsFixed(0)}';
  }

  Map<String, dynamic> _buildLocalCategoryBreakdown() {
    final map = <String, int>{};
    for (final a in _assets) {
      final cat = a['category'] as String? ?? 'OTHER';
      map[cat] = (map[cat] ?? 0) + 1;
    }
    return map.map((k, v) => MapEntry(k, v));
  }

  Map<String, dynamic> _buildLocalConditionBreakdown() {
    final map = <String, int>{};
    for (final a in _assets) {
      final cond = a['condition'] as String? ?? 'GOOD';
      map[cond] = (map[cond] ?? 0) + 1;
    }
    return map.map((k, v) => MapEntry(k, v));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight),
      filled: true,
      fillColor: AppColors.cream,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
