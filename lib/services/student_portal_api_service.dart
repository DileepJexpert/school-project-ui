import 'dio_client.dart';

class StudentPortalApiService {
  static const _base = '/student-portal';

  /// Get student's own dashboard overview
  static Future<Map<String, dynamic>> getDashboard() async {
    final response = await DioClient.get('$_base/dashboard');
    return response.data as Map<String, dynamic>;
  }

  /// Get own attendance records
  static Future<List<dynamic>> getMyAttendance(
      {String? month, String? year}) async {
    final params = <String, dynamic>{};
    if (month != null) params['month'] = month;
    if (year != null) params['year'] = year;
    final response = await DioClient.get(
      '$_base/attendance',
      queryParams: params.isNotEmpty ? params : null,
    );
    return response.data as List<dynamic>;
  }

  /// Get own attendance summary
  static Future<Map<String, dynamic>> getMyAttendanceSummary() async {
    final response = await DioClient.get('$_base/attendance/summary');
    return response.data as Map<String, dynamic>;
  }

  /// Get own results
  static Future<Map<String, dynamic>> getMyResults(
      {String? academicYear}) async {
    final params = <String, dynamic>{};
    if (academicYear != null) params['academicYear'] = academicYear;
    final response = await DioClient.get(
      '$_base/results',
      queryParams: params.isNotEmpty ? params : null,
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get own timetable
  static Future<dynamic> getMyTimetable() async {
    final response = await DioClient.get('$_base/timetable');
    return response.data;
  }

  /// Get own fee status
  static Future<Map<String, dynamic>> getMyFees() async {
    final response = await DioClient.get('$_base/fees');
    return response.data as Map<String, dynamic>;
  }
}
