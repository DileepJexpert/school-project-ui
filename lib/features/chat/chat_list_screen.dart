import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/responsive.dart';
import '../../services/auth_service.dart';
import '../../services/chat_api_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rooms = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _loadRooms();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visible {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _rooms.where((room) {
      final searchable = [
        _otherName(room),
        _text(room, 'studentName'),
        _text(room, 'lastMessage'),
      ].join(' ').toLowerCase();
      return query.isEmpty || searchable.contains(query);
    }).toList();
  }

  int get _unreadCount {
    final userId = AuthService.instance.currentUser?.userId ?? '';
    return _rooms.fold<int>(0, (sum, room) {
      final counts = _map(room['unreadCounts']);
      final unread = counts[userId];
      return sum + (unread is num ? unread.toInt() : 0);
    });
  }

  Future<void> _loadRooms() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = AuthService.instance.currentUser?.userId ?? '';
      final data = await ChatApiService.getMyRooms(userId);
      if (!mounted) return;
      setState(() {
        _rooms = data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showNewChatDialog() async {
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
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
                child: Icon(Icons.chat_outlined, color: context.palette.brand),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Start a conversation',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 560,
            height: 460,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadContacts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _InlineState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load contacts',
                    subtitle: snapshot.error.toString(),
                  );
                }
                final contacts = snapshot.data ?? [];
                if (contacts.isEmpty) {
                  return const _InlineState(
                    icon: Icons.person_search_outlined,
                    title: 'No contacts available',
                    subtitle: 'Users will appear here after they are created.',
                  );
                }
                return _ContactPicker(
                  contacts: contacts,
                  onSelect: (contact) => Navigator.pop(ctx, contact),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selected != null) await _startChat(selected);
  }

  Future<List<Map<String, dynamic>>> _loadContacts() async {
    final currentUserId = AuthService.instance.currentUser?.userId ?? '';
    final data = await ChatApiService.getContacts();
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((user) => _text(user, 'id') != currentUserId)
        .toList()
      ..sort((a, b) => _text(a, 'fullName').compareTo(_text(b, 'fullName')));
  }

  Future<void> _startChat(Map<String, dynamic> contact) async {
    final user = AuthService.instance.currentUser;
    final myId = user?.userId ?? '';
    final myName = user?.fullName ?? '';
    final myRole = user?.role ?? '';
    final otherId = _text(contact, 'id');
    final otherName = _text(contact, 'fullName').isEmpty
        ? 'Unknown'
        : _text(contact, 'fullName');
    final otherRole = _text(contact, 'role');

    try {
      final room = await ChatApiService.getOrCreateRoom(
        userId1: myId,
        userId2: otherId,
        studentId: '',
        names: {myId: myName, otherId: otherName},
        roles: {myId: myRole, otherId: otherRole},
      );
      final roomId = _text(room, 'id');
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(roomId: roomId, otherName: otherName),
        ),
      );
      _loadRooms();
    } catch (e) {
      _snack('Could not start chat: $e', isError: true);
    }
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
                'Chat',
                style: GoogleFonts.nunitoSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'School conversations with staff, parents and linked students.',
                style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _loading ? null : _loadRooms,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _showNewChatDialog,
          icon: const Icon(Icons.add_comment_outlined, size: 18),
          label: const Text('New chat'),
        ),
      ],
    );
  }

  Widget _buildMetrics() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final width = compact
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 20) / 3;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricCard(
              width: width,
              label: 'Conversations',
              value: _rooms.length.toString(),
              icon: Icons.forum_outlined,
              color: context.palette.brand,
            ),
            _MetricCard(
              width: width,
              label: 'Unread',
              value: _unreadCount.toString(),
              icon: Icons.mark_chat_unread_outlined,
              color: AppColors.warning,
            ),
            _MetricCard(
              width: width,
              label: 'Visible now',
              value: _visible.length.toString(),
              icon: Icons.filter_alt_outlined,
              color: AppColors.info,
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _searchCtrl.clear,
              icon: const Icon(Icons.close_rounded, size: 17),
              label: const Text('Clear'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _StateCard(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load chats',
        subtitle: _error!,
        actionLabel: 'Retry',
        onAction: _loadRooms,
      );
    }

    final visible = _visible;
    if (visible.isEmpty) {
      return _StateCard(
        icon: Icons.chat_bubble_outline,
        title: 'No conversations found',
        subtitle: 'Start a new chat or change the search text.',
        actionLabel: 'New chat',
        onAction: _showNewChatDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRooms,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final room = visible[index];
          return _RoomRow(
            room: room,
            otherName: _otherName(room),
            unread: _roomUnread(room),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    roomId: _text(room, 'id'),
                    otherName: _otherName(room),
                  ),
                ),
              );
              _loadRooms();
            },
          );
        },
      ),
    );
  }

  String _otherName(Map<String, dynamic> room) {
    final userId = AuthService.instance.currentUser?.userId ?? '';
    final participantNames = _map(room['participantNames']);
    for (final entry in participantNames.entries) {
      if (entry.key != userId) return entry.value?.toString() ?? 'Unknown';
    }
    return 'Unknown';
  }

  int _roomUnread(Map<String, dynamic> room) {
    final userId = AuthService.instance.currentUser?.userId ?? '';
    final unread = _map(room['unreadCounts'])[userId];
    return unread is num ? unread.toInt() : 0;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static String _text(Map<String, dynamic> item, String key) {
    final value = item[key];
    return value == null ? '' : value.toString();
  }
}

