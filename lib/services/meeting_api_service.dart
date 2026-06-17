import 'dio_client.dart';

class MeetingApiService {
  static Future<List<dynamic>> getAllMeetings() async {
    final r = await DioClient.get('/meetings');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> getMeeting(String id) async {
    final r = await DioClient.get('/meetings/$id');
    return r.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> create(
      Map<String, dynamic> data) async {
    final r = await DioClient.post('/meetings', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> data) async {
    final r = await DioClient.put('/meetings/$id', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<void> delete(String id) async {
    await DioClient.delete('/meetings/$id');
  }

  static Future<void> cancel(String id) async {
    await DioClient.put('/meetings/$id/cancel');
  }

  static Future<void> complete(String id, String notes) async {
    await DioClient.put('/meetings/$id/complete', data: {'notes': notes});
  }

  static Future<void> addFeedback(String id, String feedback) async {
    await DioClient.put('/meetings/$id/feedback',
        data: {'feedback': feedback});
  }

  static Future<List<dynamic>> getByTeacher(String teacherId) async {
    final r = await DioClient.get('/meetings/teacher/$teacherId');
    return r.data as List;
  }

  static Future<List<dynamic>> getAvailableSlots(
      String teacherId, String date) async {
    final r = await DioClient.get('/meetings/teacher/$teacherId/slots',
        queryParams: {'date': date});
    return r.data as List;
  }

  static Future<List<dynamic>> getUpcoming() async {
    final r = await DioClient.get('/meetings/upcoming');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> getStats() async {
    final r = await DioClient.get('/meetings/stats');
    return r.data as Map<String, dynamic>;
  }

  // Parent portal
  static Future<List<dynamic>> getParentMeetings() async {
    final r = await DioClient.get('/parent/meetings');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> bookMeeting(
      Map<String, dynamic> data) async {
    final r = await DioClient.post('/parent/meetings', data: data);
    return r.data as Map<String, dynamic>;
  }
}
