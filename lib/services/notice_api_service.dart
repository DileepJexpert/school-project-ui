import 'dio_client.dart';

class NoticeApiService {
  static Future<List<dynamic>> getAllNotices() async {
    final r = await DioClient.get('/notices');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> getNotice(String id) async {
    final r = await DioClient.get('/notices/$id');
    return r.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> create(
      Map<String, dynamic> data) async {
    final r = await DioClient.post('/notices', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> data) async {
    final r = await DioClient.put('/notices/$id', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<void> delete(String id) async {
    await DioClient.delete('/notices/$id');
  }

  static Future<void> publish(String id) async {
    await DioClient.put('/notices/$id/publish');
  }

  static Future<void> togglePin(String id) async {
    await DioClient.put('/notices/$id/pin');
  }

  static Future<void> markAsRead(String id) async {
    await DioClient.put('/notices/$id/read');
  }

  static Future<List<dynamic>> getByCategory(String category) async {
    final r = await DioClient.get('/notices/category/$category');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> getStats() async {
    final r = await DioClient.get('/notices/stats');
    return r.data as Map<String, dynamic>;
  }

  // Student portal
  static Future<List<dynamic>> getStudentNotices() async {
    final r = await DioClient.get('/student-portal/notices');
    return r.data as List;
  }
}
