import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/entry_store.dart';

void main() {
  final entries = [
    MoneyEntry(id: '1', income: true, title: 'Salary', category: 'Salary', cents: 5000000, date: DateTime(2026, 11, 1)),
    MoneyEntry(id: '2', income: false, title: 'Rent', category: 'Housing', cents: 1500000, date: DateTime(2026, 11, 2)),
    MoneyEntry(id: '3', income: false, title: 'Groceries, weekly', category: 'Groceries', cents: 250050, date: DateTime(2026, 11, 9), notes: 'say "fresh"'),
    MoneyEntry(id: '4', income: false, title: 'Old bill', category: 'Utilities', cents: 90000, date: DateTime(2026, 10, 30)),
  ];

  test('monthly totals count only that month, in whole paise', () {
    final s = monthSummary(entries, 2026, 11);
    expect(s.income, 5000000);
    expect(s.spent, 1500000 + 250050);
    expect(s.savings, 5000000 - 1750050);
  });

  test('spending by category is largest first and skips income', () {
    final list = spendingByCategory(entries, 2026, 11);
    expect(list.first.key, 'Housing');
    expect(list.any((e) => e.key == 'Salary'), isFalse);
  });

  test('CSV quotes fields that contain commas or quotes', () {
    final csv = entriesToCsv(entries);
    expect(csv.split('\n').first, 'date,type,category,title,amount,notes');
    expect(csv, contains('"Groceries, weekly"'));
    expect(csv, contains('"say ""fresh"""'));
    expect(csv, contains('2026-11-01,income,Salary,Salary,50000.00,'));
  });

  test('warranty end date and return deadline follow the purchase date', () {
    final p = Purchase(id: 'p', name: 'Fan', retailer: 'Store', cents: 400000, date: DateTime(2026, 1, 31), warrantyMonths: 12, returnDays: 10);
    expect(p.warrantyUntil, DateTime(2027, 1, 31));
    expect(p.returnBy, DateTime(2026, 2, 10));
    final none = Purchase(id: 'q', name: 'Pen', retailer: '', cents: 1000, date: DateTime(2026, 1, 1));
    expect(none.warrantyUntil, isNull);
  });

  test('only warranties still running today are listed, soonest first', () {
    final today = DateTime(2026, 6, 1);
    final list = openWarranties([
      Purchase(id: 'old', name: 'Old', retailer: '', cents: 1, date: DateTime(2024, 1, 1), warrantyMonths: 12),
      Purchase(id: 'late', name: 'Late', retailer: '', cents: 1, date: DateTime(2026, 2, 1), warrantyMonths: 24),
      Purchase(id: 'soon', name: 'Soon', retailer: '', cents: 1, date: DateTime(2025, 9, 1), warrantyMonths: 12),
    ], today);
    expect(list.map((p) => p.id), ['soon', 'late']);
  });

  test('an entry survives a JSON round trip', () {
    final back = MoneyEntry.fromJson(entries[2].toJson());
    expect(back.title, 'Groceries, weekly');
    expect(back.cents, 250050);
    expect(back.notes, 'say "fresh"');
  });
}
