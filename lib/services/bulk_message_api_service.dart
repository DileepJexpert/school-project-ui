import 'dio_client.dart';

class BulkMessageApiService {
  static const _base = '/bulk-messages';

  static Future<Map<String, dynamic>> sendBulkMessage(
      Map<String, dynamic> data) async {
    final response = await DioClient.post(_base, data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getAllMessages() async {
    final response = await DioClient.get(_base);
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> getMessage(String id) async {
    final response = await DioClient.get('$_base/$id');
    return response.data as Map<String, dynamic>;
  }
}
