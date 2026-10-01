import 'dio_client.dart';

class PlatformApiService {
  PlatformApiService._();

  static String get _baseUrl {
    final apiUrl = DioClient.baseUrl;
    final serverRoot = apiUrl.endsWith('/api')
        ? apiUrl.substring(0, apiUrl.length - 4)
        : apiUrl;
    return '$serverRoot/platform/schools';
  }

  static Future<List<Map<String, dynamic>>> getSchools() async {
    final response = await DioClient.instance.get(_baseUrl);
    return (response.data as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<void> createSchool(Map<String, dynamic> school) async {
    await DioClient.instance.post(_baseUrl, data: school);
  }

  static Future<void> setSchoolActive(String tenantId, bool active) async {
    await DioClient.instance.put(
      '$_baseUrl/$tenantId/status',
      data: {'active': active},
    );
  }
}
