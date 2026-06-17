import 'dio_client.dart';

class ComplaintApiService {
  // Admin endpoints
  static Future<List<dynamic>> getAllComplaints() async {
    final r = await DioClient.get('/complaints');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> getComplaint(String id) async {
    final r = await DioClient.get('/complaints/$id');
    return r.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final r = await DioClient.post('/complaints', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async {
    final r = await DioClient.put('/complaints/$id', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<void> delete(String id) async {
    await DioClient.delete('/complaints/$id');
  }

  static Future<List<dynamic>> getMyComplaints() async {
    final r = await DioClient.get('/complaints/my');
    return r.data as List;
  }

  static Future<List<dynamic>> getByStatus(String status) async {
    final r = await DioClient.get('/complaints/status/$status');
    return r.data as List;
  }

  static Future<List<dynamic>> getByCategory(String category) async {
    final r = await DioClient.get('/complaints/category/$category');
    return r.data as List;
  }

  static Future<void> updateStatus(String id, String status) async {
    await DioClient.put('/complaints/$id/status', data: {'status': status});
  }

  static Future<void> assignTo(String id, String userId, String userName) async {
    await DioClient.put('/complaints/$id/assign', data: {'userId': userId, 'userName': userName});
  }

  static Future<Map<String, dynamic>> addComment(String id, Map<String, dynamic> data) async {
    final r = await DioClient.post('/complaints/$id/comment', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getStats() async {
    final r = await DioClient.get('/complaints/stats');
    return r.data as Map<String, dynamic>;
  }

  // Student portal
  static Future<List<dynamic>> getStudentComplaints() async {
    final r = await DioClient.get('/student-portal/complaints');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> fileStudentComplaint(Map<String, dynamic> data) async {
    final r = await DioClient.post('/student-portal/complaints', data: data);
    return r.data as Map<String, dynamic>;
  }
}
