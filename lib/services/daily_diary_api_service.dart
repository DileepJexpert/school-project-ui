import 'dio_client.dart';

class DailyDiaryApiService {
  static const _base = '/daily-diary';

  /// Get all diary entries (admin/teacher). Optional className filter.
  static Future<List<dynamic>> getAllEntries({String? className}) async {
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

  /// Get diary entries by class name.
  static Future<List<dynamic>> getByClass(String className) async {
    final response = await DioClient.get('$_base/class/$className');
    return response.data as List<dynamic>;
  }

  /// Get diary entries by class and date.
  static Future<List<dynamic>> getByClassAndDate(
      String className, String date) async {
    final response = await DioClient.get(
      '$_base/class/$className/date',
      queryParams: {'date': date},
    );
    return response.data as List<dynamic>;
  }

  /// Get diary entries created by the logged-in teacher.
  static Future<List<dynamic>> getMyEntries() async {
    final response = await DioClient.get('$_base/my-entries');
    return response.data as List<dynamic>;
  }

  /// Create a new diary entry (teacher/admin).
  static Future<Map<String, dynamic>> create(
      Map<String, dynamic> data) async {
    final response = await DioClient.post(_base, data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Update an existing diary entry.
  static Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> data) async {
    final response = await DioClient.put('$_base/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Delete a diary entry.
  static Future<void> delete(String id) async {
    await DioClient.delete('$_base/$id');
  }

  // ── Student Portal ──

  /// Get diary entries for the logged-in student. Optional date filter.
  static Future<List<dynamic>> getMyDiary({String? date}) async {
    final params = <String, dynamic>{};
    if (date != null) params['date'] = date;
    final response = await DioClient.get(
      '/student-portal/daily-diary',
      queryParams: params.isNotEmpty ? params : null,
    );
    return response.data as List<dynamic>;
  }

  /// Get today's diary entries for the logged-in student.
  static Future<List<dynamic>> getTodayDiary() async {
    final response = await DioClient.get('/student-portal/daily-diary/today');
    return response.data as List<dynamic>;
  }
}
