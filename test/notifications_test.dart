import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/src/features/notifications/domain/notification_model.dart';

void main() {
  group('NotificationModel Invitation Tests', () {
    test('Correctly normalizes hub_member and generates Review Invitation action', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'notif_id': 'notif-123',
        'user_id': 'user-456',
        'notif_title': 'Hub Invitation',
        'notif_message': 'Niko Andrei invited you to join New Hub. Review and accept the invitation to start learning.',
        'notif_type': 'hub_member',
        'notif_source_id': 'hub-789',
        'notif_is_read': false,
        'notif_created_at': DateTime.now().toIso8601String(),
      };

      final NotificationModel model = NotificationModel.fromJson(json);

      expect(model.id, equals('notif-123'));
      expect(model.type, equals('hub_member'));
      expect(model.actionUrl, equals('/hubs'));
      expect(model.actionText, equals('Review Invitation'));
      expect(model.isRead, isFalse);
    });

    test('Correctly handles room_member type fallback with invitation title', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'notif_id': 'notif-abc',
        'user_id': 'user-456',
        'notif_title': 'Hub Invitation',
        'notif_message': 'Your mentor invited you to join Python Mastery.',
        'notif_type': 'room_member',
        'notif_source_id': 'room-xyz',
        'notif_is_read': false,
        'notif_created_at': DateTime.now().toIso8601String(),
      };

      final NotificationModel model = NotificationModel.fromJson(json);

      expect(model.type, equals('hub_member'));
      expect(model.actionUrl, equals('/hubs'));
      expect(model.actionText, equals('Review Invitation'));
    });

    test('Non-invitation hub member notification yields View Hub action', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'notif_id': 'notif-def',
        'user_id': 'user-456',
        'notif_title': 'Hub Admission Approved',
        'notif_message': 'You have been admitted to Web Development.',
        'notif_type': 'hub_member',
        'notif_source_id': 'hub-999',
        'notif_is_read': true,
        'notif_created_at': DateTime.now().toIso8601String(),
      };

      final NotificationModel model = NotificationModel.fromJson(json);

      expect(model.type, equals('hub_member'));
      expect(model.actionUrl, equals('/hubs'));
      expect(model.actionText, equals('View Hub'));
      expect(model.isRead, isTrue);
    });
  });
}
