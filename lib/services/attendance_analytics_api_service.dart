import 'dio_client.dart';

class AttendanceAnalyticsApiService {
  static Future<Map<String, dynamic>> getAnalytics({
    String? className,
    String? academicYear,
  }) async {
    final params = <String, dynamic>{};
    if (className != null) params['className'] = className;
    if (academicYear != null) params['academicYear'] = academicYear;
    final r = await DioClient.get('/attendance/analytics', queryParams: params);
    return r.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getStudentDetail(
    String studentId, {
    String? academicYear,
  }) async {
    final params = <String, dynamic>{};
    if (academicYear != null) params['academicYear'] = academicYear;
    final r = await DioClient.get(
      '/attendance/analytics/student/$studentId',
      queryParams: params,
    );
    return r.data as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getAtRiskStudents({
    String? academicYear,
    int threshold = 75,
  }) async {
    final params = <String, dynamic>{'threshold': threshold};
    if (academicYear != null) params['academicYear'] = academicYear;
    final r = await DioClient.get('/attendance/at-risk', queryParams: params);
    return r.data as List;
  }
}
