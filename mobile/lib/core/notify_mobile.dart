import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminders.dart';

const _channelId = 'monova_reminders';
const _channelName = 'Reminders';
const _channelDescription =
    'Bills, warranties, rent and other reminders you set in MONOVA';

/// This app is used in India, so reminder times are read in Indian time.
const _zone = 'Asia/Kolkata';

final _plugin = FlutterLocalNotificationsPlugin();
bool _ready = false;

Future<void> initReminderAlerts() async {
  if (_ready) return;
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation(_zone));
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _plugin.initialize(
    settings: const InitializationSettings(android: android),
  );
  _ready = true;
}

bool get reminderAlertsSupported => true;

/// Asks Android for permission to post notifications (Android 13 and newer). Returns whether it was granted.
Future<bool> requestReminderAlertPermission() async {
  await initReminderAlerts();
  final android = _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  return (await android?.requestNotificationsPermission()) ?? false;
}

int _notificationId(String reminderId) => reminderId.hashCode & 0x7fffffff;

Future<void> cancelReminderAlert(Reminder r) async {
  await initReminderAlerts();
  await _plugin.cancel(id: _notificationId(r.id));
}

/// Schedules the reminder for its due time. Safe to call again after any change: the old alert is replaced.
/// Alerts are inexact, so they need no special alarm permission and may arrive a few minutes late.
Future<void> scheduleReminderAlert(Reminder r) async {
  await initReminderAlerts();
  await cancelReminderAlert(r);
  if (r.done || !r.dueAt.isAfter(DateTime.now())) return;
  await _plugin.zonedSchedule(
    id: _notificationId(r.id),
    title: r.title,
    body: r.notes.isEmpty ? 'Reminder from MONOVA' : r.notes,
    scheduledDate: tz.TZDateTime.from(r.dueAt, tz.local),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );
}
