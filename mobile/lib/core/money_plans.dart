import 'entry_store.dart';
import 'local_store.dart';
import 'reminders.dart';

const budgetsKey = 'monova.budgets';
const goalsKey = 'monova.goals';
const recurringKey = 'monova.recurring';

/// The month as "2026-11", used to know which months a recurring entry has already created.
String monthKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// A monthly spending limit for one category, for example Food: 8,000 a month.
class Budget {
  const Budget({required this.id, required this.category, required this.limitCents});

  final String id;
  final String category;
  final int limitCents;

  Budget copyWith({String? category, int? limitCents}) => Budget(id: id, category: category ?? this.category, limitCents: limitCents ?? this.limitCents);

  Map<String, dynamic> toJson() => {'id': id, 'category': category, 'limitCents': limitCents};

  factory Budget.fromJson(Map<String, dynamic> j) => Budget(
        id: '${j['id']}',
        category: '${j['category'] ?? 'Other'}',
        limitCents: (j['limitCents'] as num?)?.toInt() ?? 0,
      );
}

enum BudgetState { ok, nearLimit, over }

class BudgetStatus {
  const BudgetStatus({required this.spentCents, required this.limitCents});

  final int spentCents;
  final int limitCents;

  int get remainingCents => limitCents - spentCents;

  /// Share of the limit used, from 0 upwards (above 1 means over budget).
  double get used => limitCents <= 0 ? 0 : spentCents / limitCents;

  BudgetState get state {
    if (spentCents > limitCents) return BudgetState.over;
    if (used >= 0.8) return BudgetState.nearLimit;
    return BudgetState.ok;
  }
}

/// Spending in [category] during [year]-[month], from finance entries. Income is never counted.
int spentInCategory(List<MoneyEntry> entries, String category, int year, int month) {
  var total = 0;
  for (final e in entries) {
    if (e.income || e.category != category) continue;
    if (e.date.year != year || e.date.month != month) continue;
    total += e.cents;
  }
  return total;
}

/// A savings goal: the target, and how much has been put aside so far.
class SavingsGoal {
  const SavingsGoal({required this.id, required this.name, required this.targetCents, this.savedCents = 0, this.dueDate});

  final String id;
  final String name;
  final int targetCents;
  final int savedCents;
  final DateTime? dueDate;

  bool get reached => savedCents >= targetCents;
  int get remainingCents => targetCents - savedCents < 0 ? 0 : targetCents - savedCents;
  double get progress => targetCents <= 0 ? 0 : (savedCents / targetCents).clamp(0.0, 1.0);

  /// Adds money to the goal (negative to take some out). Never goes below zero.
  SavingsGoal withContribution(int cents) {
    final next = savedCents + cents;
    return SavingsGoal(id: id, name: name, targetCents: targetCents, savedCents: next < 0 ? 0 : next, dueDate: dueDate);
  }

  SavingsGoal copyWith({String? name, int? targetCents, DateTime? dueDate}) => SavingsGoal(
        id: id,
        name: name ?? this.name,
        targetCents: targetCents ?? this.targetCents,
        savedCents: savedCents,
        dueDate: dueDate ?? this.dueDate,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetCents': targetCents,
        'savedCents': savedCents,
        'dueDate': dueDate?.toIso8601String(),
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> j) => SavingsGoal(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        targetCents: (j['targetCents'] as num?)?.toInt() ?? 0,
        savedCents: (j['savedCents'] as num?)?.toInt() ?? 0,
        dueDate: DateTime.tryParse('${j['dueDate']}'),
      );
}

/// A bill or income that comes every month, for example house rent or a salary.
class RecurringEntry {
  const RecurringEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.cents,
    required this.income,
    required this.dayOfMonth,
    required this.startDate,
    this.lastCreatedMonth = '',
  });

  final String id;
  final String title;
  final String category;
  final int cents;
  final bool income;

  /// Day of the month it falls due, 1 to 28 (so every month has that day).
  final int dayOfMonth;
  final DateTime startDate;

  /// The last month ("2026-11") whose entry has been created. Empty before the first one.
  final String lastCreatedMonth;

  RecurringEntry copyWith({String? title, String? category, int? cents, bool? income, int? dayOfMonth, DateTime? startDate, String? lastCreatedMonth}) =>
      RecurringEntry(
        id: id,
        title: title ?? this.title,
        category: category ?? this.category,
        cents: cents ?? this.cents,
        income: income ?? this.income,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        startDate: startDate ?? this.startDate,
        lastCreatedMonth: lastCreatedMonth ?? this.lastCreatedMonth,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'cents': cents,
        'income': income,
        'dayOfMonth': dayOfMonth,
        'startDate': startDate.toIso8601String(),
        'lastCreatedMonth': lastCreatedMonth,
      };

  factory RecurringEntry.fromJson(Map<String, dynamic> j) => RecurringEntry(
        id: '${j['id']}',
        title: '${j['title'] ?? ''}',
        category: '${j['category'] ?? 'Other'}',
        cents: (j['cents'] as num?)?.toInt() ?? 0,
        income: j['income'] == true,
        dayOfMonth: ((j['dayOfMonth'] as num?)?.toInt() ?? 1).clamp(1, 28),
        startDate: DateTime.tryParse('${j['startDate']}') ?? DateTime.now(),
        lastCreatedMonth: '${j['lastCreatedMonth'] ?? ''}',
      );
}

