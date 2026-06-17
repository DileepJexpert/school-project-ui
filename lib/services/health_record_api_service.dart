import 'dio_client.dart';

class HealthRecordApiService {
  static Future<List<dynamic>> getAllRecords() async {
    final r = await DioClient.get('/health-records');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> getByStudentId(String studentId) async {
    final r = await DioClient.get('/health-records/student/$studentId');
    return r.data as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getByClass(String className) async {
    final r = await DioClient.get('/health-records/class/$className');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> createOrUpdate(
      Map<String, dynamic> data) async {
    final r = await DioClient.post('/health-records', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<void> delete(String id) async {
    await DioClient.delete('/health-records/$id');
  }

  static Future<Map<String, dynamic>> addVisit(
      String studentId, Map<String, dynamic> data) async {
    final r = await DioClient.post('/health-records/student/$studentId/visit',
        data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<void> removeVisit(String studentId, String visitId) async {
    await DioClient.delete(
        '/health-records/student/$studentId/visit/$visitId');
  }

  static Future<Map<String, dynamic>> getStats() async {
    final r = await DioClient.get('/health-records/stats');
    return r.data as Map<String, dynamic>;
  }

  // Student portal
  static Future<Map<String, dynamic>> getMyHealthRecord() async {
    final r = await DioClient.get('/student-portal/health-record');
    return r.data as Map<String, dynamic>;
  }
}
