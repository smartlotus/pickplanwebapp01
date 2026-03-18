abstract class NotificationServiceAdapter {
  Future<void> init();
  Future<bool> checkPermissions();
  Future<void> showInstantNotification({
    required String title,
    required String body,
  });
  Future<void> scheduleTodoNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  });
  Future<void> cancelNotification(int id);
}
