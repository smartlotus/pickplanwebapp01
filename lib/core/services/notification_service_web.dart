// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';

import 'notification_service_adapter.dart';

class WebNotificationService implements NotificationServiceAdapter {
  static const String _subscriberStorageKey =
      'pickplan_push_subscriber_id_v1';
  static const Duration _maxLocalFallbackLateness = Duration(seconds: 75);
  final Map<int, Timer> _timers = <int, Timer>{};
  bool _pushInitTried = false;

  Object? get _notificationApi {
    if (js_util.hasProperty(html.window, 'Notification')) {
      return js_util.getProperty(html.window, 'Notification');
    }
    return null;
  }

  Object? get _pushClient {
    if (js_util.hasProperty(html.window, 'PickplanPush')) {
      return js_util.getProperty(html.window, 'PickplanPush');
    }
    return null;
  }

  bool _hasCachedSubscriberId() {
    final cached = html.window.localStorage[_subscriberStorageKey];
    return cached != null && cached.trim().isNotEmpty;
  }

  Future<Object?> _callPushClientWithResult(
    String method, [
    List<dynamic> args = const [],
  ]) async {
    final client = _pushClient;
    if (client == null || !js_util.hasProperty(client, method)) return null;

    try {
      final result = js_util.callMethod(client, method, args);
      if (result != null && js_util.hasProperty(result, 'then')) {
        return await js_util.promiseToFuture<Object?>(result);
      }
      return result;
    } catch (e, stackTrace) {
      // Keep local notifications reliable even when push backend is unstable.
      if (kDebugMode) {
        debugPrint('PickplanPush.$method failed: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
      return null;
    }
  }

  Future<void> _callPushClient(String method, [List<dynamic> args = const []]) async {
    await _callPushClientWithResult(method, args);
  }

  Future<bool> _ensurePushSubscription({required bool promptUser}) async {
    final method = promptUser ? 'resubscribe' : 'init';
    final result = await _callPushClientWithResult(method);
    if (result != null) {
      final text = result.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return true;
      }
    }
    return _hasCachedSubscriberId();
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
    final notificationApi = _notificationApi;
    if (notificationApi == null) {
      return _ensurePushSubscription(promptUser: true);
    }

    var permission = js_util.getProperty(notificationApi, 'permission')?.toString();
    if (permission == 'granted') {
      final hasPushReady = await _ensurePushSubscription(promptUser: false);
      final client = _pushClient;
      if (client != null && js_util.hasProperty(client, 'test')) {
        return hasPushReady;
      }
      return true;
    }
    if (permission == 'denied') return false;

    // Some mobile browsers only surface permission flow reliably via Push subscribe.
    final pushReady = await _ensurePushSubscription(promptUser: true);
    permission = js_util.getProperty(notificationApi, 'permission')?.toString();
    if (pushReady || permission == 'granted') {
      return true;
    }

    final result = js_util.callMethod(notificationApi, 'requestPermission', <dynamic>[]);
    bool granted = false;
    if (result != null && js_util.hasProperty(result, 'then')) {
      final resolved = await js_util.promiseToFuture<Object?>(result);
      granted = resolved?.toString() == 'granted';
    } else {
      granted = result?.toString() == 'granted';
    }

    if (granted) {
      final hasPushReady = await _ensurePushSubscription(promptUser: false);
      final client = _pushClient;
      if (client != null && js_util.hasProperty(client, 'test')) {
        return hasPushReady;
      }
    }
    return granted;
  }

  @override
  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    if (!await checkPermissions()) return;
    var localShown = false;
    try {
      html.Notification(title, body: body);
      localShown = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Web instant notification failed: $e');
      }
    }

    final client = _pushClient;
    if (client == null || !js_util.hasProperty(client, 'test')) return;

    final result = await _callPushClientWithResult('test', <dynamic>[title, body]);
    if (result == null && !localShown) {
      throw StateError('Web push test request failed.');
    }
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
      final lateness = DateTime.now().difference(scheduledTime);
      if (lateness > _maxLocalFallbackLateness) {
        _timers.remove(id);
        return;
      }

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
