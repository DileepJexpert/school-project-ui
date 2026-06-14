import 'package:dio/dio.dart';

import 'dio_client.dart';

class ParentApiService {
  static const _base = '/parent';

  /// Get parent dashboard with all children overview
  static Future<Map<String, dynamic>> getDashboard() async {
    final response = await DioClient.get('$_base/dashboard');
    return response.data as Map<String, dynamic>;
  }

  /// Get attendance records for a specific child
  static Future<List<dynamic>> getChildAttendance(String studentId,
      {String? month, String? year}) async {
    final params = <String, dynamic>{};
    if (month != null) params['month'] = month;
    if (year != null) params['year'] = year;
    final response = await DioClient.get(
      '$_base/child/$studentId/attendance',
      queryParams: params.isNotEmpty ? params : null,
    );
    return response.data as List<dynamic>;
  }

  /// Get attendance summary for a specific child
  static Future<Map<String, dynamic>> getChildAttendanceSummary(
      String studentId) async {
    final response =
        await DioClient.get('$_base/child/$studentId/attendance/summary');
    return response.data as Map<String, dynamic>;
  }

  /// Get results/report card for a specific child
  static Future<Map<String, dynamic>> getChildResults(String studentId,
      {String? academicYear}) async {
    final params = <String, dynamic>{};
    if (academicYear != null) params['academicYear'] = academicYear;
    final response = await DioClient.get(
      '$_base/child/$studentId/results',
      queryParams: params.isNotEmpty ? params : null,
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get fee status for a specific child
  static Future<Map<String, dynamic>> getChildFees(String studentId) async {
    final response = await DioClient.get('$_base/child/$studentId/fees');
    return response.data as Map<String, dynamic>;
  }

  /// Get timetable for a specific child
  static Future<dynamic> getChildTimetable(String studentId) async {
    final response = await DioClient.get('$_base/child/$studentId/timetable');
    return response.data;
  }

  /// Download report card PDF for a specific child
  static Future<List<int>> downloadReportCardPdf(
      String studentId, String academicYear) async {
    final resp = await DioClient.instance.get(
      '/api$_base/child/$studentId/results/pdf',
      queryParameters: {'academicYear': academicYear},
      options: Options(responseType: ResponseType.bytes),
    );
    return resp.data as List<int>;
  }
}
