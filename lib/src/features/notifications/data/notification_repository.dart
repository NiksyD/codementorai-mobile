import '../domain/notification_model.dart';

abstract class NotificationRepository {
  Future<List<NotificationModel>> getNotifications(String userId);
  Future<bool> markAsRead(String notificationId, String userId);
  Future<bool> markAllAsRead(String userId);
  Future<bool> clearAll(String userId);
}
