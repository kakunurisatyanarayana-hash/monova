import 'entry_store.dart';
import 'local_store.dart';
import 'reminders.dart';

const sipPlansKey = 'monova.sip';

/// Finance entries and reminders made for SIPs start with these, so they can be kept in step.
const sipEntryPrefix = 'sip-';
const sipReminderPrefix = 'sip-rem-';

/// A monthly investment (SIP, recurring deposit, monthly savings) that is paid each month.
class SipPlan {
  const SipPlan({
    required this.id,
    required this.name,
    required this.monthlyCents,
    required this.dayOfMonth,
    required this.startDate,
    this.paidMonths = const [],
    this.currentValueCents,
  });

  final String id;
  final String name;

  /// The amount due each month, in paise.
  final int monthlyCents;

  /// Day of the month it is due, 1 to 28.
  final int dayOfMonth;
  final DateTime startDate;

  /// Months already paid, as "2026-11".
  final List<String> paidMonths;

  /// The value of the investment as the owner last noted it (optional, typed by hand).
  final int? currentValueCents;

  int get investedCents => paidMonths.length * monthlyCents;

  SipPlan copyWith({
    String? name,
    int? monthlyCents,
    int? dayOfMonth,
    DateTime? startDate,
    List<String>? paidMonths,
    int? currentValueCents,
    bool clearValue = false,
  }) => SipPlan(
    id: id,
    name: name ?? this.name,
    monthlyCents: monthlyCents ?? this.monthlyCents,
    dayOfMonth: dayOfMonth ?? this.dayOfMonth,
    startDate: startDate ?? this.startDate,
    paidMonths: paidMonths ?? this.paidMonths,
    currentValueCents: clearValue
        ? null
        : (currentValueCents ?? this.currentValueCents),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'monthlyCents': monthlyCents,
    'dayOfMonth': dayOfMonth,
    'startDate': startDate.toIso8601String(),
    'paidMonths': paidMonths,
    'currentValueCents': currentValueCents,
  };

  factory SipPlan.fromJson(Map<String, dynamic> j) => SipPlan(
    id: '${j['id']}',
    name: '${j['name'] ?? ''}',
    monthlyCents: (j['monthlyCents'] as num?)?.toInt() ?? 0,
    dayOfMonth: ((j['dayOfMonth'] as num?)?.toInt() ?? 1).clamp(1, 28),
    startDate: DateTime.tryParse('${j['startDate']}') ?? DateTime.now(),
    paidMonths: [
      for (final m in (j['paidMonths'] as List<dynamic>? ?? const [])) '$m',
    ],
    currentValueCents: (j['currentValueCents'] as num?)?.toInt(),
  );
}

String monthKeyOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// The date a month's payment is due.
DateTime dueDateFor(SipPlan p, int year, int month) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, p.dayOfMonth > lastDay ? lastDay : p.dayOfMonth);
}

/// Months whose payment has fallen due by [today], from the start month to this month.
List<String> monthsDue(SipPlan p, DateTime today) {
  final out = <String>[];
  final day = DateTime(today.year, today.month, today.day);
  var m = DateTime(p.startDate.year, p.startDate.month);
  final last = DateTime(today.year, today.month);
  while (!m.isAfter(last)) {
    final due = dueDateFor(p, m.year, m.month);
    if (!due.isAfter(day) &&
        !due.isBefore(
          DateTime(p.startDate.year, p.startDate.month, p.startDate.day),
        )) {
      out.add(monthKeyOf(m));
    }
    m = DateTime(m.year, m.month + 1);
  }
  return out;
}

enum SipState { paid, pending, overdue, notYet }

/// Where this month's payment stands: paid, due and unpaid, overdue (an earlier month unpaid), or not due yet.
SipState sipStateFor(SipPlan p, DateTime today) {
  final key = monthKeyOf(today);
  if (p.paidMonths.contains(key)) return SipState.paid;
  final due = dueDateFor(p, today.year, today.month);
  final day = DateTime(today.year, today.month, today.day);
  if (due.isAfter(day)) return SipState.notYet;
  return SipState.pending;
}

/// Months that were due but not paid, before this month.
List<String> missedMonths(SipPlan p, DateTime today) {
  final key = monthKeyOf(today);
  return [
    for (final m in monthsDue(p, today))
      if (m != key && !p.paidMonths.contains(m)) m,
  ];
}

/// The total still unpaid across all due months, in paise.
int pendingCents(SipPlan p, DateTime today) {
  final unpaid = [
    for (final m in monthsDue(p, today))
      if (!p.paidMonths.contains(m)) m,
  ];
  return unpaid.length * p.monthlyCents;
}

/// A finance entry for each paid month, so Monova Finance shows the money going out.
List<MoneyEntry> sipFinanceEntries(List<SipPlan> plans) {
  return [
    for (final p in plans)
      for (final m in p.paidMonths)
        MoneyEntry(
          id: '$sipEntryPrefix${p.id}-$m',
          income: false,
          title: 'SIP: ${p.name}',
          category: 'Savings & SIP',
          cents: p.monthlyCents,
          date: DateTime(
            int.parse(m.substring(0, 4)),
            int.parse(m.substring(5, 7)),
            p.dayOfMonth,
          ),
          notes: 'Paid for $m',
        ),
  ];
}

/// Keeps the SIP entries in [entries] in line with [plans]: adds, updates and removes only SIP entries.
List<MoneyEntry> mergeSipEntries(
  List<MoneyEntry> entries,
  List<SipPlan> plans,
) {
  final wanted = {for (final e in sipFinanceEntries(plans)) e.id: e};
  final kept = <MoneyEntry>[
    for (final e in entries)
      if (!e.id.startsWith(sipEntryPrefix))
        e
      else if (wanted.containsKey(e.id))
        wanted[e.id]!,
  ];
  final existing = {for (final e in entries) e.id};
  return [
    ...kept,
    for (final e in wanted.values)
      if (!existing.contains(e.id)) e,
  ];
}

/// The monthly reminder for a plan: it repeats each month on the due day, at 9 in the morning.
Reminder sipReminder(SipPlan p, {DateTime? now}) => Reminder(
  id: '$sipReminderPrefix${p.id}',
  title: 'Pay ${p.name}: ${_rupeesText(p.monthlyCents)}',
  notes: 'Monthly investment due on day ${p.dayOfMonth}.',
  dueAt: DateTime(
    (now ?? DateTime.now()).year,
    (now ?? DateTime.now()).month,
    p.dayOfMonth,
    9,
  ),
  createdAt: now ?? DateTime.now(),
  repeat: 'monthly',
  route: '/sip',
);

String _rupeesText(int cents) => 'Rs ${(cents / 100).toStringAsFixed(0)}';

class SipStore {
  SipStore._();

  static Future<List<SipPlan>> load() async {
    final store = await LocalStore.open();
    return [for (final m in store.readList(sipPlansKey)) SipPlan.fromJson(m)];
  }

  /// Saves the plans, keeps Monova Finance in step, and keeps one monthly reminder per plan.
  static Future<void> save(List<SipPlan> plans) async {
    final store = await LocalStore.open();
    await store.writeList(sipPlansKey, [for (final p in plans) p.toJson()]);
    final entries = await EntryStore.loadEntries();
    await EntryStore.saveEntries(mergeSipEntries(entries, plans));
    final reminders = await ReminderStore.load();
    final kept = [
      for (final r in reminders)
        if (!r.id.startsWith(sipReminderPrefix)) r,
    ];
    await ReminderStore.save([...kept, for (final p in plans) sipReminder(p)]);
  }
}
