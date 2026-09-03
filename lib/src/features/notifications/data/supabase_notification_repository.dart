import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/notification_model.dart';
import 'notification_repository.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  const SupabaseNotificationRepository({this.client});

  final SupabaseClient? client;

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  static const List<Map<String, dynamic>> _defaultStarterNotifications = <Map<String, dynamic>>[
    <String, dynamic>{
      'notif_id': 'starter-ai-review',
      'notif_title': 'AI Feedback Ready',
      'notif_message':
          'Your submission for Python Data Pipelines passed 12/12 unit tests with 94% efficiency score.',
      'notif_is_read': false,
      'notif_type': 'ai',
      'action_url': '/learn/activity',
      'action_text': 'View Review',
    },
    <String, dynamic>{
      'notif_id': 'starter-streak-alert',
      'notif_title': 'Keep Your 7-Day Streak!',
      'notif_message':
          'You\'ve practiced coding 7 days in a row! Solve 1 exercise today to extend your streak.',
      'notif_is_read': false,
      'notif_type': 'streak',
      'action_url': '/learn/modules',
      'action_text': 'Practice Now',
    },
    <String, dynamic>{
      'notif_id': 'starter-module-unlocked',
      'notif_title': 'Pathway Unlocked',
      'notif_message':
          'New practice module \'Asynchronous JavaScript & Promises\' is now available in your catalog.',
      'notif_is_read': true,
      'notif_type': 'achievement',
      'action_url': '/learn/modules',
      'action_text': 'Explore Module',
    },
  ];

  @override
  Future<List<NotificationModel>> getNotifications(String userId) async {
    if (userId.isEmpty) return <NotificationModel>[];

    try {
      // 1. Live Supabase Query
      final List<Map<String, dynamic>> rows = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('notif_created_at', ascending: false)
          .limit(30);

      if (rows.isNotEmpty) {
        return rows.map((Map<String, dynamic> r) => NotificationModel.fromJson(r)).toList();
      }

      // 2. If new user has 0 notifications, seed starter notifications into DB
      final DateTime now = DateTime.now();
      final List<Map<String, dynamic>> seededRows = <Map<String, dynamic>>[];
      for (int i = 0; i < _defaultStarterNotifications.length; i++) {
        final Map<String, dynamic> item = _defaultStarterNotifications[i];
        final Map<String, dynamic> row = <String, dynamic>{
          'user_id': userId,
          'notif_title': item['notif_title'],
          'notif_message': item['notif_message'],
          'notif_is_read': item['notif_is_read'],
          'notif_type': item['notif_type'],
          'notif_created_at': now.subtract(Duration(hours: i * 3 + 1)).toIso8601String(),
        };
        seededRows.add(row);
      }

      try {
        final List<Map<String, dynamic>> inserted = await _supabase
            .from('notifications')
            .insert(seededRows)
            .select();

        if (inserted.isNotEmpty) {
          return inserted.map((Map<String, dynamic> r) => NotificationModel.fromJson(r)).toList();
        }
      } catch (_) {
        // Fallback to local starter models if insert restricted
      }

      return _defaultStarterNotifications.map((Map<String, dynamic> s) {
        return NotificationModel.fromJson(<String, dynamic>{
          ...s,
          'user_id': userId,
          'notif_created_at': DateTime.now().toIso8601String(),
        });
      }).toList();
    } catch (e, st) {
      debugPrint('getNotifications error: $e\n$st');
      return _defaultStarterNotifications.map((Map<String, dynamic> s) {
        return NotificationModel.fromJson(<String, dynamic>{
          ...s,
          'user_id': userId,
          'notif_created_at': DateTime.now().toIso8601String(),
        });
      }).toList();
    }
  }

  @override
  Future<bool> markAsRead(String notificationId, String userId) async {
    try {
      if (notificationId.isEmpty || userId.isEmpty) return false;

      await _supabase
          .from('notifications')
          .update(<String, dynamic>{'notif_is_read': true})
          .eq('notif_id', notificationId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('markAsRead error: $e');
      return false;
    }
  }

  @override
  Future<bool> markAllAsRead(String userId) async {
    try {
      if (userId.isEmpty) return false;

      await _supabase
          .from('notifications')
          .update(<String, dynamic>{'notif_is_read': true})
          .eq('user_id', userId)
          .eq('notif_is_read', false);

      return true;
    } catch (e) {
      debugPrint('markAllAsRead error: $e');
      return false;
    }
  }

  @override
  Future<bool> clearAll(String userId) async {
    try {
      if (userId.isEmpty) return false;

      await _supabase
          .from('notifications')
          .delete()
          .eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('clearAll error: $e');
      return false;
    }
  }
}
