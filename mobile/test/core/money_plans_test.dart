import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/entry_store.dart';
import 'package:monova_app/core/money_plans.dart';

void main() {
  test('a budget warns at 80 percent and is over once spending passes the limit', () {
    expect(BudgetStatus(spentCents: 7000, limitCents: 10000).state, BudgetState.ok);
    expect(BudgetStatus(spentCents: 8000, limitCents: 10000).state, BudgetState.nearLimit);
    expect(BudgetStatus(spentCents: 10000, limitCents: 10000).state, BudgetState.nearLimit);
    expect(BudgetStatus(spentCents: 10001, limitCents: 10000).state, BudgetState.over);
    expect(BudgetStatus(spentCents: 12000, limitCents: 10000).remainingCents, -2000);
  });

  test('only that category, in that month, and only spending is counted', () {
    final entries = [
      MoneyEntry(id: '1', income: false, title: 'Lunch', category: 'Food', cents: 50000, date: DateTime(2026, 11, 3)),
      MoneyEntry(id: '2', income: false, title: 'Rent', category: 'Housing', cents: 900000, date: DateTime(2026, 11, 3)),
      MoneyEntry(id: '3', income: false, title: 'Dinner', category: 'Food', cents: 20000, date: DateTime(2026, 10, 30)),
      MoneyEntry(id: '4', income: true, title: 'Refund', category: 'Food', cents: 5000, date: DateTime(2026, 11, 4)),
    ];
    expect(spentInCategory(entries, 'Food', 2026, 11), 50000);
  });

  test('a savings goal grows with contributions, never below zero, and reports progress', () {
    final g = const SavingsGoal(id: 'g', name: 'Bike', targetCents: 100000).withContribution(25000).withContribution(25000);
    expect(g.savedCents, 50000);
    expect(g.progress, closeTo(0.5, 1e-9));
    expect(g.withContribution(-80000).savedCents, 0);
    expect(g.withContribution(60000).reached, isTrue);
  });

  test('a monthly recurring entry is created once for each month that is due, and never again', () {
    final rent = RecurringEntry(id: 'rent', title: 'House rent', category: 'Housing', cents: 1200000, income: false, dayOfMonth: 5, startDate: DateTime(2026, 9, 1));
    final (first, updated) = generateRecurringEntries([rent], DateTime(2026, 11, 27));
    // September, October and November have all fallen due (the 5th of each month has passed).
    expect(first.map((e) => e.id), ['rec-rent-2026-09', 'rec-rent-2026-10', 'rec-rent-2026-11']);
    expect(first.every((e) => e.cents == 1200000 && !e.income), isTrue);
    expect(updated.single.lastCreatedMonth, '2026-11');

    // Running it again on the same day creates nothing.
    final (second, _) = generateRecurringEntries(updated, DateTime(2026, 11, 27));
    expect(second, isEmpty);

    // Next month adds exactly one.
    final (third, _) = generateRecurringEntries(updated, DateTime(2026, 12, 6));
    expect(third.map((e) => e.id), ['rec-rent-2026-12']);
  });

  test('a monthly entry due later this month waits until its day', () {
    final salary = RecurringEntry(id: 's', title: 'Salary', category: 'Salary', cents: 5000000, income: true, dayOfMonth: 28, startDate: DateTime(2026, 11, 1));
    final (before, _) = generateRecurringEntries([salary], DateTime(2026, 11, 27));
    expect(before, isEmpty);
    final (on, _) = generateRecurringEntries([salary], DateTime(2026, 11, 28));
    expect(on.single.income, isTrue);
    expect(on.single.date, DateTime(2026, 11, 28));
  });

  test('restoring or re-running never duplicates saved entries', () {
    final saved = [MoneyEntry(id: 'rec-rent-2026-11', income: false, title: 'House rent', category: 'Housing', cents: 1, date: DateTime(2026, 11, 5))];
    final created = [
      MoneyEntry(id: 'rec-rent-2026-11', income: false, title: 'House rent', category: 'Housing', cents: 1, date: DateTime(2026, 11, 5)),
      MoneyEntry(id: 'rec-rent-2026-12', income: false, title: 'House rent', category: 'Housing', cents: 1, date: DateTime(2026, 12, 5)),
    ];
    expect(addMissingEntries(saved, created).length, 2);
  });

  test('plans survive a save and reload', () {
    final r = RecurringEntry(id: 'x', title: 'Wi-Fi', category: 'Internet', cents: 79900, income: false, dayOfMonth: 12, startDate: DateTime(2026, 4, 12), lastCreatedMonth: '2026-10');
    final back = RecurringEntry.fromJson(r.toJson());
    expect(back.dayOfMonth, 12);
    expect(back.lastCreatedMonth, '2026-10');
    expect(SavingsGoal.fromJson(const SavingsGoal(id: 'g', name: 'Trip', targetCents: 5000, savedCents: 1200).toJson()).savedCents, 1200);
    expect(Budget.fromJson(const Budget(id: 'b', category: 'Food', limitCents: 800000).toJson()).limitCents, 800000);
  });
}
