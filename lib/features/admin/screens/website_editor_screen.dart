import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/school_website_service.dart';

class WebsiteEditorScreen extends StatefulWidget {
  const WebsiteEditorScreen({super.key});

  @override
  State<WebsiteEditorScreen> createState() => _WebsiteEditorScreenState();
}

class _WebsiteEditorScreenState extends State<WebsiteEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic> _data = {};

  // ── Text controllers for each field ──
  final _schoolNameCtrl = TextEditingController();
  final _shortNameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _accreditationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _officeHoursCtrl = TextEditingController();
  final _primaryColorCtrl = TextEditingController();
  final _secondaryColorCtrl = TextEditingController();
  final _marqueeCtrl = TextEditingController();
  final _principalNameCtrl = TextEditingController();
  final _principalTitleCtrl = TextEditingController();
  final _principalMsgCtrl = TextEditingController();
  final _missionCtrl = TextEditingController();
  final _visionCtrl = TextEditingController();

  // Dynamic list controllers
  List<Map<String, TextEditingController>> _statsCtrls = [];
  List<Map<String, TextEditingController>> _achievementsCtrls = [];
  List<Map<String, TextEditingController>> _eventsCtrls = [];
  List<Map<String, TextEditingController>> _testimonialsCtrls = [];
  List<Map<String, TextEditingController>> _feeStructureCtrls = [];
  List<Map<String, TextEditingController>> _timelineCtrls = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _schoolNameCtrl.dispose();
    _shortNameCtrl.dispose();
    _taglineCtrl.dispose();
    _accreditationCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _officeHoursCtrl.dispose();
    _primaryColorCtrl.dispose();
    _secondaryColorCtrl.dispose();
    _marqueeCtrl.dispose();
    _principalNameCtrl.dispose();
    _principalTitleCtrl.dispose();
    _principalMsgCtrl.dispose();
    _missionCtrl.dispose();
    _visionCtrl.dispose();
    for (final m in [..._statsCtrls, ..._achievementsCtrls, ..._eventsCtrls, ..._testimonialsCtrls, ..._feeStructureCtrls, ..._timelineCtrls]) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _data = await SchoolWebsiteService.getWebsite();
      _populateFields();
    } catch (e) {
      _error = 'Failed to load website config: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _populateFields() {
    _schoolNameCtrl.text = _data['schoolName'] ?? '';
    _shortNameCtrl.text = _data['shortName'] ?? '';
    _taglineCtrl.text = _data['tagline'] ?? '';
    _accreditationCtrl.text = _data['accreditation'] ?? '';
    _phoneCtrl.text = _data['phone'] ?? '';
    _emailCtrl.text = _data['email'] ?? '';
    _addressCtrl.text = _data['address'] ?? '';
    _officeHoursCtrl.text = _data['officeHours'] ?? '';
    _primaryColorCtrl.text = _data['primaryColor'] ?? '#1B3A5C';
    _secondaryColorCtrl.text = _data['secondaryColor'] ?? '#C8922A';
    _marqueeCtrl.text = _data['marqueeText'] ?? '';
    _principalNameCtrl.text = _data['principalName'] ?? '';
    _principalTitleCtrl.text = _data['principalTitle'] ?? '';
    _principalMsgCtrl.text = _data['principalMessage'] ?? '';
    _missionCtrl.text = _data['mission'] ?? '';
    _visionCtrl.text = _data['vision'] ?? '';

    _statsCtrls = _buildListCtrls(_data['stats'], ['value', 'label']);
    _achievementsCtrls = _buildListCtrls(_data['achievements'], ['year', 'title']);
    _eventsCtrls = _buildListCtrls(_data['events'], ['date', 'title', 'description', 'category']);
    _testimonialsCtrls = _buildListCtrls(_data['testimonials'], ['name', 'relation', 'text']);
    _feeStructureCtrls = _buildListCtrls(_data['feeStructure'], ['grade', 'admission', 'tuition', 'annual']);
    _timelineCtrls = _buildListCtrls(_data['timeline'], ['year', 'text']);
  }

  List<Map<String, TextEditingController>> _buildListCtrls(
      dynamic list, List<String> keys) {
    if (list == null || list is! List) return [];
    return list.map<Map<String, TextEditingController>>((item) {
      final m = item as Map<String, dynamic>;
      return {for (var k in keys) k: TextEditingController(text: m[k]?.toString() ?? '')};
    }).toList();
  }

  List<Map<String, String>> _readListCtrls(
      List<Map<String, TextEditingController>> ctrls) {
    return ctrls
        .map((m) => m.map((k, c) => MapEntry(k, c.text)))
        .where((m) => m.values.any((v) => v.isNotEmpty))
        .toList();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'schoolName': _schoolNameCtrl.text,
        'shortName': _shortNameCtrl.text,
        'tagline': _taglineCtrl.text,
        'accreditation': _accreditationCtrl.text,
        'phone': _phoneCtrl.text,
        'email': _emailCtrl.text,
        'address': _addressCtrl.text,
        'officeHours': _officeHoursCtrl.text,
        'primaryColor': _primaryColorCtrl.text,
        'secondaryColor': _secondaryColorCtrl.text,
        'marqueeText': _marqueeCtrl.text,
        'principalName': _principalNameCtrl.text,
        'principalTitle': _principalTitleCtrl.text,
        'principalMessage': _principalMsgCtrl.text,
        'mission': _missionCtrl.text,
        'vision': _visionCtrl.text,
        'stats': _readListCtrls(_statsCtrls),
        'achievements': _readListCtrls(_achievementsCtrls),
        'events': _readListCtrls(_eventsCtrls),
        'testimonials': _readListCtrls(_testimonialsCtrls),
        'feeStructure': _readListCtrls(_feeStructureCtrls),
        'timeline': _readListCtrls(_timelineCtrls),
        // Preserve sections not edited here
        if (_data['coreValues'] != null) 'coreValues': _data['coreValues'],
        if (_data['notices'] != null) 'notices': _data['notices'],
        if (_data['academicLevels'] != null) 'academicLevels': _data['academicLevels'],
        if (_data['coCurriculars'] != null) 'coCurriculars': _data['coCurriculars'],
        if (_data['admissionSteps'] != null) 'admissionSteps': _data['admissionSteps'],
        if (_data['importantDates'] != null) 'importantDates': _data['importantDates'],
        if (_data['galleryImages'] != null) 'galleryImages': _data['galleryImages'],
        if (_data['transportZones'] != null) 'transportZones': _data['transportZones'],
        if (_data['transportFeatures'] != null) 'transportFeatures': _data['transportFeatures'],
        if (_data['socialLinks'] != null) 'socialLinks': _data['socialLinks'],
      };
      _data = await SchoolWebsiteService.updateWebsite(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Website updated! Visitors will see changes immediately.'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: GoogleFonts.poppins(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Save bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.cream,
          child: Row(
            children: [
              Icon(Icons.language, color: AppColors.navy, size: 20),
              const SizedBox(width: 8),
              Text('School Website Editor',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.navy)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 18),
                label: Text(_saving ? 'Saving...' : 'Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: AppColors.navy,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Identity & Contact'),
            Tab(text: 'About & Principal'),
            Tab(text: 'Stats & Achievements'),
            Tab(text: 'Events & Testimonials'),
            Tab(text: 'Fee Structure & Timeline'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildIdentityTab(),
              _buildAboutTab(),
              _buildStatsTab(),
              _buildEventsTab(),
              _buildFeeTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab 1: Identity & Contact ──
  Widget _buildIdentityTab() {
    return _scrollForm([
      _sectionHeader('School Identity'),
      _field('School Name', _schoolNameCtrl),
      _row([
        _field('Short Name (e.g. SIA)', _shortNameCtrl),
        _field('Accreditation', _accreditationCtrl),
      ]),
      _field('Tagline', _taglineCtrl),
      _field('Marquee Banner Text', _marqueeCtrl, maxLines: 2),
      const SizedBox(height: 16),
      _sectionHeader('Contact Information'),
      _row([
        _field('Phone', _phoneCtrl),
        _field('Email', _emailCtrl),
      ]),
      _field('Address', _addressCtrl),
      _field('Office Hours', _officeHoursCtrl, maxLines: 2),
      const SizedBox(height: 16),
      _sectionHeader('Theme Colors'),
      _row([
        _field('Primary Color (hex)', _primaryColorCtrl),
        _field('Secondary Color (hex)', _secondaryColorCtrl),
      ]),
    ]);
  }

  // ── Tab 2: About & Principal ──
  Widget _buildAboutTab() {
    return _scrollForm([
      _sectionHeader('Principal Information'),
      _row([
        _field('Principal Name', _principalNameCtrl),
        _field('Principal Title', _principalTitleCtrl),
      ]),
      _field('Principal Message', _principalMsgCtrl, maxLines: 6),
      const SizedBox(height: 16),
      _sectionHeader('Mission & Vision'),
      _field('Mission Statement', _missionCtrl, maxLines: 4),
      _field('Vision Statement', _visionCtrl, maxLines: 4),
    ]);
  }

  // ── Tab 3: Stats & Achievements ──
  Widget _buildStatsTab() {
    return _scrollForm([
      _sectionHeader('Quick Stats'),
      _dynamicList(
        ctrls: _statsCtrls,
        fields: ['value', 'label'],
        fieldLabels: ['Value (e.g. 500+)', 'Label (e.g. Students)'],
        onAdd: () => setState(() => _statsCtrls.add({
              'value': TextEditingController(),
              'label': TextEditingController(),
            })),
        onRemove: (i) => setState(() => _statsCtrls.removeAt(i)),
      ),
      const SizedBox(height: 16),
      _sectionHeader('Achievements'),
      _dynamicList(
        ctrls: _achievementsCtrls,
        fields: ['year', 'title'],
        fieldLabels: ['Year', 'Achievement Title'],
        onAdd: () => setState(() => _achievementsCtrls.add({
              'year': TextEditingController(),
              'title': TextEditingController(),
            })),
        onRemove: (i) => setState(() => _achievementsCtrls.removeAt(i)),
      ),
    ]);
  }

  // ── Tab 4: Events & Testimonials ──
  Widget _buildEventsTab() {
    return _scrollForm([
      _sectionHeader('Events'),
      _dynamicList(
        ctrls: _eventsCtrls,
        fields: ['date', 'title', 'description', 'category'],
        fieldLabels: ['Date', 'Title', 'Description', 'Category'],
        onAdd: () => setState(() => _eventsCtrls.add({
              'date': TextEditingController(),
              'title': TextEditingController(),
              'description': TextEditingController(),
              'category': TextEditingController(),
            })),
        onRemove: (i) => setState(() => _eventsCtrls.removeAt(i)),
      ),
      const SizedBox(height: 16),
      _sectionHeader('Testimonials'),
      _dynamicList(
        ctrls: _testimonialsCtrls,
        fields: ['name', 'relation', 'text'],
        fieldLabels: ['Name', 'Relation (e.g. Parent of X)', 'Testimonial Text'],
        onAdd: () => setState(() => _testimonialsCtrls.add({
              'name': TextEditingController(),
              'relation': TextEditingController(),
              'text': TextEditingController(),
            })),
        onRemove: (i) => setState(() => _testimonialsCtrls.removeAt(i)),
      ),
    ]);
  }

  // ── Tab 5: Fee Structure & Timeline ──
  Widget _buildFeeTab() {
    return _scrollForm([
      _sectionHeader('Fee Structure'),
      _dynamicList(
        ctrls: _feeStructureCtrls,
        fields: ['grade', 'admission', 'tuition', 'annual'],
        fieldLabels: ['Grade/Level', 'Admission Fee', 'Tuition', 'Annual Total'],
        onAdd: () => setState(() => _feeStructureCtrls.add({
              'grade': TextEditingController(),
              'admission': TextEditingController(),
              'tuition': TextEditingController(),
              'annual': TextEditingController(),
            })),
        onRemove: (i) => setState(() => _feeStructureCtrls.removeAt(i)),
      ),
      const SizedBox(height: 16),
      _sectionHeader('School History Timeline'),
      _dynamicList(
        ctrls: _timelineCtrls,
        fields: ['year', 'text'],
        fieldLabels: ['Year', 'Milestone Description'],
        onAdd: () => setState(() => _timelineCtrls.add({
              'year': TextEditingController(),
              'text': TextEditingController(),
            })),
        onRemove: (i) => setState(() => _timelineCtrls.removeAt(i)),
      ),
    ]);
  }

  // ── Shared builder helpers ──

  Widget _scrollForm(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Text(title,
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy)),
      );

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        style: GoogleFonts.poppins(fontSize: 13),
      ),
    );
  }

  Widget _row(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .map((c) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: c == children.last ? 0 : 12),
                    child: c,
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _dynamicList({
    required List<Map<String, TextEditingController>> ctrls,
    required List<String> fields,
    required List<String> fieldLabels,
    required VoidCallback onAdd,
    required void Function(int) onRemove,
  }) {
    return Column(
      children: [
        ...List.generate(ctrls.length, (i) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('#${i + 1}',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => onRemove(i),
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                  ...List.generate(fields.length, (fi) {
                    return _field(fieldLabels[fi], ctrls[i][fields[fi]]!);
                  }),
                ],
              ),
            ),
          );
        }),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Item'),
        ),
      ],
    );
  }
}
