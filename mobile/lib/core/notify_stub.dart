import 'reminders.dart';

/// Web and other builds without phone notifications: nothing is scheduled.
Future<void> initReminderAlerts() async {}

/// Asks for permission to show notifications. Returns false where notifications are not available.
Future<bool> requestReminderAlertPermission() async => false;

/// Whether this build can show phone notifications at all.
bool get reminderAlertsSupported => false;

/// Schedules the reminder. Nothing happens in this build.
Future<void> scheduleReminderAlert(Reminder r) async {}

Future<void> cancelReminderAlert(Reminder r) async {}
