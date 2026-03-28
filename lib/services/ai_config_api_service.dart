import 'dio_client.dart';

class AiConfigApiService {
  static const _base = '/ai-config';

  /// Get AI config for the school (admin)
  static Future<Map<String, dynamic>> getConfig() async {
    final response = await DioClient.get(_base);
    return response.data as Map<String, dynamic>;
  }

  /// Update AI config (admin)
  static Future<Map<String, dynamic>> updateConfig(
      Map<String, dynamic> data) async {
    final response = await DioClient.put(_base, data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Get usage report (admin)
  static Future<List<dynamic>> getUsageReport(
      String from, String to) async {
    final response = await DioClient.get('$_base/usage-report',
        queryParams: {'from': from, 'to': to});
    return response.data as List<dynamic>;
  }
}
