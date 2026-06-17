import 'dio_client.dart';

class StaffAttendanceApiService {
  static const _base = '/staff-attendance';

  static Future<List<dynamic>> getByDate(String date) async {
    final r = await DioClient.get('$_base/date/$date');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> markAttendance(
      Map<String, dynamic> data) async {
    final r = await DioClient.post(_base, data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<void> markBulkAttendance(
      List<Map<String, dynamic>> data) async {
    await DioClient.post('$_base/bulk', data: data);
  }

  static Future<Map<String, dynamic>> updateAttendance(
      String id, Map<String, dynamic> data) async {
    final r = await DioClient.put('$_base/$id', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getByStaff(String userId) async {
    final r = await DioClient.get('$_base/staff/$userId');
    return r.data as List;
  }

  static Future<List<dynamic>> getByDateRange(String from, String to) async {
    final r = await DioClient.get('$_base/range',
        queryParams: {'from': from, 'to': to});
    return r.data as List;
  }

  static Future<Map<String, dynamic>> getTodayStats() async {
    final r = await DioClient.get('$_base/today-stats');
    return r.data as Map<String, dynamic>;
  }
}
