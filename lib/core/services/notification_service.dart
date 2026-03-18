import 'notification_service_mobile.dart'
    if (dart.library.html) 'notification_service_web.dart';
import 'notification_service_adapter.dart';

class NotificationService {
  static final NotificationServiceAdapter _adapter = createNotificationService();

  static Future<void> init() => _adapter.init();

  static Future<bool> checkPermissions() => _adapter.checkPermissions();

  static Future<void> showInstantNotification({
    required String title,
    required String body,
  }) => _adapter.showInstantNotification(title: title, body: body);

  static Future<void> scheduleTodoNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) => _adapter.scheduleTodoNotification(
    id: id,
    title: title,
    body: body,
    scheduledTime: scheduledTime,
  );

  static Future<void> cancelNotification(int id) =>
      _adapter.cancelNotification(id);
}
