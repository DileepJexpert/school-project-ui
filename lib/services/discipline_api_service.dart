import 'dio_client.dart';

class DisciplineApiService {
  static const _base = '/discipline';

  static Future<List<dynamic>> getAllIncidents(
      {String? className, String? severity}) async {
    final params = <String, dynamic>{};
    if (className != null) params['className'] = className;
    if (severity != null) params['severity'] = severity;
    final response = await DioClient.get(
      _base,
      queryParams: params.isNotEmpty ? params : null,
    );
    return response.data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createIncident(
      Map<String, dynamic> data) async {
    final response = await DioClient.post(_base, data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getStudentIncidents(String studentId) async {
    final response = await DioClient.get('$_base/student/$studentId');
    return response.data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> resolveIncident(
      String id, String resolution) async {
    final response = await DioClient.put(
      '$_base/$id/resolve',
      data: {'resolution': resolution},
    );
    return response.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getSummary() async {
    final response = await DioClient.get('$_base/summary');
    return response.data as Map<String, dynamic>;
  }
}
