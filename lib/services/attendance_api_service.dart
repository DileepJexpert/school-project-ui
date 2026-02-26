import '../models/attendance_model.dart';
import 'dio_client.dart';

class AttendanceApiService {
  static const _base = '/attendance';

  /// Marks attendance in bulk for all students of a class on a given date.
  static Future<List<AttendanceModel>> markBulkAttendance({
    required String className,
    required String academicYear,
    required String date,
    required String markedBy,
    required List<Map<String, dynamic>> entries,
  }) async {
    final response = await DioClient.post('$_base/mark', data: {
      'className': className,
      'academicYear': academicYear,
      'date': date,
      'markedBy': markedBy,
      'entries': entries,
    });
    return (response.data as List)
        .map((e) => AttendanceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns attendance records for a class on a specific date.
  static Future<List<AttendanceModel>> getClassAttendance(
      String className, String date) async {
    final response = await DioClient.get(
      '$_base/class/$className',
      queryParams: {'date': date},
    );
    return (response.data as List)
        .map((e) => AttendanceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns attendance records for a student between two dates.
  static Future<List<AttendanceModel>> getStudentAttendance(
      String studentId, String from, String to) async {
    final response = await DioClient.get(
      '$_base/student/$studentId',
      queryParams: {'from': from, 'to': to},
    );
    return (response.data as List)
        .map((e) => AttendanceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns attendance summary for a student in an academic year.
  static Future<AttendanceSummaryModel> getAttendanceSummary(
      String studentId, String academicYear) async {
    final response = await DioClient.get(
      '$_base/student/$studentId/summary',
      queryParams: {'academicYear': academicYear},
    );
    return AttendanceSummaryModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  static Future<void> deleteAttendance(String id) async {
    await DioClient.delete('$_base/$id');
  }
}
