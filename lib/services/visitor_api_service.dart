import 'dio_client.dart';

class VisitorApiService {
  static Future<List<dynamic>> getAllVisitors() async {
    final r = await DioClient.get('/visitors');
    return r.data as List;
  }

  static Future<List<dynamic>> getTodayVisitors() async {
    final r = await DioClient.get('/visitors/today');
    return r.data as List;
  }

  static Future<List<dynamic>> getCheckedIn() async {
    final r = await DioClient.get('/visitors/checked-in');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> getStats() async {
    final r = await DioClient.get('/visitors/stats');
    return r.data as Map<String, dynamic>;
  }

  static Future<List<dynamic>> search(String query) async {
    final r = await DioClient.get('/visitors/search',
        queryParams: {'q': query});
    return r.data as List;
  }

  static Future<List<dynamic>> getByDateRange(String from, String to) async {
    final r = await DioClient.get('/visitors/date-range',
        queryParams: {'from': from, 'to': to});
    return r.data as List;
  }

  static Future<Map<String, dynamic>> create(
      Map<String, dynamic> data) async {
    final r = await DioClient.post('/visitors', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> data) async {
    final r = await DioClient.put('/visitors/$id', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<void> checkout(String id) async {
    await DioClient.post('/visitors/$id/checkout');
  }

  static Future<void> delete(String id) async {
    await DioClient.delete('/visitors/$id');
  }
}
