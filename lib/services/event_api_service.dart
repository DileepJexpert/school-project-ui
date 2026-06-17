import 'dio_client.dart';

class EventApiService {
  static const _base = '/events';

  static Future<List<Map<String, dynamic>>> getAllEvents() async {
    final response = await DioClient.get(_base);
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getUpcomingEvents() async {
    final response = await DioClient.get('$_base/upcoming');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> createEvent(
      Map<String, dynamic> data) async {
    final response = await DioClient.post(_base, data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateEvent(
      String id, Map<String, dynamic> data) async {
    final response = await DioClient.put('$_base/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<void> deleteEvent(String id) async {
    await DioClient.delete('$_base/$id');
  }
}
