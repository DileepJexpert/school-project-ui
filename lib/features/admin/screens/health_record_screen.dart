import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/health_record_api_service.dart';

class HealthRecordScreen extends StatefulWidget {
  const HealthRecordScreen({super.key});

  @override
  State<HealthRecordScreen> createState() => _HealthRecordScreenState();
}

class _HealthRecordScreenState extends State<HealthRecordScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Records state ---
  bool _loadingRecords = true;
  List<Map<String, dynamic>> _records = [];
  String _searchQuery = '';
  String? _classFilter;

  // --- Dashboard state ---
  bool _loadingStats = true;
  Map<String, dynamic> _stats = {};

  static const _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    _loadRecords();
    _loadStats();
  }

  Future<void> _loadRecords() async {
    setState(() => _loadingRecords = true);
    try {
      final data = await HealthRecordApiService.getAllRecords();
      if (mounted) {
        setState(() => _records = List<Map<String, dynamic>>.from(
            data.map((e) => Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingRecords = false);
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final data = await HealthRecordApiService.getStats();
      if (mounted) setState(() => _stats = data);
    } catch (_) {}
    if (mounted) setState(() => _loadingStats = false);
  }

  List<Map<String, dynamic>> get _filteredRecords {
    var list = _records;
    if (_classFilter != null && _classFilter!.isNotEmpty) {
      list = list
          .where((r) => (r['className'] as String? ?? '') == _classFilter)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        final name = (r['studentName'] as String? ?? '').toLowerCase();
        final sid = (r['studentId'] as String? ?? '').toLowerCase();
        final bg = (r['bloodGroup'] as String? ?? '').toLowerCase();
        return name.contains(q) || sid.contains(q) || bg.contains(q);
      }).toList();
    }
    return list;
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
              Tab(text: 'Health Records'),
              Tab(text: 'Dashboard'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRecordsTab(),
              _buildDashboardTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────── TAB 1: Health Records ─────────────────────

  Widget _buildRecordsTab() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.contentPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student Health Records',
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              const SizedBox(height: 4),
              Text('Manage student health information and medical visits.',
                  style: GoogleFonts.poppins(
                      color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 20),

              // Filters row
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Class filter
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      value: _classFilter,
                      decoration: _inputDecoration('All Classes'),
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: AppColors.textPrimary),
                      isExpanded: true,
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Classes',
                              style: GoogleFonts.poppins(fontSize: 14)),
                        ),
                        ...SchoolConstants.baseClasses.map((c) =>
                            DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    style:
                                        GoogleFonts.poppins(fontSize: 14)))),
                      ],
                      onChanged: (v) => setState(() => _classFilter = v),
                    ),
                  ),
                  // Search
                  SizedBox(
                    width: 280,
                    child: TextFormField(
                      decoration: InputDecoration(
                        hintText: 'Search by name, ID, blood group...',
                        hintStyle: GoogleFonts.poppins(
                            fontSize: 14, color: AppColors.textLight),
                        prefixIcon: const Icon(Icons.search,
                            color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD),
                          borderSide:
                              const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD),
                          borderSide:
                              const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMD),
                          borderSide: const BorderSide(
                              color: AppColors.navy, width: 1.5),
                        ),
                      ),
                      style: GoogleFonts.poppins(fontSize: 14),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Records list
              if (_loadingRecords)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_filteredRecords.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.medical_information_outlined,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('No health records found',
                            style: GoogleFonts.poppins(
                                color: AppColors.textLight, fontSize: 14)),
                      ],
                    ),
                  ),
                )
              else
                _buildRecordGrid(),

              const SizedBox(height: 80),
            ],
          ),
        ),
        // FAB
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            heroTag: 'add_health_record',
            onPressed: () => _showRecordDialog(),
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text('Add Record',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordGrid() {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);
    final columns = isDesktop ? 3 : (isTablet ? 2 : 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _filteredRecords.map((record) {
            return SizedBox(
              width: cardWidth,
              child: _buildRecordCard(record),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final studentName = record['studentName'] as String? ?? 'Unknown';
    final className = record['className'] as String? ?? '';
    final bloodGroup = record['bloodGroup'] as String? ?? '';
    final height = record['height'];
    final weight = record['weight'];
    final allergies = _toStringList(record['allergies']);
    final chronicConditions = _toStringList(record['chronicConditions']);
    final emergencyContactName =
        record['emergencyContactName'] as String? ?? '';
    final emergencyContactPhone =
        record['emergencyContactPhone'] as String? ?? '';
    final visits = record['medicalVisits'] as List? ?? [];
    final id = record['_id'] as String? ?? record['id'] as String? ?? '';

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
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(studentName,
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
                    if (v == 'view') {
                      _showDetailDialog(record);
                    } else if (v == 'edit') {
                      _showRecordDialog(record: record);
                    } else if (v == 'delete') {
                      _confirmDelete(id, studentName);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                        value: 'view',
                        child: Text('View Details',
                            style: GoogleFonts.poppins())),
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
            const SizedBox(height: 6),

            // Class chip + Blood group badge
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (className.isNotEmpty) _chip(className, AppColors.navy),
                if (bloodGroup.isNotEmpty)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(bloodGroup,
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error)),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Height / Weight
            if (height != null || weight != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.straighten, size: 14, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Text(
                      [
                        if (height != null) '${height}cm',
                        if (weight != null) '${weight}kg',
                      ].join(' | '),
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

            // Allergies
            if (allergies.isNotEmpty) ...[
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: allergies
                    .map((a) => _chip(a, AppColors.error))
                    .toList(),
              ),
              const SizedBox(height: 6),
            ],

            // Chronic conditions
            if (chronicConditions.isNotEmpty) ...[
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: chronicConditions
                    .map((c) => _chip(c, AppColors.warning))
                    .toList(),
              ),
              const SizedBox(height: 6),
            ],

            // Emergency contact
            if (emergencyContactName.isNotEmpty ||
                emergencyContactPhone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.emergency_outlined,
                        size: 14, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        [emergencyContactName, emergencyContactPhone]
                            .where((s) => s.isNotEmpty)
                            .join(' - '),
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Visits badge
            if (visits.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.local_hospital_outlined,
                      size: 14, color: AppColors.info),
                  const SizedBox(width: 4),
                  Text('${visits.length} medical visit${visits.length == 1 ? '' : 's'}',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.info,
                          fontWeight: FontWeight.w500)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────────── TAB 2: Dashboard ─────────────────────

  Widget _buildDashboardTab() {
    if (_loadingStats && _loadingRecords) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalRecords =
        ((_stats['totalRecords'] as num?)?.toInt()) ?? _records.length;
    final studentsWithAllergies =
        ((_stats['studentsWithAllergies'] as num?)?.toInt()) ??
            _records.where((r) {
              final a = _toStringList(r['allergies']);
              return a.isNotEmpty;
            }).length;

    final bloodGroupDistribution =
        _stats['bloodGroupDistribution'] as Map<String, dynamic>? ??
            _buildLocalBloodGroupDistribution();

    final isWide =
        Responsive.isDesktop(context) || Responsive.isTablet(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Health Dashboard',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text('Overview of student health data.',
              style: GoogleFonts.poppins(
                  color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),

          // Stat cards
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = isWide ? 2 : 1;
              final cardWidth =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _statCard(
                      'Total Records',
                      '$totalRecords',
                      Icons.medical_information_rounded,
                      AppColors.navy,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _statCard(
                      'Students with Allergies',
                      '$studentsWithAllergies',
                      Icons.warning_amber_rounded,
                      AppColors.error,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Blood group distribution
          _buildBloodGroupCard(bloodGroupDistribution),
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

  Widget _buildBloodGroupCard(Map<String, dynamic> distribution) {
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
            Text('Blood Group Distribution',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
            const SizedBox(height: 16),
            if (distribution.isEmpty)
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
                children: _bloodGroups.map((bg) {
                  final count =
                      (distribution[bg] as num?)?.toInt() ?? 0;
                  final color = _bloodGroupColor(bg);
                  return Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMD),
                      border:
                          Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text('$count',
                            style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: color)),
                        Text(bg,
                            style: GoogleFonts.poppins(
                                fontSize: 12,
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

  Future<void> _showRecordDialog({Map<String, dynamic>? record}) async {
    final isEdit = record != null;

    final studentIdC =
        TextEditingController(text: record?['studentId'] as String? ?? '');
    final studentNameC =
        TextEditingController(text: record?['studentName'] as String? ?? '');
    final heightC = TextEditingController(
        text: record?['height'] != null ? '${record!['height']}' : '');
    final weightC = TextEditingController(
        text: record?['weight'] != null ? '${record!['weight']}' : '');
    final visionC =
        TextEditingController(text: record?['vision'] as String? ?? '');
    final allergiesC = TextEditingController(
        text: _toStringList(record?['allergies']).join(', '));
    final chronicC = TextEditingController(
        text: _toStringList(record?['chronicConditions']).join(', '));
    final medicationsC = TextEditingController(
        text: record?['currentMedications'] as String? ?? '');
    final vaccinationsC = TextEditingController(
        text: _toStringList(record?['vaccinationRecords']).join(', '));
    final emergNameC = TextEditingController(
        text: record?['emergencyContactName'] as String? ?? '');
    final emergPhoneC = TextEditingController(
        text: record?['emergencyContactPhone'] as String? ?? '');
    final emergRelationC = TextEditingController(
        text: record?['emergencyContactRelation'] as String? ?? '');
    final familyDoctorC = TextEditingController(
        text: record?['familyDoctor'] as String? ?? '');
    final familyDoctorPhoneC = TextEditingController(
        text: record?['familyDoctorPhone'] as String? ?? '');

    String selectedClass = record?['className'] as String? ??
        SchoolConstants.baseClasses.first;
    String? selectedBloodGroup = record?['bloodGroup'] as String?;

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
                  isEdit ? 'Edit Health Record' : 'Add Health Record',
                  style:
                      GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dialogField(
                          'Student ID *', studentIdC, 'Student ID'),
                      const SizedBox(height: 12),
                      _dialogField('Student Name *', studentNameC,
                          'Full name'),
                      const SizedBox(height: 12),

                      // Class dropdown
                      _dialogLabel('Class *'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: SchoolConstants.baseClasses
                                .contains(selectedClass)
                            ? selectedClass
                            : SchoolConstants.baseClasses.first,
                        decoration: _inputDecoration('Select class'),
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.textPrimary),
                        isExpanded: true,
                        items: SchoolConstants.baseClasses
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    style: GoogleFonts.poppins(
                                        fontSize: 14))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => selectedClass = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Blood Group dropdown
                      _dialogLabel('Blood Group'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedBloodGroup,
                        decoration:
                            _inputDecoration('Select blood group'),
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.textPrimary),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text('Not specified',
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: AppColors.textLight)),
                          ),
                          ..._bloodGroups.map((bg) => DropdownMenuItem(
                              value: bg,
                              child: Text(bg,
                                  style: GoogleFonts.poppins(
                                      fontSize: 14)))),
                        ],
                        onChanged: (v) {
                          setDialogState(
                              () => selectedBloodGroup = v);
                        },
                      ),
                      const SizedBox(height: 12),

                      _dialogField('Height (cm)', heightC, 'e.g. 150',
                          keyboardType: TextInputType.number),
                      const SizedBox(height: 12),
                      _dialogField('Weight (kg)', weightC, 'e.g. 45',
                          keyboardType: TextInputType.number),
                      const SizedBox(height: 12),
                      _dialogField(
                          'Vision', visionC, 'e.g. 6/6'),
                      const SizedBox(height: 12),
                      _dialogField('Allergies', allergiesC,
                          'Comma separated, e.g. Peanuts, Dust'),
                      const SizedBox(height: 12),
                      _dialogField('Chronic Conditions', chronicC,
                          'Comma separated, e.g. Asthma'),
                      const SizedBox(height: 12),
                      _dialogField('Current Medications',
                          medicationsC, 'Current medications'),
                      const SizedBox(height: 12),
                      _dialogField('Vaccination Records',
                          vaccinationsC,
                          'Comma separated, e.g. BCG, Polio'),
                      const SizedBox(height: 12),
                      _dialogField('Emergency Contact Name',
                          emergNameC, 'Contact person name'),
                      const SizedBox(height: 12),
                      _dialogField('Emergency Contact Phone',
                          emergPhoneC, 'Phone number',
                          keyboardType: TextInputType.phone),
                      const SizedBox(height: 12),
                      _dialogField('Emergency Contact Relation',
                          emergRelationC, 'e.g. Father, Mother'),
                      const SizedBox(height: 12),
                      _dialogField('Family Doctor', familyDoctorC,
                          'Doctor name'),
                      const SizedBox(height: 12),
                      _dialogField('Family Doctor Phone',
                          familyDoctorPhoneC, 'Doctor phone',
                          keyboardType: TextInputType.phone),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child:
                      Text('Cancel', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (studentIdC.text.trim().isEmpty ||
                              studentNameC.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Student ID and Name are required')),
                            );
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            final data = <String, dynamic>{
                              'studentId':
                                  studentIdC.text.trim(),
                              'studentName':
                                  studentNameC.text.trim(),
                              'className': selectedClass,
                            };
                            if (selectedBloodGroup != null) {
                              data['bloodGroup'] =
                                  selectedBloodGroup;
                            }
                            if (heightC.text.trim().isNotEmpty) {
                              data['height'] = double.tryParse(
                                      heightC.text.trim()) ??
                                  0;
                            }
                            if (weightC.text.trim().isNotEmpty) {
                              data['weight'] = double.tryParse(
                                      weightC.text.trim()) ??
                                  0;
                            }
                            if (visionC.text.trim().isNotEmpty) {
                              data['vision'] =
                                  visionC.text.trim();
                            }
                            final allergyList = _splitComma(
                                allergiesC.text);
                            if (allergyList.isNotEmpty) {
                              data['allergies'] = allergyList;
                            }
                            final chronicList = _splitComma(
                                chronicC.text);
                            if (chronicList.isNotEmpty) {
                              data['chronicConditions'] =
                                  chronicList;
                            }
                            if (medicationsC
                                .text.trim().isNotEmpty) {
                              data['currentMedications'] =
                                  medicationsC.text.trim();
                            }
                            final vaccList = _splitComma(
                                vaccinationsC.text);
                            if (vaccList.isNotEmpty) {
                              data['vaccinationRecords'] =
                                  vaccList;
                            }
                            if (emergNameC
                                .text.trim().isNotEmpty) {
                              data['emergencyContactName'] =
                                  emergNameC.text.trim();
                            }
                            if (emergPhoneC
                                .text.trim().isNotEmpty) {
                              data['emergencyContactPhone'] =
                                  emergPhoneC.text.trim();
                            }
                            if (emergRelationC
                                .text.trim().isNotEmpty) {
                              data['emergencyContactRelation'] =
                                  emergRelationC.text.trim();
                            }
                            if (familyDoctorC
                                .text.trim().isNotEmpty) {
                              data['familyDoctor'] =
                                  familyDoctorC.text.trim();
                            }
                            if (familyDoctorPhoneC
                                .text.trim().isNotEmpty) {
                              data['familyDoctorPhone'] =
                                  familyDoctorPhoneC.text.trim();
                            }

                            if (isEdit) {
                              final id = record['_id']
                                      as String? ??
                                  record['id'] as String? ??
                                  '';
                              data['_id'] = id;
                            }

                            await HealthRecordApiService
                                .createOrUpdate(data);
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(isEdit
                                      ? 'Record updated!'
                                      : 'Record added!'),
                                  backgroundColor:
                                      AppColors.success,
                                ),
                              );
                              _loadRecords();
                              _loadStats();
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Failed: $e'),
                                  backgroundColor:
                                      AppColors.error,
                                ),
                              );
                            }
                          }
                          setDialogState(
                              () => saving = false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMD),
                    ),
                  ),
                  child: Text(
                    saving
                        ? 'Saving...'
                        : (isEdit ? 'Update' : 'Add'),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ───────────── Detail Dialog ─────────────

  void _showDetailDialog(Map<String, dynamic> record) {
    final studentName = record['studentName'] as String? ?? 'Unknown';
    final studentId = record['studentId'] as String? ?? '';
    final className = record['className'] as String? ?? '';
    final bloodGroup = record['bloodGroup'] as String? ?? '';
    final height = record['height'];
    final weight = record['weight'];
    final vision = record['vision'] as String? ?? '';
    final allergies = _toStringList(record['allergies']);
    final chronicConditions = _toStringList(record['chronicConditions']);
    final medications = record['currentMedications'] as String? ?? '';
    final vaccinations = _toStringList(record['vaccinationRecords']);
    final emergName = record['emergencyContactName'] as String? ?? '';
    final emergPhone = record['emergencyContactPhone'] as String? ?? '';
    final emergRelation = record['emergencyContactRelation'] as String? ?? '';
    final familyDoctor = record['familyDoctor'] as String? ?? '';
    final familyDoctorPhone = record['familyDoctorPhone'] as String? ?? '';
    final visits = (record['medicalVisits'] as List?)
            ?.map((v) => Map<String, dynamic>.from(v as Map))
            .toList() ??
        [];
    final recordId = record['_id'] as String? ?? record['id'] as String? ?? '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(studentName,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700)),
                  ),
                  if (bloodGroup.isNotEmpty)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(bloodGroup,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error)),
                    ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Basic info
                      _detailRow('Student ID', studentId),
                      _detailRow('Class', className),
                      if (height != null)
                        _detailRow('Height', '${height} cm'),
                      if (weight != null)
                        _detailRow('Weight', '${weight} kg'),
                      if (vision.isNotEmpty)
                        _detailRow('Vision', vision),

                      // Allergies
                      if (allergies.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _dialogLabel('Allergies'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: allergies
                              .map((a) => _chip(a, AppColors.error))
                              .toList(),
                        ),
                      ],

                      // Chronic conditions
                      if (chronicConditions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _dialogLabel('Chronic Conditions'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: chronicConditions
                              .map((c) => _chip(c, AppColors.warning))
                              .toList(),
                        ),
                      ],

                      if (medications.isNotEmpty)
                        _detailRow('Current Medications', medications),

                      // Vaccinations
                      if (vaccinations.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _dialogLabel('Vaccination Records'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: vaccinations
                              .map((v) => _chip(v, AppColors.success))
                              .toList(),
                        ),
                      ],

                      // Emergency contact
                      if (emergName.isNotEmpty ||
                          emergPhone.isNotEmpty ||
                          emergRelation.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text('Emergency Contact',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy)),
                        const SizedBox(height: 8),
                        if (emergName.isNotEmpty)
                          _detailRow('Name', emergName),
                        if (emergPhone.isNotEmpty)
                          _detailRow('Phone', emergPhone),
                        if (emergRelation.isNotEmpty)
                          _detailRow('Relation', emergRelation),
                      ],

                      // Family doctor
                      if (familyDoctor.isNotEmpty ||
                          familyDoctorPhone.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text('Family Doctor',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy)),
                        const SizedBox(height: 8),
                        if (familyDoctor.isNotEmpty)
                          _detailRow('Doctor', familyDoctor),
                        if (familyDoctorPhone.isNotEmpty)
                          _detailRow('Phone', familyDoctorPhone),
                      ],

                      // Medical visits
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Medical Visits',
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy)),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _showVisitDialog(
                                  studentId.isNotEmpty
                                      ? studentId
                                      : recordId);
                              _loadRecords();
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: Text('Add Visit',
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (visits.isEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text('No medical visits recorded',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppColors.textLight)),
                          ),
                        )
                      else
                        ...visits.asMap().entries.map((entry) {
                          final i = entry.key;
                          final visit = entry.value;
                          return _buildVisitItem(
                            visit,
                            studentId.isNotEmpty
                                ? studentId
                                : recordId,
                            i < visits.length - 1,
                            setDialogState,
                          );
                        }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Close', style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildVisitItem(
    Map<String, dynamic> visit,
    String studentId,
    bool showDivider,
    void Function(void Function()) setDialogState,
  ) {
    final date = visit['date'] as String? ?? '';
    final reason = visit['reason'] as String? ?? '';
    final symptoms = visit['symptoms'] as String? ?? '';
    final treatment = visit['treatment'] as String? ?? '';
    final attendedBy = visit['attendedBy'] as String? ?? '';
    final sentHome = visit['sentHome'] == true;
    final remarks = visit['remarks'] as String? ?? '';
    final visitId =
        visit['_id'] as String? ?? visit['id'] as String? ?? '';

    String dateStr = '';
    if (date.isNotEmpty) {
      try {
        final dt = DateTime.parse(date);
        dateStr = DateFormat('dd MMM yyyy').format(dt.toLocal());
      } catch (_) {
        dateStr = date;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline dot
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: sentHome
                          ? AppColors.warning
                          : AppColors.info,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (showDivider)
                    Container(
                      width: 2,
                      height: 40,
                      color: AppColors.border,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(reason,
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                        ),
                        if (visitId.isNotEmpty)
                          InkWell(
                            onTap: () async {
                              try {
                                await HealthRecordApiService
                                    .removeVisit(
                                        studentId, visitId);
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Visit removed'),
                                      backgroundColor:
                                          AppColors.success,
                                    ),
                                  );
                                  _loadRecords();
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Failed: $e'),
                                      backgroundColor:
                                          AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: AppColors.error),
                          ),
                      ],
                    ),
                    if (dateStr.isNotEmpty)
                      Text(dateStr,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    if (symptoms.isNotEmpty)
                      Text('Symptoms: $symptoms',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    if (treatment.isNotEmpty)
                      Text('Treatment: $treatment',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    if (attendedBy.isNotEmpty)
                      Text('Attended by: $attendedBy',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    if (sentHome)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _chip('Sent Home', AppColors.warning),
                      ),
                    if (remarks.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Remarks: $remarks',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textLight)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const SizedBox(height: 4),
      ],
    );
  }

  // ───────────── Add Medical Visit Dialog ─────────────

  Future<void> _showVisitDialog(String studentId) async {
    final reasonC = TextEditingController();
    final symptomsC = TextEditingController();
    final treatmentC = TextEditingController();
    final attendedByC = TextEditingController();
    final remarksC = TextEditingController();
    DateTime visitDate = DateTime.now();
    bool sentHome = false;
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
              title: Text('Add Medical Visit',
                  style:
                      GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date
                      _dialogLabel('Date'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: visitDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(
                                () => visitDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration:
                              _inputDecoration('Select date'),
                          child: Text(
                            DateFormat('dd MMM yyyy')
                                .format(visitDate),
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _dialogField(
                          'Reason *', reasonC, 'Reason for visit'),
                      const SizedBox(height: 12),
                      _dialogField(
                          'Symptoms', symptomsC, 'Symptoms observed'),
                      const SizedBox(height: 12),
                      _dialogField('Treatment', treatmentC,
                          'Treatment provided',
                          maxLines: 3),
                      const SizedBox(height: 12),
                      _dialogField('Attended By', attendedByC,
                          'Doctor / Nurse name'),
                      const SizedBox(height: 12),

                      // Sent Home switch
                      Row(
                        children: [
                          Text('Sent Home',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          const Spacer(),
                          Switch(
                            value: sentHome,
                            activeColor: AppColors.gold,
                            onChanged: (v) =>
                                setDialogState(() => sentHome = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _dialogField(
                          'Remarks', remarksC, 'Additional remarks'),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child:
                      Text('Cancel', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (reasonC.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Reason is required')),
                            );
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            final data = <String, dynamic>{
                              'date': visitDate
                                  .toIso8601String(),
                              'reason':
                                  reasonC.text.trim(),
                              'sentHome': sentHome,
                            };
                            if (symptomsC
                                .text.trim().isNotEmpty) {
                              data['symptoms'] =
                                  symptomsC.text.trim();
                            }
                            if (treatmentC
                                .text.trim().isNotEmpty) {
                              data['treatment'] =
                                  treatmentC.text.trim();
                            }
                            if (attendedByC
                                .text.trim().isNotEmpty) {
                              data['attendedBy'] =
                                  attendedByC.text.trim();
                            }
                            if (remarksC
                                .text.trim().isNotEmpty) {
                              data['remarks'] =
                                  remarksC.text.trim();
                            }

                            await HealthRecordApiService
                                .addVisit(studentId, data);
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Visit added!'),
                                  backgroundColor:
                                      AppColors.success,
                                ),
                              );
                              _loadRecords();
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Failed: $e'),
                                  backgroundColor:
                                      AppColors.error,
                                ),
                              );
                            }
                          }
                          setDialogState(
                              () => saving = false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMD),
                    ),
                  ),
                  child: Text(
                    saving ? 'Saving...' : 'Add Visit',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ───────────── Confirm Delete ─────────────

  Future<void> _confirmDelete(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        ),
        title: Text('Delete Health Record',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure you want to delete the health record for "$name"?',
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
        await HealthRecordApiService.delete(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Health record deleted'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadRecords();
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

  Widget _detailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Color _bloodGroupColor(String bg) {
    return switch (bg) {
      'A+' || 'A-' => AppColors.error,
      'B+' || 'B-' => AppColors.info,
      'O+' || 'O-' => AppColors.success,
      'AB+' || 'AB-' => AppColors.warning,
      _ => AppColors.textSecondary,
    };
  }

  List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    }
    if (value is String && value.isNotEmpty) {
      return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  List<String> _splitComma(String text) {
    return text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _buildLocalBloodGroupDistribution() {
    final map = <String, int>{};
    for (final r in _records) {
      final bg = r['bloodGroup'] as String? ?? '';
      if (bg.isNotEmpty) {
        map[bg] = (map[bg] ?? 0) + 1;
      }
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
