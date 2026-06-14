import 'dio_client.dart';

class WhatsAppApiService {
  static const _base = '/whatsapp-config';

  /// Get WhatsApp config for the school (admin)
  static Future<Map<String, dynamic>> getConfig() async {
    final response = await DioClient.get(_base);
    return response.data as Map<String, dynamic>;
  }

  /// Update WhatsApp config (admin)
  static Future<Map<String, dynamic>> updateConfig(
      Map<String, dynamic> data) async {
    final response = await DioClient.put(_base, data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Get conversation logs (admin)
  static Future<List<dynamic>> getConversations() async {
    final response = await DioClient.get('$_base/conversations');
    return response.data as List<dynamic>;
  }

  /// Send a test message (admin)
  static Future<void> sendTestMessage(String phone, String message) async {
    await DioClient.post('$_base/test', data: {
      'phone': phone,
      'message': message,
    });
  }

  /// Manually trigger fee reminders for this school (admin)
  static Future<void> sendFeeReminders() async {
    await DioClient.post('$_base/send-fee-reminders');
  }
}
