import 'local_store.dart';
import 'notifications.dart';

/// Keeps the notification history on this phone.
class NotificationStore {
  NotificationStore._();

  static const _key = 'monova.notifications';

  static Future<List<AppNotification>> load() async {
    final store = await LocalStore.open();
    return [for (final m in store.readList(_key)) ?AppNotification.fromJson(m)];
  }

  static Future<void> save(List<AppNotification> list) async {
    final store = await LocalStore.open();
    await store.writeList(_key, [for (final n in trimNotifications(list)) n.toJson()]);
  }

  /// Adds one notification, keeping existing ones, and returns the updated list.
  static Future<List<AppNotification>> add(AppNotification n) async {
    final next = addNotification(await load(), n);
    await save(next);
    return next;
  }
}
