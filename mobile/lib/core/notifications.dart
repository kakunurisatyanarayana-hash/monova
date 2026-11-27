// In-app notifications: complaint updates, rent and payment reminders, announcements. Kept on the phone.
// Pure Dart; storage is in notification_store.dart.
//
// What this is not: a push to another person's phone. Delivery to another device needs a shared service,
// which is not part of the offline app. Notifications here appear on the device where the record lives.

enum NotificationKind { complaint, rentDue, paymentDue, announcement, system }

String notificationKindLabel(NotificationKind k) => switch (k) {
      NotificationKind.complaint => 'Complaint',
      NotificationKind.rentDue => 'Rent due',
      NotificationKind.paymentDue => 'Payment due',
      NotificationKind.announcement => 'Announcement',
      NotificationKind.system => 'Monova',
    };

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.route = '',
    this.readAt,
    this.snoozedUntil,
    this.dismissed = false,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;

  /// Where tapping the notification leads, for example /property/abc/complaints. Empty when there is nowhere to go.
  final String route;
  final DateTime? readAt;

  /// Hidden from the list until this time has passed.
  final DateTime? snoozedUntil;
  final bool dismissed;

  bool get isRead => readAt != null;

  /// Shown in the centre right now: not dismissed, and not snoozed into the future.
  bool visibleAt(DateTime now) => !dismissed && (snoozedUntil == null || !snoozedUntil!.isAfter(now));

  AppNotification copyWith({DateTime? readAt, DateTime? snoozedUntil, bool? dismissed, bool clearSnooze = false}) => AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        createdAt: createdAt,
        route: route,
        readAt: readAt ?? this.readAt,
        snoozedUntil: clearSnooze ? null : (snoozedUntil ?? this.snoozedUntil),
        dismissed: dismissed ?? this.dismissed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'route': route,
        'readAt': readAt?.toIso8601String(),
        'snoozedUntil': snoozedUntil?.toIso8601String(),
        'dismissed': dismissed,
      };

  static AppNotification? fromJson(Map<String, dynamic> j) {
    final created = DateTime.tryParse('${j['createdAt']}');
    final kind = NotificationKind.values.where((k) => k.name == '${j['kind']}').firstOrNull;
    if (created == null || kind == null) return null;
    return AppNotification(
      id: '${j['id']}',
      kind: kind,
      title: '${j['title']}',
      body: '${j['body']}',
      createdAt: created,
      route: '${j['route'] ?? ''}',
      readAt: DateTime.tryParse('${j['readAt']}'),
      snoozedUntil: DateTime.tryParse('${j['snoozedUntil']}'),
      dismissed: j['dismissed'] == true,
    );
  }
}

/// Adds a notification unless one with the same id exists. Repeated events (for example a reminder recomputed on
/// every open) therefore appear once.
List<AppNotification> addNotification(List<AppNotification> all, AppNotification n) {
  if (all.any((x) => x.id == n.id)) return all;
  return [n, ...all];
}

/// The notifications to show now: newest first, without dismissed or snoozed ones.
List<AppNotification> visibleNotifications(List<AppNotification> all, DateTime now) {
  final out = [for (final n in all) if (n.visibleAt(now)) n];
  out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return out;
}

int unreadCount(List<AppNotification> all, DateTime now) => [for (final n in visibleNotifications(all, now)) if (!n.isRead) n].length;

/// Replaces one notification by id. Other notifications are left as they are.
List<AppNotification> updateNotification(List<AppNotification> all, String id, AppNotification Function(AppNotification) change) =>
    [for (final n in all) n.id == id ? change(n) : n];

/// Keeps the list from growing without limit: dismissed items beyond the newest 200 are dropped.
List<AppNotification> trimNotifications(List<AppNotification> all) {
  if (all.length <= 200) return all;
  final kept = [...all]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return kept.take(200).toList();
}

/// A rent or payment reminder for the given day, with a stable id so it is added only once per due date.
AppNotification dueReminder({required NotificationKind kind, required String personId, required String name, required String amount, required DateTime dueOn}) {
  final day = '${dueOn.year}-${dueOn.month.toString().padLeft(2, '0')}-${dueOn.day.toString().padLeft(2, '0')}';
  final label = kind == NotificationKind.rentDue ? 'Rent due' : 'Payment due';
  return AppNotification(
    id: '${kind.name}|$personId|$day',
    kind: kind,
    title: '$label: $name',
    body: '$amount due on $day. Send a reminder on WhatsApp if you want to.',
    createdAt: dueOn,
  );
}
