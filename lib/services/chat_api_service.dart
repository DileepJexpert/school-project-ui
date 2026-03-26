import 'dio_client.dart';

class ChatApiService {
  static const _base = '/chat';

  /// Get all tenant users as chat contacts
  static Future<List<dynamic>> getContacts() async {
    final response = await DioClient.get('/users');
    return response.data as List<dynamic>;
  }

  /// Get all chat rooms for the current user
  static Future<List<dynamic>> getMyRooms(String userId) async {
    final response = await DioClient.get(
      '$_base/rooms',
      queryParams: {'userId': userId},
    );
    return response.data as List<dynamic>;
  }

  /// Get or create a chat room between two users
  static Future<Map<String, dynamic>> getOrCreateRoom({
    required String userId1,
    required String userId2,
    required String studentId,
    required Map<String, String> names,
    required Map<String, String> roles,
  }) async {
    final response = await DioClient.post('$_base/rooms', data: {
      'userId1': userId1,
      'userId2': userId2,
      'studentId': studentId,
      'names': names,
      'roles': roles,
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
