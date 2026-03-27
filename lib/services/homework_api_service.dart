import 'dio_client.dart';

class HomeworkApiService {
  static const _base = '/homework';

  /// Get homework for the logged-in student (uses JWT linkedEntityId on backend)
  static Future<List<dynamic>> getMyHomework() async {
    final response = await DioClient.get('/student-portal/homework');
    return response.data as List<dynamic>;
  }

  /// Get all homework (admin/teacher). Optional className filter.
  static Future<List<dynamic>> getAllHomework({String? className}) async {
    final params = <String, dynamic>{};
    if (className != null && className.isNotEmpty) {
      params['className'] = className;
    }
    final response = await DioClient.get(
      _base,
      queryParams: params.isNotEmpty ? params : null,
    );
    return response.data as List<dynamic>;
  }

  /// Create homework (teacher/admin)
  static Future<Map<String, dynamic>> createHomework(
      Map<String, dynamic> data) async {
    final response = await DioClient.post(_base, data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Update homework
  static Future<Map<String, dynamic>> updateHomework(
      String id, Map<String, dynamic> data) async {
    final response = await DioClient.put('$_base/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Delete homework
  static Future<void> deleteHomework(String id) async {
    await DioClient.delete('$_base/$id');
  }
}
