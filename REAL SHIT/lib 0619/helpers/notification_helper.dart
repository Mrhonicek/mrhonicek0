import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize local notifications
  static Future<void> initializeLocalNotifications() async {
    // Android initialization settings
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings (if needed)
    const DarwinInitializationSettings iOSInitSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iOSInitSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('Notification tapped: ${response.payload}');
        // You can add navigation logic here
      },
    );
  }

  // Show a local notification
  static Future<void> showLocalNotification(
    OSNotification notification, {
    String? channelId = 'default_channel',
    String? channelName = 'Default Channel',
    Color notificationColor = Colors.blue,
    bool enableVibration = true,
    bool playSound = true,
    String? soundFile,
    String? largeIcon,
    String? bigPicture,
  }) async {
    // Create Android-specific notification details
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId!,
      channelName!,
      importance: Importance.max,
      priority: Priority.high,
      color: notificationColor,
      enableVibration: enableVibration,
      playSound: playSound,
      sound: soundFile != null
          ? RawResourceAndroidNotificationSound(soundFile)
          : null,
      largeIcon: largeIcon != null ? FilePathAndroidBitmap(largeIcon) : null,
      styleInformation: bigPicture != null
          ? BigPictureStyleInformation(FilePathAndroidBitmap(bigPicture))
          : null,
      icon: '@mipmap/ic_launcher',
      channelShowBadge: true,
      // Add ticker text for accessibility
      ticker: 'New notification',
    );

    // Create iOS-specific notification details (if needed)
    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Combine platform-specific details
    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    // Extract additional data if available
    Map<String, dynamic>? additionalData = notification.additionalData;
    String? payload = additionalData != null ? additionalData.toString() : null;

    // Show the notification
    if (notification.title != null && notification.body != null) {
      await flutterLocalNotificationsPlugin.show(
        notification.androidNotificationId ?? 0,
        notification.title,
        notification.body,
        platformDetails,
        payload: payload,
      );
    }
  }

  // Create notification channels for Android
  static Future<void> createNotificationChannels() async {
    // Emergency alerts channel
    const AndroidNotificationChannel emergencyChannel =
        AndroidNotificationChannel(
      'emergency_channel',
      'Emergency Alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Colors.red,
      showBadge: true,
      description: 'Notifications for emergency alerts',
    );

    // General alerts channel
    const AndroidNotificationChannel generalChannel =
        AndroidNotificationChannel(
      'general_channel',
      'General Notifications',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      description: 'Notifications for general updates',
    );

    // Create the channels
    final androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(emergencyChannel);
      await androidPlugin.createNotificationChannel(generalChannel);
    }
  }

  // Schedule a delayed notification
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? channelId = 'default_channel',
    String? channelName = 'Default Channel',
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId!,
      channelName!,
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails();

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );
    // Ensure you have imported: import 'package:timezone/timezone.dart' as tz;
    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      platformDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
