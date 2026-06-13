import 'dio_client.dart';
import 'package:dio/dio.dart';

class SchoolWebsiteService {
  static const _publicBase = '/public/website';

  /// Fetch a school's public website config by tenant ID.
  /// No auth required — uses the server root, not the /api prefix.
  static Future<Map<String, dynamic>> getPublicWebsite(String tenantId) async {
    final serverRoot = DioClient.baseUrl.replaceAll('/api', '');
    final response = await Dio().get('$serverRoot$_publicBase/$tenantId');
    return response.data as Map<String, dynamic>;
  }

  /// Admin: get the current school's website config.
  static Future<Map<String, dynamic>> getWebsite() async {
    final response = await DioClient.get('/website');
    return response.data as Map<String, dynamic>;
  }

  /// Admin: update the current school's website config.
  static Future<Map<String, dynamic>> updateWebsite(
      Map<String, dynamic> data) async {
    final response = await DioClient.put('/website', data: data);
    return response.data as Map<String, dynamic>;
  }
}
