import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/notification_model.dart';
import '../../../services/notification_api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _all = [];
  List<NotificationModel> _filtered = [];
  bool _loading = true;
  String? _error;
  String _typeFilter = 'ALL';

  static const _typeOptions = [
    'ALL',
    'GENERAL',
    'FEE_REMINDER',
    'EXAM',
    'EVENT',
    'HOLIDAY',
    'EMERGENCY',
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await NotificationApiService.getAllNotifications();
      setState(() {
        _all = list;
        _applyFilter();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    if (_typeFilter == 'ALL') {
      _filtered = List.from(_all);
    } else {
      _filtered = _all.where((n) => n.type == _typeFilter).toList();
    }
  }

  Future<void> _markAsRead(NotificationModel n) async {
    try {
      final updated = await NotificationApiService.markAsRead(n.id!);
      setState(() {
        final idx = _all.indexWhere((x) => x.id == n.id);
        if (idx != -1) _all[idx] = updated;
        _applyFilter();
      });
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await NotificationApiService.deleteNotification(id);
      setState(() {
        _all.removeWhere((n) => n.id == id);
        _applyFilter();
      });
      _showSnack('Notification deleted.');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunitoSans()),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  void _openCreateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateNotificationDialog(
        onCreated: (n) {
          Navigator.pop(_);
          setState(() {
            _all.insert(0, n);
            _applyFilter();
          });
          _showSnack('Notification created!');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildTypeFilter(),
          const SizedBox(height: 16),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Notifications',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          Text(
            _loading
                ? 'Loading…'
                : '${_filtered.length} notification(s)',
            style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary, fontSize: 13),
          ),
        ]),
      ),
      OutlinedButton.icon(
        onPressed: _loadNotifications,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Refresh'),
        style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.navy,
            side: const BorderSide(color: AppColors.navy)),
      ),
      const SizedBox(width: 10),
      ElevatedButton.icon(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('New'),
        style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white),
      ),
    ]);
  }

  Widget _buildTypeFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _typeOptions.map((t) {
          final isActive = _typeFilter == t;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(t.replaceAll('_', ' ')),
              selected: isActive,
              onSelected: (_) {
                setState(() {
                  _typeFilter = t;
                  _applyFilter();
                });
              },
              selectedColor: AppColors.navy.withOpacity(0.15),
              checkmarkColor: AppColors.navy,
              labelStyle: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive
                      ? AppColors.navy
                      : AppColors.textSecondary),
              side: BorderSide(
                  color: isActive ? AppColors.navy : AppColors.border),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildShimmer();
    if (_error != null) return _buildError();
    if (_filtered.isEmpty) return _buildEmpty();
    return ListView.separated(
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _NotificationCard(
        notification: _filtered[i],
        onMarkRead: _filtered[i].read
            ? null
            : () => _markAsRead(_filtered[i]),
        onDelete: () => _delete(_filtered[i].id!),
      ),
    );
  }

  Widget _buildShimmer() => Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        child: ListView.builder(
          itemCount: 5,
          itemBuilder: (_, __) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 90,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
          ),
        ),
      );

  Widget _buildError() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off_rounded,
              color: AppColors.error, size: 52),
          const SizedBox(height: 12),
          Text('Could not load notifications',
              style: GoogleFonts.nunitoSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error)),
          const SizedBox(height: 6),
          Text(_error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _loadNotifications, child: const Text('Retry')),
        ]),
      );

  Widget _buildEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.notifications_none_rounded,
              size: 60, color: AppColors.textLight.withOpacity(0.4)),
          const SizedBox(height: 14),
          Text('No notifications',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 6),
          Text('Tap "New" to create the first notification.',
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openCreateDialog,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Create Notification'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white),
          ),
        ]),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// Notification Card
