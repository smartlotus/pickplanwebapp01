import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'notification_service_adapter.dart';

class MobileNotificationService implements NotificationServiceAdapter {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  Future<void> init() async {
    tz.initializeTimeZones();

    try {
      final dynamic timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timezoneInfo is String
          ? timezoneInfo
          : timezoneInfo.identifier as String;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // Keep default local timezone if platform timezone lookup fails.
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification clicked: ${details.payload}');
      },
    );
  }

  @override
  Future<bool> checkPermissions() async {
    var status = await Permission.notification.status;
    if (status.isDenied) {
      status = await Permission.notification.request();
    }

    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }

    return status.isGranted;
  }

  @override
  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    final vibrationPattern = Int64List.fromList([0, 1000, 500, 1000]);
    final androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test reminders',
      importance: Importance.max,
      priority: Priority.high,
      vibrationPattern: vibrationPattern,
      enableVibration: true,
      fullScreenIntent: true,
    );

    await _notificationsPlugin.show(
      999,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  @override
  Future<void> scheduleTodoNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (scheduledTime.isBefore(DateTime.now())) return;

    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    final vibrationPattern = Int64List.fromList([0, 1000, 500, 1000, 500, 2000]);

    final androidDetails = AndroidNotificationDetails(
      'todo_reminders_v3',
      'Todo reminders',
      channelDescription: 'Todo reminder and deadline notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      color: const Color(0xFF00F2FF),
      vibrationPattern: vibrationPattern,
      enableVibration: true,
      enableLights: true,
      ledColor: const Color(0xFF00F2FF),
      ledOnMs: 1000,
      ledOffMs: 500,
      ticker: 'Todo time reached: $title',
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      fullScreenIntent: false,
      styleInformation: BigTextStyleInformation(body),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzTime,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }
}

NotificationServiceAdapter createNotificationService() {
  return MobileNotificationService();
}

