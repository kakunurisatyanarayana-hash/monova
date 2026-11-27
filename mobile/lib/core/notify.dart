/// Phone notifications for reminders. The Android app schedules them; the web build shows no alerts.
export 'notify_stub.dart' if (dart.library.io) 'notify_mobile.dart';
