import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/money_plans.dart';

void main() {
  final rent = RecurringEntry(id: 'r', title: 'House rent', category: 'Housing', cents: 1200000, income: false, dayOfMonth: 5, startDate: DateTime(2026, 1, 1));

  test('a monthly bill that is still to come this month reminds on its day this month', () {
    final r = recurringReminder(rent, DateTime(2026, 11, 2));
    expect(r.dueAt, DateTime(2026, 11, 5, 9));
    expect(r.repeats, isTrue);
    expect(r.title, contains('Pay House rent'));
  });

  test('once the day has passed this month, the reminder is for next month', () {
    final r = recurringReminder(rent, DateTime(2026, 11, 27));
    expect(r.dueAt, DateTime(2026, 12, 5, 9));
  });

  test('a day past the end of a short month reminds on its last day', () {
    final late = RecurringEntry(id: 'l', title: 'Wi-Fi', category: 'Internet', cents: 79900, income: false, dayOfMonth: 28, startDate: DateTime(2026, 1, 1));
    expect(recurringReminder(late, DateTime(2026, 2, 1)).dueAt, DateTime(2026, 2, 28, 9));
  });
}
