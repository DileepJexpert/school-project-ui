import '../models/notification_model.dart';
import 'dio_client.dart';

class NotificationApiService {
  static const _base = '/notifications';

  static Future<List<NotificationModel>> getAllNotifications() async {
    final response = await DioClient.get(_base);
    return (response.data as List)
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<NotificationModel> createNotification(
      NotificationModel notification) async {
    final response =
        await DioClient.post(_base, data: notification.toJson());
    return NotificationModel.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<NotificationModel> updateNotification(
      String id, NotificationModel notification) async {
    final response =
        await DioClient.put('$_base/$id', data: notification.toJson());
    return NotificationModel.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<NotificationModel> markAsRead(String id) async {
    final response = await DioClient.put('$_base/$id/read');
    return NotificationModel.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> deleteNotification(String id) async {
    await DioClient.delete('$_base/$id');
  }

  static Future<List<NotificationModel>> getNotificationsByType(
      String type) async {
    final response = await DioClient.get('$_base/type/$type');
    return (response.data as List)
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
