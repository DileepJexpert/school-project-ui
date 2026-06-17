import 'dio_client.dart';

class ExamScheduleApiService {
  static const _base = '/exam-schedules';

  static Future<List<Map<String, dynamic>>> getAllSchedules(
      String academicYear) async {
    final response =
        await DioClient.get(_base, queryParams: {'academicYear': academicYear});
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getClassSchedules(
    String className,
    String academicYear, {
    String? status,
  }) async {
    final params = <String, dynamic>{'academicYear': academicYear};
    if (status != null) params['status'] = status;
    final response = await DioClient.get('$_base/class/$className',
        queryParams: params);
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> createSchedule(
      Map<String, dynamic> data) async {
    final response = await DioClient.post(_base, data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateSchedule(
      String id, Map<String, dynamic> data) async {
    final response = await DioClient.put('$_base/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<void> publishSchedule(String id) async {
    await DioClient.put('$_base/$id/publish');
  }

  static Future<void> deleteSchedule(String id) async {
    await DioClient.delete('$_base/$id');
  }
}
