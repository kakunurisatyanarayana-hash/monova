import 'local_store.dart';

const remindersKey = 'monova.reminders';

/// How a reminder repeats after it is marked done.
const reminderRepeats = <String>['none', 'monthly', 'yearly'];

/// A reminder for a bill, warranty, rent, renewal or anything else with a date.
/// [route] is the page to open from the reminder (empty for a plain reminder).
class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    required this.dueAt,
    required this.createdAt,
    this.notes = '',
    this.repeat = 'none',
    this.route = '',
    this.done = false,
  });

  final String id;
  final String title;
  final String notes;

  /// Local date and time the reminder is due.
  final DateTime dueAt;
  final String repeat;
  final String route;
  final bool done;
  final DateTime createdAt;

  bool get repeats => repeat != 'none';

  /// True when the due time has passed and the reminder is not done.
  bool isOverdue(DateTime now) => !done && dueAt.isBefore(now);

  /// True when the reminder is due today (or already overdue).
  bool isDueToday(DateTime now) {
    final endOfToday = DateTime(now.year, now.month, now.day + 1);
    return !done && dueAt.isBefore(endOfToday);
  }

  Reminder copyWith({
    String? title,
    String? notes,
    DateTime? dueAt,
    String? repeat,
    String? route,
    bool? done,
  }) => Reminder(
    id: id,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    dueAt: dueAt ?? this.dueAt,
    repeat: repeat ?? this.repeat,
    route: route ?? this.route,
    done: done ?? this.done,
    createdAt: createdAt,
  );

  /// The reminder moved to its next occurrence, still not done. Only meaningful for repeating reminders.
  Reminder advanced() {
    final next = switch (repeat) {
      'monthly' => addMonths(dueAt, 1),
      'yearly' => addMonths(dueAt, 12),
      _ => dueAt,
    };
    return copyWith(dueAt: next, done: false);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'notes': notes,
    'dueAt': dueAt.toIso8601String(),
    'repeat': repeat,
    'route': route,
    'done': done,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
    id: '${j['id']}',
    title: '${j['title'] ?? ''}',
    notes: '${j['notes'] ?? ''}',
    dueAt: DateTime.tryParse('${j['dueAt']}') ?? DateTime.now(),
    repeat: reminderRepeats.contains(j['repeat']) ? '${j['repeat']}' : 'none',
    route: '${j['route'] ?? ''}',
    done: j['done'] == true,
    createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
  );
}

/// Adds months to a date, keeping the time. A date past the end of the target month (31 January + 1 month) stops at its last day.
DateTime addMonths(DateTime d, int months) {
  final total = d.month - 1 + months;
  final year = d.year + total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = d.day > lastDay ? lastDay : d.day;
  return DateTime(year, month, day, d.hour, d.minute);
}

/// Reminders that need a look now: not done, and due within [upcomingDays] days (overdue ones included), soonest first.
List<Reminder> remindersNeedingAttention(
  List<Reminder> all,
  DateTime now, {
  int upcomingDays = 3,
}) {
  final horizon = DateTime(now.year, now.month, now.day + upcomingDays + 1);
  final list = [
    for (final r in all)
      if (!r.done && r.dueAt.isBefore(horizon)) r,
  ]..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  return list;
}

class ReminderStore {
  ReminderStore._();

  static Future<List<Reminder>> load() async {
    final store = await LocalStore.open();
    return [for (final m in store.readList(remindersKey)) Reminder.fromJson(m)];
  }

  static Future<void> save(List<Reminder> reminders) async {
    final store = await LocalStore.open();
    await store.writeList(remindersKey, [
      for (final r in reminders) r.toJson(),
    ]);
  }
}
