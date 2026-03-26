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
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
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
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRooms,
                  child: ListView.separated(
                    itemCount: _rooms.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final room = _rooms[index] as Map<String, dynamic>;
                      return _buildRoomTile(room);
                    },
                  ),
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
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(roomId: roomId, otherName: otherName),
        ));
      },
    );
  }
}
