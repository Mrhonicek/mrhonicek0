import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'inbox_model.dart';

class InboxService {
  final SupabaseClient _client = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin(); // Local Notifications Plugin

  InboxService() {
    _setupLocalNotifications(); // Initialize Local Notifications
  }

  Future<List<NotifyBroadcast>> fetchNotifications() async {
    final response = await _client
        .from('notifybroadcast')
        .select()
        .order('broadcasted_on', ascending: false);

    if (response != null && response is List) {
      return response.map((json) => NotifyBroadcast.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load notifications');
    }
  }

  void subscribeToNotifications(Function(NotifyBroadcast) onNewNotification) {
    _client
        .from('notifybroadcast')
        .stream(primaryKey: ['em_alert_id'])
        .order('broadcasted_on', ascending: false)
        .listen((data) {
          for (var record in data) {
            final newNotification = NotifyBroadcast.fromJson(record);
            onNewNotification(newNotification);
            _showLocalNotification(
                newNotification); // 🔔 Show local notification
          }
        });
  }

  // ✅ Initialize Local Notifications
  void _setupLocalNotifications() async {
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initSettings =
        InitializationSettings(android: androidInitSettings);

    await _localNotifications.initialize(initSettings);
  }

  // ✅ Show Local Notification
  Future<void> _showLocalNotification(NotifyBroadcast notification) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'inbox_channel',
      'Inbox Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      notification.emAlertId.hashCode, // Unique ID
      notification.title,
      notification.description,
      notificationDetails,
    );
  }
}
