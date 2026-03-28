import 'dio_client.dart';

class AiApiService {
  /// Send a message to AI homework helper
  static Future<Map<String, dynamic>> chat(Map<String, dynamic> data) async {
    final response = await DioClient.post('/ai/chat', data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Get all conversations for the logged-in student
  static Future<List<dynamic>> getConversations() async {
    final response = await DioClient.get('/ai/conversations');
    return response.data as List<dynamic>;
  }

  /// Get a specific conversation by ID
  static Future<Map<String, dynamic>> getConversation(String id) async {
    final response = await DioClient.get('/ai/conversations/$id');
    return response.data as Map<String, dynamic>;
  }

  /// Get usage stats for the logged-in student
  static Future<List<dynamic>> getUsage() async {
    final response = await DioClient.get('/ai/usage');
    return response.data as List<dynamic>;
  }
}
