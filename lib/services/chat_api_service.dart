import 'dio_client.dart';

class ChatApiService {
  static const _base = '/chat';

  /// Get all chat rooms for the current user
  static Future<List<dynamic>> getMyRooms(String userId) async {
    final response = await DioClient.get(
      '$_base/rooms',
      queryParams: {'userId': userId},
    );
    return response.data as List<dynamic>;
  }

  /// Get or create a chat room
  static Future<Map<String, dynamic>> getOrCreateRoom({
    required List<String> participants,
    required String studentId,
    required Map<String, String> participantNames,
    required Map<String, String> participantRoles,
  }) async {
    final response = await DioClient.post('$_base/rooms', data: {
      'participants': participants,
      'studentId': studentId,
      'participantNames': participantNames,
      'participantRoles': participantRoles,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Get messages for a room
  static Future<List<dynamic>> getMessages(String roomId,
      {int page = 0, int size = 50}) async {
    final response = await DioClient.get(
      '$_base/rooms/$roomId/messages',
      queryParams: {'page': page, 'size': size},
    );
    return response.data as List<dynamic>;
  }

  /// Send a message
  static Future<Map<String, dynamic>> sendMessage(
      String roomId, Map<String, dynamic> message) async {
    final response =
        await DioClient.post('$_base/rooms/$roomId/messages', data: message);
    return response.data as Map<String, dynamic>;
  }

  /// Mark messages in a room as read
  static Future<void> markAsRead(String roomId, String userId) async {
    await DioClient.put(
      '$_base/rooms/$roomId/read',
      data: {'userId': userId},
    );
  }
}