class _RoomRow extends StatelessWidget {
  final Map<String, dynamic> room;
  final String otherName;
  final int unread;
  final VoidCallback onTap;

  const _RoomRow({
    required this.room,
    required this.otherName,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lastMessage = _text('lastMessage');
    final studentName = _text('studentName');
    final initial = otherName.isNotEmpty ? otherName[0].toUpperCase() : '?';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border.all(
            color: unread > 0
                ? context.palette.brand.withValues(alpha: 0.32)
                : context.palette.border,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: context.palette.brand.withValues(alpha: 0.1),
              child: Text(
                initial,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunitoSans(
                            fontSize: 15,
                            fontWeight:
                                unread > 0 ? FontWeight.w900 : FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: context.palette.brand,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            unread.toString(),
                            style: GoogleFonts.nunitoSans(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (studentName.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Regarding $studentName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: context.palette.accent,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  String _text(String key) {
    final value = room[key];
    return value == null ? '' : value.toString();
  }
}

class _ContactPicker extends StatefulWidget {
  final List<Map<String, dynamic>> contacts;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _ContactPicker({required this.contacts, required this.onSelect});

  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return widget.contacts;
    return widget.contacts.where((contact) {
      final searchable = [
        _text(contact, 'fullName'),
        _text(contact, 'email'),
        _text(contact, 'role'),
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _filtered;

    return Column(
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Search name, email, role...',
            prefixIcon: Icon(Icons.search_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: contacts.isEmpty
              ? const _InlineState(
                  icon: Icons.person_search_outlined,
                  title: 'No matching contacts',
                  subtitle: 'Try a different name or role.',
                )
              : ListView.separated(
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final name = _text(contact, 'fullName').isEmpty
                        ? 'Unknown'
                        : _text(contact, 'fullName');
                    final email = _text(contact, 'email');
                    final role = _prettyRole(_text(contact, 'role'));
                    return InkWell(
                      onTap: () => widget.onSelect(contact),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.palette.canvas,
                          border: Border.all(color: context.palette.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  context.palette.brand.withValues(alpha: 0.1),
                              child: Text(
                                name[0].toUpperCase(),
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
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.nunitoSans(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    [role, email]
                                        .where((item) => item.isNotEmpty)
                                        .join(' | '),
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
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static String _text(Map<String, dynamic> item, String key) {
    final value = item[key];
    return value == null ? '' : value.toString();
  }

  static String _prettyRole(String role) {
    return role.replaceAll('ROLE_', '').replaceAll('_', ' ');
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

class _InlineState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InlineState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: AppColors.textLight),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
