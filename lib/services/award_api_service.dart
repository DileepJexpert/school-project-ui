import 'dio_client.dart';

class AwardApiService {
  static Future<List<dynamic>> getAllAwards() async {
    final r = await DioClient.get('/awards');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> getAward(String id) async {
    final r = await DioClient.get('/awards/$id');
    return r.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> create(
      Map<String, dynamic> data) async {
    final r = await DioClient.post('/awards', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> data) async {
    final r = await DioClient.put('/awards/$id', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<void> delete(String id) async {
    await DioClient.delete('/awards/$id');
  }

  static Future<List<dynamic>> getByStudent(String studentId) async {
    final r = await DioClient.get('/awards/student/$studentId');
    return r.data as List;
  }

  static Future<List<dynamic>> getByClass(String className) async {
    final r = await DioClient.get('/awards/class/$className');
    return r.data as List;
  }

  static Future<List<dynamic>> getByCategory(String category) async {
    final r = await DioClient.get('/awards/category/$category');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> getStats() async {
    final r = await DioClient.get('/awards/stats');
    return r.data as Map<String, dynamic>;
  }

  // Student portal
  static Future<List<dynamic>> getMyAwards() async {
    final r = await DioClient.get('/student-portal/awards');
    return r.data as List;
  }
}