/// Creates the finance entries for recurring items that have fallen due by [today] and do not exist yet.
/// Each month's entry has a fixed id, so running this again (or after a restore) never creates a duplicate.
/// Returns the new entries and the recurring items with their last created month updated.
(List<MoneyEntry>, List<RecurringEntry>) generateRecurringEntries(List<RecurringEntry> items, DateTime today) {
  final created = <MoneyEntry>[];
  final updated = <RecurringEntry>[];
  final todayMonth = DateTime(today.year, today.month);
  for (final r in items) {
    var month = r.lastCreatedMonth.isEmpty
        ? DateTime(r.startDate.year, r.startDate.month)
        : DateTime(int.parse(r.lastCreatedMonth.substring(0, 4)), int.parse(r.lastCreatedMonth.substring(5, 7)) + 1);
    var last = r.lastCreatedMonth;
    while (!month.isAfter(todayMonth)) {
      final lastDay = DateTime(month.year, month.month + 1, 0).day;
      final dueDate = DateTime(month.year, month.month, r.dayOfMonth > lastDay ? lastDay : r.dayOfMonth);
      if (dueDate.isAfter(today) || dueDate.isBefore(DateTime(r.startDate.year, r.startDate.month, r.startDate.day))) {
        month = DateTime(month.year, month.month + 1);
        continue;
      }
      final key = monthKey(month);
      created.add(MoneyEntry(
        id: 'rec-${r.id}-$key',
        income: r.income,
        title: r.title,
        category: r.category,
        cents: r.cents,
        date: dueDate,
        notes: 'Repeats every month',
      ));
      last = key;
      month = DateTime(month.year, month.month + 1);
    }
    updated.add(r.copyWith(lastCreatedMonth: last));
  }
  return (created, updated);
}

/// Adds the entries that are not already saved (by id). Returns the combined list.
List<MoneyEntry> addMissingEntries(List<MoneyEntry> saved, List<MoneyEntry> created) {
  final ids = {for (final e in saved) e.id};
  return [...saved, for (final e in created) if (ids.add(e.id)) e];
}

class PlansStore {
  PlansStore._();

  static Future<List<Budget>> loadBudgets() async {
    final store = await LocalStore.open();
    return [for (final m in store.readList(budgetsKey)) Budget.fromJson(m)];
  }

  static Future<void> saveBudgets(List<Budget> list) async {
    final store = await LocalStore.open();
    await store.writeList(budgetsKey, [for (final b in list) b.toJson()]);
  }

  static Future<List<SavingsGoal>> loadGoals() async {
    final store = await LocalStore.open();
    return [for (final m in store.readList(goalsKey)) SavingsGoal.fromJson(m)];
  }

  static Future<void> saveGoals(List<SavingsGoal> list) async {
    final store = await LocalStore.open();
    await store.writeList(goalsKey, [for (final g in list) g.toJson()]);
  }

  static Future<List<RecurringEntry>> loadRecurring() async {
    final store = await LocalStore.open();
    return [for (final m in store.readList(recurringKey)) RecurringEntry.fromJson(m)];
  }

  static Future<void> saveRecurring(List<RecurringEntry> list) async {
    final store = await LocalStore.open();
    await store.writeList(recurringKey, [for (final r in list) r.toJson()]);
    await syncRecurringReminders(list);
  }

  /// Creates any recurring entries that are due, saves them to Monova Finance, and remembers the months done.
  /// Safe to call often: nothing is created twice.
  static Future<int> runRecurring(DateTime today) async {
    final items = await loadRecurring();
    if (items.isEmpty) return 0;
    final (created, updated) = generateRecurringEntries(items, today);
    if (created.isNotEmpty) {
      final saved = await EntryStore.loadEntries();
      await EntryStore.saveEntries(addMissingEntries(saved, created));
    }
    await saveRecurring(updated);
    return created.length;
  }
}

/// Reminder for a recurring bill or income: due on its day each month, at 9 in the morning.
/// It is the next occurrence from [today], so a bill whose day has passed this month shows next month.
Reminder recurringReminder(RecurringEntry r, DateTime today) {
  final thisLast = DateTime(today.year, today.month + 1, 0).day;
  var due = DateTime(today.year, today.month, r.dayOfMonth > thisLast ? thisLast : r.dayOfMonth, 9);
  if (due.isBefore(today)) {
    final next = DateTime(today.year, today.month + 1);
    final nextLast = DateTime(next.year, next.month + 1, 0).day;
    due = DateTime(next.year, next.month, r.dayOfMonth > nextLast ? nextLast : r.dayOfMonth, 9);
  }
  final amount = 'Rs ${(r.cents / 100).toStringAsFixed(0)}';
  return Reminder(
    id: 'rec-rem-${r.id}',
    title: '${r.income ? 'Expected' : 'Pay'} ${r.title}: $amount',
    notes: 'Every month, on day ${r.dayOfMonth}.',
    dueAt: due,
    createdAt: today,
    repeat: 'monthly',
    route: '/plans',
  );
}

/// One monthly reminder per recurring item. Replaces the old ones, so changes take effect at once.
Future<void> syncRecurringReminders(List<RecurringEntry> items, {DateTime? now}) async {
  final today = now ?? DateTime.now();
  final reminders = await ReminderStore.load();
  final kept = [for (final r in reminders) if (!r.id.startsWith('rec-rem-')) r];
  await ReminderStore.save([...kept, for (final r in items) recurringReminder(r, today)]);
}
