import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../services/chat_api_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _loading = true;
  List<dynamic> _rooms = [];

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _loading = true);
    try {
      final userId = AuthService.instance.currentUser?.userId ?? '';
      final data = await ChatApiService.getMyRooms(userId);
      if (mounted) setState(() => _rooms = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load chats: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showNewChatDialog() async {
    List<dynamic> contacts = [];
    bool loadingContacts = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (loadingContacts) {
              ChatApiService.getContacts().then((data) {
                final currentUserId =
                    AuthService.instance.currentUser?.userId ?? '';
                // Filter out current user
                final filtered = data
                    .where((u) =>
                        (u['id'] as String? ?? '') != currentUserId)
                    .toList();
                setDialogState(() {
                  contacts = filtered;
                  loadingContacts = false;
                });
              }).catchError((e) {
                setDialogState(() {
                  loadingContacts = false;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to load contacts: $e')),
                );
              });
              // Prevent re-calling on rebuild
              loadingContacts = false;
              return AlertDialog(
                title: Text('New Chat',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                content: const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator())),
              );
            }

            return AlertDialog(
              title: Text('New Chat',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: contacts.isEmpty
                    ? Center(
                        child: Text('No contacts available.',
                            style: GoogleFonts.poppins(
                                color: AppColors.textSecondary)))
                    : _ContactList(
                        contacts: contacts,
                        onSelect: (contact) {
                          Navigator.pop(ctx);
                          _startChat(contact);
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
      },
    );
  }

  Future<void> _startChat(Map<String, dynamic> contact) async {
    final user = AuthService.instance.currentUser;
    final myId = user?.userId ?? '';
    final myName = user?.fullName ?? '';
    final myRole = user?.role ?? '';
    final otherId = contact['id'] as String? ?? '';
    final otherName = contact['fullName'] as String? ?? 'Unknown';
    final otherRole = contact['role'] as String? ?? '';

    try {
      final room = await ChatApiService.getOrCreateRoom(
        userId1: myId,
        userId2: otherId,
        studentId: '',
        names: {myId: myName, otherId: otherName},
        roles: {myId: myRole, otherId: otherRole},
      );
      final roomId = room['id'] as String? ?? '';
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(roomId: roomId, otherName: otherName),
        ));
        // Refresh rooms list when coming back
        _loadRooms();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Messages',
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
            ),
            Expanded(
              child: _rooms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('No conversations yet.',
                              style: GoogleFonts.poppins(
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          Text('Tap + to start a new chat.',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRooms,
                      child: ListView.separated(
                        itemCount: _rooms.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final room =
                              _rooms[index] as Map<String, dynamic>;
                          return _buildRoomTile(room);
                        },
                      ),
                    ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            backgroundColor: AppColors.navy,
            onPressed: _showNewChatDialog,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomTile(Map<String, dynamic> room) {
    final userId = AuthService.instance.currentUser?.userId ?? '';
    final participantNames =
        (room['participantNames'] as Map<String, dynamic>?) ?? {};
    final unreadCounts =
        (room['unreadCounts'] as Map<String, dynamic>?) ?? {};
    final lastMessage = room['lastMessage'] as String? ?? '';
    final roomId = room['id'] as String? ?? '';
    final studentName = room['studentName'] as String? ?? '';

    // Get the other participant's name
    String otherName = 'Unknown';
    for (final entry in participantNames.entries) {
      if (entry.key != userId) {
        otherName = entry.value as String;
        break;
      }
    }

    final unread = (unreadCounts[userId] as num?)?.toInt() ?? 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.navy.withOpacity(0.1),
        child: Text(otherName.isNotEmpty ? otherName[0] : '?',
            style: const TextStyle(
                color: AppColors.navy, fontWeight: FontWeight.w600)),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(otherName,
                style: GoogleFonts.poppins(
                    fontWeight:
                        unread > 0 ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14)),
          ),
          if (unread > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$unread',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (studentName.isNotEmpty)
            Text('Re: $studentName',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.gold)),
          Text(lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(roomId: roomId, otherName: otherName),
        ));
        _loadRooms();
      },
    );
  }
}

/// Filterable contact list widget used in the New Chat dialog
class _ContactList extends StatefulWidget {
  final List<dynamic> contacts;
  final void Function(Map<String, dynamic>) onSelect;

  const _ContactList({required this.contacts, required this.onSelect});

  @override
  State<_ContactList> createState() => _ContactListState();
}

class _ContactListState extends State<_ContactList> {
  String _search = '';

  List<dynamic> get _filtered {
    if (_search.isEmpty) return widget.contacts;
    final q = _search.toLowerCase();
    return widget.contacts.where((c) {
      final name = (c['fullName'] as String? ?? '').toLowerCase();
      final email = (c['email'] as String? ?? '').toLowerCase();
      final role = (c['role'] as String? ?? '').toLowerCase();
      return name.contains(q) || email.contains(q) || role.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search by name, email, or role...',
            prefixIcon: const Icon(Icons.search),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('No matching contacts.',
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecondary)))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final c = filtered[index] as Map<String, dynamic>;
                    final name = c['fullName'] as String? ?? 'Unknown';
                    final email = c['email'] as String? ?? '';
                    final role = c['role'] as String? ?? '';
                    final displayRole = role
                        .replaceAll('ROLE_', '')
                        .replaceAll('_', ' ');

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.navy.withOpacity(0.1),
                        child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w600)),
                      ),
                      title: Text(name,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500, fontSize: 14)),
                      subtitle: Text('$displayRole  |  $email',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                      onTap: () => widget.onSelect(c),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