// ──────────────────────────────────────────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onMarkRead;
  final VoidCallback onDelete;

  const _NotificationCard({
    required this.notification,
    required this.onMarkRead,
    required this.onDelete,
  });

  static const _typeColors = {
    'GENERAL': Color(0xFF3B82F6),
    'FEE_REMINDER': Color(0xFFDB2777),
    'EXAM': Color(0xFF7C3AED),
    'EVENT': Color(0xFF059669),
    'HOLIDAY': Color(0xFFF59E0B),
    'EMERGENCY': Color(0xFFDC2626),
  };

  static const _priorityColors = {
    'HIGH': AppColors.error,
    'MEDIUM': AppColors.warning,
    'LOW': AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final typeColor =
        _typeColors[notification.type] ?? AppColors.textSecondary;
    final priorityColor =
        _priorityColors[notification.priority] ?? AppColors.textSecondary;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                  notification.type.replaceAll('_', ' '),
                  style: GoogleFonts.nunitoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: typeColor)),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(notification.priority,
                  style: GoogleFonts.nunitoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: priorityColor)),
            ),
            if (notification.read)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.check_circle_rounded,
                    size: 16, color: AppColors.success.withOpacity(0.7)),
              ),
            const Spacer(),
            if (notification.createdAt != null)
              Text(
                  _formatDate(notification.createdAt!),
                  style: GoogleFonts.nunitoSans(
                      fontSize: 11, color: AppColors.textLight)),
          ]),
          const SizedBox(height: 8),
          Text(notification.title,
              style: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(notification.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary, fontSize: 13)),
          if (notification.targetClass != null ||
              notification.targetStudentId != null) ...[
            const SizedBox(height: 6),
            Text(
              notification.targetClass != null
                  ? 'Class: ${notification.targetClass}'
                  : 'Student: ${notification.targetStudentId}',
              style: GoogleFonts.nunitoSans(
                  fontSize: 11, color: AppColors.textLight),
            ),
          ],
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (onMarkRead != null)
              TextButton.icon(
                onPressed: onMarkRead,
                icon: const Icon(Icons.done_rounded, size: 14),
                label: const Text('Mark Read'),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.success,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10)),
              ),
            TextButton.icon(
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline_rounded, size: 14),
              label: const Text('Delete'),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10)),
            ),
          ]),
        ]),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Notification'),
        content:
            const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(_);
              onDelete();
            },
            child: Text('Delete',
                style: GoogleFonts.nunitoSans(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Create Notification Dialog
// ──────────────────────────────────────────────────────────────────────────────
class _CreateNotificationDialog extends StatefulWidget {
  final ValueChanged<NotificationModel> onCreated;

  const _CreateNotificationDialog({required this.onCreated});

  @override
  State<_CreateNotificationDialog> createState() =>
      _CreateNotificationDialogState();
}

class _CreateNotificationDialogState
    extends State<_CreateNotificationDialog> {
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _createdByCtrl = TextEditingController(text: 'Admin');
  final _targetClassCtrl = TextEditingController();

  String _type = 'GENERAL';
  String _audience = 'ALL';
  String _priority = 'MEDIUM';
  bool _saving = false;

  static const _types = [
    'GENERAL',
    'FEE_REMINDER',
    'EXAM',
    'EVENT',
    'HOLIDAY',
    'EMERGENCY'
  ];
  static const _audiences = ['ALL', 'CLASS_SPECIFIC', 'INDIVIDUAL'];
  static const _priorities = ['LOW', 'MEDIUM', 'HIGH'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _createdByCtrl.dispose();
    _targetClassCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty ||
        _messageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Title and message are required.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      final n = NotificationModel(
        title: _titleCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
        type: _type,
        targetAudience: _audience,
        targetClass: _audience == 'CLASS_SPECIFIC'
            ? _targetClassCtrl.text.trim()
            : null,
        priority: _priority,
        createdBy: _createdByCtrl.text.trim(),
      );
      final created = await NotificationApiService.createNotification(n);
      widget.onCreated(created);
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
      title: Text('Create Notification',
          style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.navy)),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_titleCtrl, 'Title *'),
              const SizedBox(height: 12),
              _field(_messageCtrl, 'Message *', maxLines: 3),
              const SizedBox(height: 12),
              _dropdown('Type', _types, _type, (v) => setState(() => _type = v!)),
              const SizedBox(height: 12),
              _dropdown('Target Audience', _audiences, _audience,
                  (v) => setState(() => _audience = v!)),
              if (_audience == 'CLASS_SPECIFIC') ...[
                const SizedBox(height: 12),
                _field(_targetClassCtrl, 'Target Class e.g. Class-5A'),
              ],
              const SizedBox(height: 12),
              _dropdown('Priority', _priorities, _priority,
                  (v) => setState(() => _priority = v!)),
              const SizedBox(height: 12),
              _field(_createdByCtrl, 'Created By'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _create,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Create'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunitoSans(
            color: AppColors.textSecondary, fontSize: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          borderSide: const BorderSide(color: AppColors.navy, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _dropdown(String label, List<String> items, String value,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((i) => DropdownMenuItem(
              value: i,
              child: Text(i.replaceAll('_', ' '),
                  style: GoogleFonts.nunitoSans(fontSize: 13))))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunitoSans(
            color: AppColors.textSecondary, fontSize: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMD),
          borderSide: const BorderSide(color: AppColors.navy, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
