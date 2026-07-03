import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../models/notification_model.dart';
import '../../../services/notification_api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _searchCtrl = TextEditingController();
  final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

  List<NotificationModel> _all = [];
  bool _loading = true;
  String? _error;
  String _typeFilter = 'ALL';
  String _priorityFilter = 'ALL';
  bool _unreadOnly = false;

  static const _typeOptions = [
    'ALL',
    'GENERAL',
    'FEE_REMINDER',
    'EXAM',
    'EVENT',
    'HOLIDAY',
    'EMERGENCY',
  ];

  static const _priorityOptions = ['ALL', 'LOW', 'MEDIUM', 'HIGH'];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _loadNotifications();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<NotificationModel> get _visible {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _all.where((item) {
      final matchesType = _typeFilter == 'ALL' || item.type == _typeFilter;
      final matchesPriority =
          _priorityFilter == 'ALL' || item.priority == _priorityFilter;
      final matchesRead = !_unreadOnly || !item.read;
      final searchable = [
        item.title,
        item.message,
        item.type,
        item.priority,
        item.targetAudience,
        item.targetClass ?? '',
      ].join(' ').toLowerCase();
      return matchesType &&
          matchesPriority &&
          matchesRead &&
          (query.isEmpty || searchable.contains(query));
    }).toList();

    filtered.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    return filtered;
  }

  int get _unreadCount => _all.where((n) => !n.read).length;
  int get _highPriorityCount => _all.where((n) => n.priority == 'HIGH').length;
  int get _emergencyCount => _all.where((n) => n.type == 'EMERGENCY').length;

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await NotificationApiService.getAllNotifications();
      if (!mounted) return;
      setState(() => _all = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    final id = notification.id;
    if (id == null || id.isEmpty) return;

    try {
      final updated = await NotificationApiService.markAsRead(id);
      if (!mounted) return;
      setState(() {
        final index = _all.indexWhere((item) => item.id == id);
        if (index != -1) _all[index] = updated;
      });
    } catch (e) {
      _snack('Could not mark as read: $e', isError: true);
    }
  }

  Future<void> _delete(NotificationModel notification) async {
    final id = notification.id;
    if (id == null || id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete notification'),
        content: Text('Delete "${notification.title}"?'),
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

    if (confirmed != true) return;

    try {
      await NotificationApiService.deleteNotification(id);
      if (!mounted) return;
      setState(() => _all.removeWhere((item) => item.id == id));
      _snack('Notification deleted.');
    } catch (e) {
      _snack('Could not delete notification: $e', isError: true);
    }
  }

  void _openCreateDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ComposeNotificationDialog(
        onCreated: (notification) {
          Navigator.pop(ctx);
          setState(() => _all.insert(0, notification));
          _snack('Notification created.');
        },
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
          _buildToolbar(),
          const SizedBox(height: 12),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications',
                style: GoogleFonts.nunitoSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Send notices, reminders, alerts, and class-specific updates.',
                style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _loading ? null : _loadNotifications,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _openCreateDialog,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Compose'),
        ),
      ],
    );
  }

  Widget _buildMetrics() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 780;
        final itemWidth = compact ? (width - 10) / 2 : (width - 30) / 4;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricCard(
              width: itemWidth,
              label: 'Total sent',
              value: _all.length.toString(),
              icon: Icons.campaign_outlined,
              color: context.palette.brand,
            ),
            _MetricCard(
              width: itemWidth,
              label: 'Unread',
              value: _unreadCount.toString(),
              icon: Icons.mark_email_unread_outlined,
              color: AppColors.info,
            ),
            _MetricCard(
              width: itemWidth,
              label: 'High priority',
              value: _highPriorityCount.toString(),
              icon: Icons.priority_high_rounded,
              color: AppColors.warning,
            ),
            _MetricCard(
              width: itemWidth,
              label: 'Emergency',
              value: _emergencyCount.toString(),
              icon: Icons.crisis_alert_outlined,
              color: AppColors.error,
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar() {
    final dropdownTextStyle = GoogleFonts.nunitoSans(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final search = SizedBox(
            width: compact ? constraints.maxWidth : 360,
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search title, message, type...',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
          );

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              search,
              SizedBox(
                width: compact ? (constraints.maxWidth - 10) / 2 : 176,
                child: DropdownButtonFormField<String>(
                  initialValue: _typeFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  style: dropdownTextStyle,
                  items: _typeOptions
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(_pretty(type)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(
                    () => _typeFilter = value ?? 'ALL',
                  ),
                ),
              ),
              SizedBox(
                width: compact ? (constraints.maxWidth - 10) / 2 : 160,
                child: DropdownButtonFormField<String>(
                  initialValue: _priorityFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  style: dropdownTextStyle,
                  items: _priorityOptions
                      .map(
                        (priority) => DropdownMenuItem(
                          value: priority,
                          child: Text(_pretty(priority)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(
                    () => _priorityFilter = value ?? 'ALL',
                  ),
                ),
              ),
              FilterChip(
                selected: _unreadOnly,
                label: const Text('Unread only'),
                avatar: Icon(
                  _unreadOnly
                      ? Icons.mark_email_unread_rounded
                      : Icons.mark_email_read_outlined,
                  size: 17,
                ),
                onSelected: (selected) =>
                    setState(() => _unreadOnly = selected),
              ),
              if (_searchCtrl.text.isNotEmpty ||
                  _typeFilter != 'ALL' ||
                  _priorityFilter != 'ALL' ||
                  _unreadOnly)
                TextButton.icon(
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _typeFilter = 'ALL';
                      _priorityFilter = 'ALL';
                      _unreadOnly = false;
                    });
                  },
                  icon: const Icon(Icons.close_rounded, size: 17),
                  label: const Text('Clear'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _StateCard(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load notifications',
        subtitle: _error!,
        actionLabel: 'Retry',
        onAction: _loadNotifications,
      );
    }

    final visible = _visible;
    if (visible.isEmpty) {
      return _StateCard(
        icon: Icons.notifications_none_rounded,
        title: 'No notifications found',
        subtitle: 'Try another filter or compose a new notice.',
        actionLabel: 'Compose',
        onAction: _openCreateDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final notification = visible[index];
          return _NotificationRow(
            notification: notification,
            createdLabel: _formatDate(notification.createdAt),
            expiresLabel: _formatDate(notification.expiresAt),
            onMarkRead:
                notification.read ? null : () => _markAsRead(notification),
            onDelete: () => _delete(notification),
          );
        },
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'Not set';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return _dateTimeFmt.format(parsed.toLocal());
  }

  static String _pretty(String value) {
    if (value == 'ALL') return 'All';
    return value
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0]}${part.substring(1).toLowerCase()}')
        .join(' ');
  }
}

class _NotificationRow extends StatelessWidget {
  final NotificationModel notification;
  final String createdLabel;
  final String expiresLabel;
  final VoidCallback? onMarkRead;
  final VoidCallback onDelete;

  const _NotificationRow({
    required this.notification,
    required this.createdLabel,
    required this.expiresLabel,
    required this.onMarkRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(notification.type);
    final priorityColor = _priorityColor(notification.priority);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: notification.read
              ? context.palette.border
              : context.palette.brand.withValues(alpha: 0.32),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_typeIcon(notification.type), color: color, size: 22),
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
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunitoSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (!notification.read)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.palette.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MiniChip(
                      label: _pretty(notification.type),
                      color: color,
                    ),
                    _MiniChip(
                      label: _pretty(notification.priority),
                      color: priorityColor,
                    ),
                    _MiniChip(
                      label: notification.targetClass?.isNotEmpty == true
                          ? notification.targetClass!
                          : _pretty(notification.targetAudience),
                      color: context.palette.brand,
                    ),
                    _MiniChip(
                      label: 'Created $createdLabel',
                      color: AppColors.textSecondary,
                    ),
                    if (notification.expiresAt?.isNotEmpty == true)
                      _MiniChip(
                        label: 'Expires $expiresLabel',
                        color: AppColors.warning,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (value) {
              if (value == 'read') onMarkRead?.call();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              if (onMarkRead != null)
                const PopupMenuItem(
                  value: 'read',
                  child: Text('Mark as read'),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _typeColor(String type) {
    return switch (type) {
      'EMERGENCY' => AppColors.error,
      'FEE_REMINDER' => AppColors.warning,
      'EXAM' => AppColors.info,
      'EVENT' => AppColors.success,
      'HOLIDAY' => const Color(0xFF7C3AED),
      _ => AppColors.navy,
    };
  }

  static IconData _typeIcon(String type) {
    return switch (type) {
      'EMERGENCY' => Icons.crisis_alert_outlined,
      'FEE_REMINDER' => Icons.payments_outlined,
      'EXAM' => Icons.assignment_outlined,
      'EVENT' => Icons.event_available_outlined,
      'HOLIDAY' => Icons.beach_access_outlined,
      _ => Icons.campaign_outlined,
    };
  }

  static Color _priorityColor(String priority) {
    return switch (priority) {
      'HIGH' => AppColors.error,
      'LOW' => AppColors.success,
      _ => AppColors.warning,
    };
  }

  static String _pretty(String value) {
    return value
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0]}${part.substring(1).toLowerCase()}')
        .join(' ');
  }
}

class _ComposeNotificationDialog extends StatefulWidget {
  final ValueChanged<NotificationModel> onCreated;

  const _ComposeNotificationDialog({required this.onCreated});

  @override
  State<_ComposeNotificationDialog> createState() =>
      _ComposeNotificationDialogState();
}

class _ComposeNotificationDialogState
    extends State<_ComposeNotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _createdByCtrl = TextEditingController(text: 'Admin');
  final _targetClassCtrl = TextEditingController();
  final _targetStudentCtrl = TextEditingController();

  String _type = 'GENERAL';
  String _priority = 'MEDIUM';
  String _audience = 'ALL';
  DateTime? _expiresAt;
  bool _saving = false;

  static const _types = [
    'GENERAL',
    'FEE_REMINDER',
    'EXAM',
    'EVENT',
    'HOLIDAY',
    'EMERGENCY',
  ];

  static const _priorities = ['LOW', 'MEDIUM', 'HIGH'];
  static const _audiences = ['ALL', 'CLASS_SPECIFIC', 'INDIVIDUAL'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _createdByCtrl.dispose();
    _targetClassCtrl.dispose();
    _targetStudentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: context.palette.brand,
                surface: context.palette.surface,
              ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
            child: child!,
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _expiresAt = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final notification = NotificationModel(
        title: _titleCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
        type: _type,
        targetAudience: _audience,
        priority: _priority,
        targetClass:
            _audience == 'CLASS_SPECIFIC' ? _targetClassCtrl.text.trim() : null,
        targetStudentId:
            _audience == 'INDIVIDUAL' ? _targetStudentCtrl.text.trim() : null,
        createdBy: _createdByCtrl.text.trim().isEmpty
            ? 'Admin'
            : _createdByCtrl.text.trim(),
        expiresAt: _expiresAt == null ? null : _apiDate(_expiresAt!),
      );

      final created =
          await NotificationApiService.createNotification(notification);
      if (!mounted) return;
      widget.onCreated(created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create notification: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      actionsPadding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.palette.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.campaign_outlined, color: context.palette.brand),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Compose notification',
              style: GoogleFonts.nunitoSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title_rounded, size: 19),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a title'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _messageCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a message'
                      : null,
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 540;
                    final fieldWidth = compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: _dropdown(
                            label: 'Type',
                            value: _type,
                            items: _types,
                            onChanged: (value) =>
                                setState(() => _type = value ?? _type),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _dropdown(
                            label: 'Priority',
                            value: _priority,
                            items: _priorities,
                            onChanged: (value) => setState(
                              () => _priority = value ?? _priority,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _dropdown(
                            label: 'Audience',
                            value: _audience,
                            items: _audiences,
                            onChanged: (value) => setState(
                              () => _audience = value ?? _audience,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: TextFormField(
                            controller: _createdByCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Created by'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (_audience == 'CLASS_SPECIFIC') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _targetClassCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Target class',
                      hintText: 'Example: Class 7 - A',
                    ),
                    validator: (value) {
                      if (_audience != 'CLASS_SPECIFIC') return null;
                      return value == null || value.trim().isEmpty
                          ? 'Enter target class'
                          : null;
                    },
                  ),
                ],
                if (_audience == 'INDIVIDUAL') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _targetStudentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Student ID',
                    ),
                    validator: (value) {
                      if (_audience != 'INDIVIDUAL') return null;
                      return value == null || value.trim().isEmpty
                          ? 'Enter student ID'
                          : null;
                    },
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.palette.canvas,
                    border: Border.all(color: context.palette.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_busy_outlined, size: 19),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _expiresAt == null
                              ? 'No expiry date'
                              : 'Expires on ${DateFormat('dd MMM yyyy').format(_expiresAt!)}',
                          style: GoogleFonts.nunitoSans(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _pickExpiry,
                        child: const Text('Set date'),
                      ),
                      if (_expiresAt != null)
                        IconButton(
                          tooltip: 'Clear expiry',
                          onPressed: () => setState(() => _expiresAt = null),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(_saving ? 'Sending...' : 'Send notification'),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(_pretty(item)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  static String _pretty(String value) {
    return value
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0]}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  static String _apiDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _MetricCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border.all(color: context.palette.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
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
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunitoSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
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
                fontWeight: FontWeight.w800,
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
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
