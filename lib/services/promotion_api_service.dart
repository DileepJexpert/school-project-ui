import 'dio_client.dart';

class PromotionApiService {
  static Future<List<dynamic>> getAllPromotions() async {
    final r = await DioClient.get('/promotions');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> getPromotion(String id) async {
    final r = await DioClient.get('/promotions/$id');
    return r.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> promoteStudent(Map<String, dynamic> data) async {
    final r = await DioClient.post('/promotions', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<List<dynamic>> bulkPromote(Map<String, dynamic> data) async {
    final r = await DioClient.post('/promotions/bulk', data: data);
    return r.data as List;
  }

  static Future<Map<String, dynamic>> retainStudent(Map<String, dynamic> data) async {
    final r = await DioClient.post('/promotions/retain', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> issueTC(Map<String, dynamic> data) async {
    final r = await DioClient.post('/promotions/tc', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getByYear(String year) async {
    final r = await DioClient.get('/promotions/year/$year');
    return r.data as List;
  }

  static Future<List<dynamic>> getByClass(String className) async {
    final r = await DioClient.get('/promotions/class/$className');
    return r.data as List;
  }

  static Future<List<dynamic>> getByStudent(String studentId) async {
    final r = await DioClient.get('/promotions/student/$studentId');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> getStats(String academicYear) async {
    final r = await DioClient.get('/promotions/stats', queryParams: {'academicYear': academicYear});
    return r.data as Map<String, dynamic>;
  }
}
