import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/promotion_api_service.dart';

class PromotionScreen extends StatefulWidget {
  const PromotionScreen({super.key});

  @override
  State<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends State<PromotionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Promotions tab state ---
  List<dynamic> _promotions = [];
  bool _loading = true;
  String? _error;
  final _yearCtrl = TextEditingController(text: '2024-25');
  String? _filterClass;

  // --- Dashboard tab state ---
  Map<String, dynamic> _stats = {};
  bool _statsLoading = false;
  String? _statsError;
  final _statsYearCtrl = TextEditingController(text: '2024-25');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPromotions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _yearCtrl.dispose();
    _statsYearCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────── Data loading ─────────────────────────

  Future<void> _loadPromotions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<dynamic> list;
      if (_filterClass != null && _filterClass!.isNotEmpty) {
        list = await PromotionApiService.getByClass(_filterClass!);
      } else if (_yearCtrl.text.trim().isNotEmpty) {
        list = await PromotionApiService.getByYear(_yearCtrl.text.trim());
      } else {
        list = await PromotionApiService.getAllPromotions();
      }
      if (!mounted) return;
      setState(() => _promotions = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStats() async {
    setState(() {
      _statsLoading = true;
      _statsError = null;
    });
    try {
      final data =
          await PromotionApiService.getStats(_statsYearCtrl.text.trim());
      if (!mounted) return;
      setState(() => _stats = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _statsError = e.toString());
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildTabBar(),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPromotionsTab(),
                _buildDashboardTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Header ─────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student Promotions',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              Text(
                'Promote, retain, or issue TCs for students',
                style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────── Tab bar ─────────────────────────

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.creamDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (i) {
          if (i == 1 && _stats.isEmpty && !_statsLoading) _loadStats();
        },
        indicator: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        ),
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Promotions'),
          Tab(text: 'Dashboard'),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TAB 1: Promotions
  // ═══════════════════════════════════════════════════════════

  Widget _buildPromotionsTab() {
    return Column(
      children: [
        _buildFiltersRow(),
        const SizedBox(height: 12),
        _buildActionsRow(),
        const SizedBox(height: 12),
        Expanded(child: _buildPromotionsList()),
      ],
    );
  }

  Widget _buildFiltersRow() {
    return Row(
      children: [
        // Academic year
        SizedBox(
          width: 140,
          child: TextField(
            controller: _yearCtrl,
            decoration: InputDecoration(
              labelText: 'Academic Year',
              labelStyle: GoogleFonts.nunitoSans(fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: GoogleFonts.nunitoSans(fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        // Class filter
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            value: _filterClass,
            hint: Text('All Classes',
                style: GoogleFonts.nunitoSans(
                    color: AppColors.textLight, fontSize: 13)),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text('All Classes',
                    style: GoogleFonts.nunitoSans(fontSize: 13)),
              ),
              ...SchoolConstants.baseClasses.map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(c, style: GoogleFonts.nunitoSans(fontSize: 13)),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _filterClass = v),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _loadPromotions,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Load'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navy,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsRow() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: () => _showBulkPromoteDialog(context),
          icon: const Icon(Icons.groups_rounded, size: 18),
          label: const Text('Bulk Promote Class'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _showIndividualPromoteDialog(context),
          icon: const Icon(Icons.person_add_rounded, size: 16),
          label: const Text('Promote Individual'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.navy,
            side: const BorderSide(color: AppColors.navy),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _showIssueTCDialog(context),
          icon: const Icon(Icons.exit_to_app_rounded, size: 16),
          label: const Text('Issue TC'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPromotionsList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.navy));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_error!,
                style: GoogleFonts.nunitoSans(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadPromotions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_promotions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_rounded, size: 64, color: AppColors.textLight),
            const SizedBox(height: 16),
            Text('No promotions recorded',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Text('Use the action buttons above to promote students.',
                style: GoogleFonts.nunitoSans(
                    fontSize: 13, color: AppColors.textLight)),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _promotions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildPromotionCard(_promotions[i]),
    );
  }

  Widget _buildPromotionCard(dynamic promo) {
    final map = promo is Map<String, dynamic> ? promo : <String, dynamic>{};
    final studentName = map['studentName'] ?? 'Unknown';
    final studentId = map['studentId'] ?? '';
    final fromClass = map['fromClass'] ?? '';
    final fromSection = map['fromSection'] ?? '';
    final toClass = map['toClass'] ?? '';
    final toSection = map['toSection'] ?? '';
    final fromYear = map['fromAcademicYear'] ?? '';
    final toYear = map['toAcademicYear'] ?? '';
    final status = (map['status'] ?? 'PROMOTED').toString().toUpperCase();
    final percentage = map['percentage'];
    final remarks = map['remarks'] ?? '';
    final promotedBy = map['promotedBy'] ?? '';
    final date = map['createdAt'] ?? map['date'] ?? '';

    Color statusColor;
    switch (status) {
      case 'PROMOTED':
        statusColor = AppColors.success;
        break;
      case 'RETAINED':
        statusColor = AppColors.warning;
        break;
      case 'TRANSFERRED':
        statusColor = AppColors.info;
        break;
      case 'TC_ISSUED':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.textSecondary;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: name + status badge
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(studentName,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary)),
                    if (studentId.isNotEmpty)
                      Text('ID: $studentId',
                          style: GoogleFonts.nunitoSans(
                              fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSM),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Class transition row
          Row(
            children: [
              _classChip(fromClass, fromSection),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 18, color: AppColors.gold),
              ),
              _classChip(toClass, toSection),
            ],
          ),

          // Academic year transition
          if (fromYear.isNotEmpty || toYear.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14, color: AppColors.textLight),
                const SizedBox(width: 6),
                Text(
                  '$fromYear  →  $toYear',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],

          // Percentage
          if (percentage != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.percent_rounded,
                    size: 14, color: AppColors.textLight),
                const SizedBox(width: 6),
                Text('$percentage%',
                    style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ],
            ),
          ],

          // Remarks
          if (remarks.toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded,
                    size: 14, color: AppColors.textLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(remarks.toString(),
                      style: GoogleFonts.nunitoSans(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ],

          // Promoted by + date
          if (promotedBy.isNotEmpty || date.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    size: 14, color: AppColors.textLight),
                const SizedBox(width: 4),
                Text(
                  promotedBy.isNotEmpty ? promotedBy : '',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 11, color: AppColors.textLight),
                ),
                if (promotedBy.isNotEmpty && date.isNotEmpty)
                  Text(' · ',
                      style: GoogleFonts.nunitoSans(
                          fontSize: 11, color: AppColors.textLight)),
                if (date.isNotEmpty)
                  Text(_formatDate(date.toString()),
                      style: GoogleFonts.nunitoSans(
                          fontSize: 11, color: AppColors.textLight)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _classChip(String className, String section) {
    final label =
        section.isNotEmpty ? '$className - $section' : className;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.creamDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusSM),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label.isEmpty ? '—' : label,
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.navy)),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  TAB 2: Dashboard
  // ═══════════════════════════════════════════════════════════

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Year selector
          Row(
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _statsYearCtrl,
                  decoration: InputDecoration(
                    labelText: 'Academic Year',
                    labelStyle: GoogleFonts.nunitoSans(fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: GoogleFonts.nunitoSans(fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _loadStats,
                icon: const Icon(Icons.bar_chart_rounded, size: 16),
                label: const Text('Load Stats'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: AppColors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_statsLoading)
            const Center(
                child: Padding(
              padding: EdgeInsets.only(top: 60),
              child: CircularProgressIndicator(color: AppColors.navy),
            )),

          if (_statsError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(_statsError!,
                    style:
                        GoogleFonts.nunitoSans(color: AppColors.textSecondary)),
              ),
            ),

          if (!_statsLoading && _statsError == null && _stats.isNotEmpty) ...[
            // Summary stat cards
            _buildStatCards(),
            const SizedBox(height: 24),
            // Progress summary
            _buildProgressSummary(),
            const SizedBox(height: 24),
            // Class-wise breakdown
            _buildClassBreakdown(),
          ],

          if (!_statsLoading && _statsError == null && _stats.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Text('Select an academic year and load stats.',
                    style:
                        GoogleFonts.nunitoSans(color: AppColors.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    final promoted = _stats['totalPromoted'] ?? 0;
    final retained = _stats['totalRetained'] ?? 0;
    final tcIssued = _stats['totalTCIssued'] ?? 0;

    return Row(
      children: [
        Expanded(
            child: _statCard('Total Promoted', '$promoted',
                Icons.trending_up_rounded, AppColors.success)),
        const SizedBox(width: 12),
        Expanded(
            child: _statCard('Retained', '$retained',
                Icons.pause_circle_outline_rounded, AppColors.warning)),
        const SizedBox(width: 12),
        Expanded(
            child: _statCard('TC Issued', '$tcIssued',
                Icons.exit_to_app_rounded, AppColors.error)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.nunitoSans(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildProgressSummary() {
    final promoted = (_stats['totalPromoted'] ?? 0) as num;
    final total = (_stats['totalStudents'] ?? 0) as num;
    final ratio = total > 0 ? promoted / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Promotion Summary',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppColors.navy)),
          const SizedBox(height: 12),
          Text(
            '${promoted.toInt()} out of ${total.toInt()} students promoted',
            style: GoogleFonts.nunitoSans(
                fontSize: 14, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusSM),
            child: LinearProgressIndicator(
              value: ratio.toDouble(),
              minHeight: 10,
              backgroundColor: AppColors.creamDark,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(ratio * 100).toStringAsFixed(1)}%',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassBreakdown() {
    final classWise = _stats['classWise'];
    if (classWise == null || classWise is! List || classWise.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Class-wise Breakdown',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppColors.navy)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: classWise.map<Widget>((item) {
            final className = item['className'] ?? '';
            final count = item['count'] ?? 0;
            return Container(
              width: 160,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(className.toString(),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.navy)),
                  const SizedBox(height: 4),
                  Text('$count promoted',
                      style: GoogleFonts.nunitoSans(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  DIALOG: Bulk Promote
  // ═══════════════════════════════════════════════════════════

  void _showBulkPromoteDialog(BuildContext ctx) {
    String? fromClass;
    String? toClass;
    final fromYearCtrl = TextEditingController(text: '2024-25');
    final toYearCtrl = TextEditingController(text: '2025-26');
    final sectionCtrl = TextEditingController();
    bool confirmed = false;
    bool submitting = false;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (dialogCtx, dialogSetState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
            title: Row(children: [
              const Icon(Icons.groups_rounded, color: AppColors.gold, size: 22),
              const SizedBox(width: 10),
              Text('Bulk Promote Class',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
            ]),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // From Class
                    _dialogLabel('From Class *'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: fromClass,
                      hint: Text('Select class…',
                          style: GoogleFonts.nunitoSans(
                              color: AppColors.textLight)),
                      decoration: _dialogInputDecoration(),
                      items: SchoolConstants.baseClasses
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  style: GoogleFonts.nunitoSans())))
                          .toList(),
                      onChanged: submitting
                          ? null
                          : (v) => dialogSetState(() => fromClass = v),
                    ),

                    const SizedBox(height: 14),
                    _dialogLabel('From Academic Year *'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: fromYearCtrl,
                      enabled: !submitting,
                      decoration: _dialogInputDecoration(hint: 'e.g. 2024-25'),
                      style: GoogleFonts.nunitoSans(),
                    ),

                    const SizedBox(height: 14),
                    _dialogLabel('To Class *'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: toClass,
                      hint: Text('Select class…',
                          style: GoogleFonts.nunitoSans(
                              color: AppColors.textLight)),
                      decoration: _dialogInputDecoration(),
                      items: SchoolConstants.baseClasses
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  style: GoogleFonts.nunitoSans())))
                          .toList(),
                      onChanged: submitting
                          ? null
                          : (v) => dialogSetState(() => toClass = v),
                    ),

                    const SizedBox(height: 14),
                    _dialogLabel('To Academic Year *'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: toYearCtrl,
                      enabled: !submitting,
                      decoration: _dialogInputDecoration(hint: 'e.g. 2025-26'),
                      style: GoogleFonts.nunitoSans(),
                    ),

                    const SizedBox(height: 14),
                    _dialogLabel('Section (optional)'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: sectionCtrl,
                      enabled: !submitting,
                      decoration: _dialogInputDecoration(hint: 'e.g. A'),
                      style: GoogleFonts.nunitoSans(),
                    ),

                    const SizedBox(height: 18),
                    // Warning
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMD),
                        border:
                            Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.warning, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This will promote ALL students in the selected class.',
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    // Confirmation checkbox
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: confirmed,
                            onChanged: submitting
                                ? null
                                : (v) =>
                                    dialogSetState(() => confirmed = v ?? false),
                            activeColor: AppColors.gold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'I understand this action cannot be easily undone',
                            style: GoogleFonts.nunitoSans(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
                child: Text('Cancel',
                    style: GoogleFonts.poppins(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: (confirmed &&
                        fromClass != null &&
                        toClass != null &&
                        fromYearCtrl.text.trim().isNotEmpty &&
                        toYearCtrl.text.trim().isNotEmpty &&
                        !submitting)
                    ? () async {
                        dialogSetState(() => submitting = true);
                        try {
                          final data = {
                            'fromClass': fromClass,
                            'toClass': toClass,
                            'fromAcademicYear': fromYearCtrl.text.trim(),
                            'toAcademicYear': toYearCtrl.text.trim(),
                            if (sectionCtrl.text.trim().isNotEmpty)
                              'section': sectionCtrl.text.trim(),
                          };
                          await PromotionApiService.bulkPromote(data);
                          if (!ctx.mounted) return;
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Bulk promotion completed successfully!',
                                  style: GoogleFonts.nunitoSans()),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          _loadPromotions();
                        } catch (e) {
                          dialogSetState(() => submitting = false);
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e',
                                  style: GoogleFonts.nunitoSans()),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  ),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.white))
                    : Text('Promote All', style: GoogleFonts.poppins()),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  DIALOG: Individual Promote
  // ═══════════════════════════════════════════════════════════

  void _showIndividualPromoteDialog(BuildContext ctx) {
    final studentIdCtrl = TextEditingController();
    final studentNameCtrl = TextEditingController();
    final fromClassCtrl = TextEditingController();
    String? toClass;
    final toSectionCtrl = TextEditingController();
    final fromYearCtrl = TextEditingController(text: '2024-25');
    final toYearCtrl = TextEditingController(text: '2025-26');
    final percentageCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (dialogCtx, dialogSetState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
            title: Row(children: [
              const Icon(Icons.person_add_rounded,
                  color: AppColors.navy, size: 22),
              const SizedBox(width: 10),
              Text('Promote Individual',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
            ]),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dialogLabel('Student ID *'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: studentIdCtrl,
                      enabled: !submitting,
                      decoration:
                          _dialogInputDecoration(hint: 'e.g. STU-2024-001'),
                      style: GoogleFonts.nunitoSans(),
                    ),

                    const SizedBox(height: 14),
                    _dialogLabel('Student Name *'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: studentNameCtrl,
                      enabled: !submitting,
                      decoration:
                          _dialogInputDecoration(hint: 'Full name'),
                      style: GoogleFonts.nunitoSans(),
                    ),

                    const SizedBox(height: 14),
                    _dialogLabel('From Class'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: fromClassCtrl,
                      enabled: !submitting,
                      decoration: _dialogInputDecoration(
                          hint: 'Auto-fill from student'),
                      style: GoogleFonts.nunitoSans(),
                    ),

                    const SizedBox(height: 14),
                    _dialogLabel('To Class *'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: toClass,
                      hint: Text('Select class…',
                          style: GoogleFonts.nunitoSans(
                              color: AppColors.textLight)),
                      decoration: _dialogInputDecoration(),
                      items: SchoolConstants.baseClasses
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  style: GoogleFonts.nunitoSans())))
                          .toList(),
                      onChanged: submitting
                          ? null
                          : (v) => dialogSetState(() => toClass = v),
                    ),

                    const SizedBox(height: 14),
                    _dialogLabel('To Section'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: toSectionCtrl,
                      enabled: !submitting,
                      decoration: _dialogInputDecoration(hint: 'e.g. A'),
                      style: GoogleFonts.nunitoSans(),
                    ),

                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _dialogLabel('From Academic Year'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: fromYearCtrl,
                                enabled: !submitting,
                                decoration: _dialogInputDecoration(
                                    hint: '2024-25'),
                                style: GoogleFonts.nunitoSans(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _dialogLabel('To Academic Year'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: toYearCtrl,
                                enabled: !submitting,
                                decoration: _dialogInputDecoration(
                                    hint: '2025-26'),
                                style: GoogleFonts.nunitoSans(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    _dialogLabel('Percentage (optional)'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: percentageCtrl,
                      enabled: !submitting,
                      keyboardType: TextInputType.number,
                      decoration:
                          _dialogInputDecoration(hint: 'e.g. 85.5'),
                      style: GoogleFonts.nunitoSans(),
                    ),

                    const SizedBox(height: 14),
                    _dialogLabel('Remarks'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: remarksCtrl,
                      enabled: !submitting,
                      decoration:
                          _dialogInputDecoration(hint: 'Optional remarks'),
                      style: GoogleFonts.nunitoSans(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
                child: Text('Cancel',
                    style: GoogleFonts.poppins(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: (studentIdCtrl.text.trim().isNotEmpty &&
                        studentNameCtrl.text.trim().isNotEmpty &&
                        toClass != null &&
                        !submitting)
                    ? () async {
                        dialogSetState(() => submitting = true);
                        try {
                          final data = {
                            'studentId': studentIdCtrl.text.trim(),
                            'studentName': studentNameCtrl.text.trim(),
                            if (fromClassCtrl.text.trim().isNotEmpty)
                              'fromClass': fromClassCtrl.text.trim(),
                            'toClass': toClass,
                            if (toSectionCtrl.text.trim().isNotEmpty)
                              'toSection': toSectionCtrl.text.trim(),
                            if (fromYearCtrl.text.trim().isNotEmpty)
                              'fromAcademicYear': fromYearCtrl.text.trim(),
                            if (toYearCtrl.text.trim().isNotEmpty)
                              'toAcademicYear': toYearCtrl.text.trim(),
                            if (percentageCtrl.text.trim().isNotEmpty)
                              'percentage':
                                  double.tryParse(percentageCtrl.text.trim()),
                            if (remarksCtrl.text.trim().isNotEmpty)
                              'remarks': remarksCtrl.text.trim(),
                          };
                          await PromotionApiService.promoteStudent(data);
                          if (!ctx.mounted) return;
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Student promoted successfully!',
                                  style: GoogleFonts.nunitoSans()),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          _loadPromotions();
                        } catch (e) {
                          dialogSetState(() => submitting = false);
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e',
                                  style: GoogleFonts.nunitoSans()),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  ),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.white))
                    : Text('Promote', style: GoogleFonts.poppins()),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  DIALOG: Issue TC
  // ═══════════════════════════════════════════════════════════

  void _showIssueTCDialog(BuildContext ctx) {
    final studentIdCtrl = TextEditingController();
    final studentNameCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (dialogCtx, dialogSetState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
            title: Row(children: [
              const Icon(Icons.exit_to_app_rounded,
                  color: AppColors.error, size: 22),
              const SizedBox(width: 10),
              Text('Issue Transfer Certificate',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
            ]),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogLabel('Student ID *'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: studentIdCtrl,
                    enabled: !submitting,
                    decoration:
                        _dialogInputDecoration(hint: 'e.g. STU-2024-001'),
                    style: GoogleFonts.nunitoSans(),
                  ),

                  const SizedBox(height: 14),
                  _dialogLabel('Student Name'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: studentNameCtrl,
                    enabled: !submitting,
                    decoration: _dialogInputDecoration(hint: 'Full name'),
                    style: GoogleFonts.nunitoSans(),
                  ),

                  const SizedBox(height: 14),
                  _dialogLabel('Remarks *'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: remarksCtrl,
                    enabled: !submitting,
                    maxLines: 3,
                    decoration: _dialogInputDecoration(
                        hint: 'Reason for issuing TC…'),
                    style: GoogleFonts.nunitoSans(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
                child: Text('Cancel',
                    style: GoogleFonts.poppins(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: (studentIdCtrl.text.trim().isNotEmpty &&
                        remarksCtrl.text.trim().isNotEmpty &&
                        !submitting)
                    ? () async {
                        dialogSetState(() => submitting = true);
                        try {
                          final data = {
                            'studentId': studentIdCtrl.text.trim(),
                            if (studentNameCtrl.text.trim().isNotEmpty)
                              'studentName': studentNameCtrl.text.trim(),
                            'remarks': remarksCtrl.text.trim(),
                          };
                          await PromotionApiService.issueTC(data);
                          if (!ctx.mounted) return;
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Transfer Certificate issued successfully!',
                                  style: GoogleFonts.nunitoSans()),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          _loadPromotions();
                        } catch (e) {
                          dialogSetState(() => submitting = false);
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e',
                                  style: GoogleFonts.nunitoSans()),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                  ),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.white))
                    : Text('Issue TC', style: GoogleFonts.poppins()),
              ),
            ],
          );
        },
      ),
    );
  }

  // ───────────────────────── Dialog helpers ─────────────────────────

  Widget _dialogLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.nunitoSans(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: AppColors.textSecondary,
      ),
    );
  }

  InputDecoration _dialogInputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.nunitoSans(color: AppColors.textLight),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
