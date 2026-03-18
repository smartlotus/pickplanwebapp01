// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';

import 'notification_service_adapter.dart';

class WebNotificationService implements NotificationServiceAdapter {
  final Map<int, Timer> _timers = <int, Timer>{};
  bool _pushInitTried = false;

  Object? get _pushClient {
    if (js_util.hasProperty(html.window, 'PickplanPush')) {
      return js_util.getProperty(html.window, 'PickplanPush');
    }
    return null;
  }

  Future<void> _callPushClient(String method, [List<dynamic> args = const []]) async {
    final client = _pushClient;
    if (client == null || !js_util.hasProperty(client, method)) return;

    try {
      final result = js_util.callMethod(client, method, args);
      if (result != null && js_util.hasProperty(result, 'then')) {
        await js_util.promiseToFuture(result);
      }
    } catch (e, stackTrace) {
      // Keep local notifications reliable even when push backend is unstable.
      if (kDebugMode) {
        debugPrint('PickplanPush.$method failed: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  @override
  Future<void> init() async {
    if (_pushInitTried) return;
    _pushInitTried = true;
    // Keep web startup non-blocking. Push registration is triggered lazily
    // when the user actually tests notifications or schedules a reminder.
  }

  @override
  Future<bool> checkPermissions() async {
    if (!html.Notification.supported) return false;

    final permission = html.Notification.permission;
    if (permission == 'granted') return true;
    if (permission == 'denied') return false;

    final result = await html.Notification.requestPermission();
    return result == 'granted';
  }

  @override
  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    if (!await checkPermissions()) return;
    html.Notification(title, body: body);
    await _callPushClient('test', <dynamic>[title, body]);
  }

  @override
  Future<void> scheduleTodoNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (scheduledTime.isBefore(DateTime.now())) return;
    if (!await checkPermissions()) return;

    _timers.remove(id)?.cancel();
    final delay = scheduledTime.difference(DateTime.now());

    _timers[id] = Timer(delay, () {
      try {
        html.Notification(title, body: body);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Web notification failed: $e');
        }
      } finally {
        _timers.remove(id);
      }
    });

    await _callPushClient('schedule', <dynamic>[
      id.toString(),
      title,
      body,
      scheduledTime.toUtc().toIso8601String(),
    ]);
  }

  @override
  Future<void> cancelNotification(int id) async {
    _timers.remove(id)?.cancel();
    await _callPushClient('cancel', <dynamic>[id.toString()]);
  }
}

NotificationServiceAdapter createNotificationService() {
  return WebNotificationService();
}
