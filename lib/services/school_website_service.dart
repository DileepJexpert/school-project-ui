import 'dio_client.dart';
import 'package:dio/dio.dart';

class SchoolWebsiteService {
  static const _publicBase = '/public/website';

  /// Fetch a school's public website config by tenant ID.
  /// No auth required — uses the server root, not the /api prefix.
  static Future<Map<String, dynamic>> getPublicWebsite(String tenantId) async {
    // Strip only a trailing '/api' — replaceAll would corrupt URLs that
    // contain '/api' elsewhere (e.g. https://my-api.example.com/api).
    final serverRoot =
        DioClient.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
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

  // ── Public Admission endpoints (no auth) ──

  /// Submit a public online admission application.
  /// Returns the created record (includes enquiry/admission number).
  static Future<Map<String, dynamic>> submitPublicAdmission(
      String tenantId, Map<String, dynamic> data) async {
    final serverRoot =
        DioClient.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final response = await Dio()
        .post('$serverRoot/public/admissions/$tenantId', data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Fetch the list of classes available for public admission.
  static Future<List<String>> getAvailableClasses(String tenantId) async {
    final serverRoot =
        DioClient.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final response =
        await Dio().get('$serverRoot/public/admissions/$tenantId/classes');
    return (response.data as List).cast<String>();
  }
}
