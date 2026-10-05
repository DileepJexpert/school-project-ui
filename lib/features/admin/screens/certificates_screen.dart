import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../services/certificate_api_service.dart';
import '../../../services/certificate_print_service.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _certificates = [];

  static const _certificateTypes = [
    _CertificateType('TRANSFER', 'Transfer', Icons.swap_horiz_rounded,
        AppColors.info, 'Leaving and transfer documentation'),
    _CertificateType('BONAFIDE', 'Bonafide', Icons.verified_outlined,
        AppColors.success, 'Proof of student enrollment'),
    _CertificateType('CHARACTER', 'Character', Icons.workspace_premium_outlined,
        AppColors.warning, 'Conduct and character record'),
    _CertificateType('STUDY', 'Study', Icons.school_outlined, Color(0xFF7C3AED),
        'Study and academic confirmation'),
  ];

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  Future<void> _loadCertificates() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await CertificateApiService.getAllCertificates();
      if (!mounted) return;
      setState(() {
        _certificates =
            data.map((item) => item as Map<String, dynamic>).toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _searchQuery = '';
  String _selectedTypeFilter = 'ALL';

  List<Map<String, dynamic>> get _filteredCertificates {
    return _certificates.where((c) {
      final type = (c['certificateType'] as String? ?? '').toUpperCase();
      if (_selectedTypeFilter != 'ALL' && type != _selectedTypeFilter) {
        return false;
      }
      final name = (c['studentName'] as String? ?? '').toLowerCase();
      final serial = (c['serialNumber'] as String? ?? '').toLowerCase();
      final reason = (c['reason'] as String? ?? '').toLowerCase();
      final q = _searchQuery.trim().toLowerCase();
      if (q.isNotEmpty && !name.contains(q) && !serial.contains(q) && !reason.contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  int _countFor(String type) =>
      _certificates.where((c) => (c['certificateType'] as String? ?? '').toUpperCase() == type).length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCertificates;

    return AdminPageScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdminPageHeader(
          title: 'Certificates & Documents',
          subtitle:
              'Generate, verify, and print official CBSE transfer, bonafide, and conduct certificates.',
          icon: Icons.description_outlined,
          actions: [
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadCertificates,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Refresh'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _showGenerateDialog(),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Generate Certificate'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _typeGrid(),
        const SizedBox(height: 18),

        // Search & Filter bar
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by student name, certificate no, or purpose…',
                  hintStyle: GoogleFonts.nunitoSans(color: AppColors.textLight, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textLight),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Type filter chips
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip('ALL', 'All (${_certificates.length})'),
              const SizedBox(width: 6),
              _filterChip('TRANSFER', 'Transfer TC (${_countFor('TRANSFER')})'),
              const SizedBox(width: 6),
              _filterChip('BONAFIDE', 'Bonafide (${_countFor('BONAFIDE')})'),
              const SizedBox(width: 6),
              _filterChip('CHARACTER', 'Character (${_countFor('CHARACTER')})'),
              const SizedBox(width: 6),
              _filterChip('STUDY', 'Study (${_countFor('STUDY')})'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(
            child: Text(
              'Issued Certificates',
              style: GoogleFonts.nunitoSans(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '${filtered.length} matching',
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        if (_loading)
          const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _errorState()
        else if (filtered.isEmpty)
          _emptyState()
        else
          Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
                  Divider(color: context.palette.border, height: 1),
              itemBuilder: (_, index) => _certificateTile(filtered[index]),
            ),
          ),
      ]),
    );
  }

  Widget _filterChip(String code, String label) {
    final active = _selectedTypeFilter == code;
    return GestureDetector(
      onTap: () => setState(() => _selectedTypeFilter = code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? AppColors.navy : AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunitoSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _typeGrid() {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 960
          ? 4
          : constraints.maxWidth > 620
              ? 2
              : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _certificateTypes
            .map((type) => SizedBox(width: width, child: _typeCard(type)))
            .toList(),
      );
    });
  }

  Widget _typeCard(_CertificateType type) {
    return Card(
      child: InkWell(
        onTap: () => _showGenerateDialog(preselectedType: type.code),
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: type.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              ),
              child: Icon(type.icon, color: type.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      type.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ]),
            ),
            Icon(Icons.chevron_right_rounded, color: context.palette.brand),
          ]),
        ),
      ),
    );
  }

  Widget _certificateTile(Map<String, dynamic> certificate) {
    final type = certificate['certificateType'] as String? ?? 'CERTIFICATE';
    final studentName = certificate['studentName'] as String? ?? 'Student';
    final serial = certificate['serialNumber'] as String? ?? '';
    final generatedAt = certificate['generatedAt'] as String? ?? '';
    final reason = certificate['reason'] as String? ?? '';
    final typeInfo = _certificateTypes.firstWhere(
      (item) => item.code == type,
      orElse: () => _certificateTypes.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: typeInfo.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(typeInfo.icon, color: typeInfo.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      studentName,
                      style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeInfo.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        typeInfo.label,
                        style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          color: typeInfo.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (serial.isNotEmpty) 'Serial: $serial',
                    if (reason.isNotEmpty) 'Purpose: $reason',
                    if (generatedAt.isNotEmpty) generatedAt,
                  ].join(' · '),
                  style: GoogleFonts.nunitoSans(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.print_outlined, size: 16),
            label: Text('Print', style: GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.w700)),
            onPressed: () {
              CertificatePrintService.printCertificate(certificate: certificate);
            },
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.description_outlined,
                size: 52, color: AppColors.textLight.withValues(alpha: 0.55)),
            const SizedBox(height: 12),
            Text(
              'No certificates generated yet',
              style: GoogleFonts.nunitoSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Generate a certificate from one of the certificate types above.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _errorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              'Could not load certificates',
              style: GoogleFonts.nunitoSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCertificates,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Retry'),
            ),
          ]),
        ),
      ),
    );
  }

  void _showGenerateDialog({String? preselectedType}) {
    final studentIdCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String certType = preselectedType ?? _certificateTypes.first.code;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'Generate Certificate',
            style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: studentIdCtrl,
                decoration: const InputDecoration(labelText: 'Student ID *'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: certType,
                decoration:
                    const InputDecoration(labelText: 'Certificate Type'),
                items: _certificateTypes
                    .map((type) => DropdownMenuItem(
                          value: type.code,
                          child: Text(type.label),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => certType = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason'),
                maxLines: 2,
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (studentIdCtrl.text.trim().isEmpty) {
                  _snack('Student ID is required.', isError: true);
                  return;
                }
                try {
                  await CertificateApiService.generateCertificate({
                    'studentId': studentIdCtrl.text.trim(),
                    'certificateType': certType,
                    'reason': reasonCtrl.text.trim(),
                  });
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _snack('Certificate generated.');
                  _loadCertificates();
                } catch (e) {
                  _snack('Failed to generate certificate: $e', isError: true);
                }
              },
              child: const Text('Generate'),
            ),
          ],
        ),
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
}

class _CertificateType {
  final String code;
  final String label;
  final IconData icon;
  final Color color;
  final String description;

  const _CertificateType(
    this.code,
    this.label,
    this.icon,
    this.color,
    this.description,
  );
}
