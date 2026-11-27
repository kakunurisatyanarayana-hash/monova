import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/entry_store.dart';
import 'package:monova_app/core/loans.dart';
import 'package:monova_app/core/monthly_report.dart';
import 'package:monova_app/core/money_plans.dart';
import 'package:monova_app/core/property_store.dart';

void main() {
  final entries = [
    MoneyEntry(id: '1', income: true, title: 'Salary', category: 'Salary', cents: 5000000, date: DateTime(2026, 11, 1)),
    MoneyEntry(id: '2', income: false, title: 'Rent', category: 'Housing', cents: 1500000, date: DateTime(2026, 11, 2)),
    MoneyEntry(id: '3', income: false, title: 'Lunch', category: 'Food', cents: 250000, date: DateTime(2026, 11, 9)),
    MoneyEntry(id: '4', income: false, title: 'Dinner', category: 'Food', cents: 150000, date: DateTime(2026, 11, 20)),
    MoneyEntry(id: '5', income: false, title: 'Old', category: 'Food', cents: 90000, date: DateTime(2026, 10, 30)),
  ];

  test('the monthly totals and categories count only that month, largest category first', () {
    final r = buildMonthlyReport(
      year: 2026,
      month: 11,
      entries: entries,
      budgets: const [Budget(id: 'b', category: 'Food', limitCents: 300000)],
      loans: const [],
      book: const PropertyBook(),
    );
    expect(r.moneyIn, 5000000);
    expect(r.moneyOut, 1900000);
    expect(r.leftOver, 3100000);
    expect(r.categories.map((c) => c.category), ['Housing', 'Food']);
    expect(r.categories.last.cents, 400000);
    expect(r.budgets.single.spentCents, 400000);
    expect(r.budgets.single.spentCents > r.budgets.single.limitCents, isTrue, reason: 'Food is over its Rs 3,000 budget');
  });

  test('loans and property figures are included', () {
    final loan = Loan(id: 'l', name: 'Bank', kind: 'emi', principalCents: 10000000, startDate: DateTime(2026, 1, 5), annualRatePercent: 12, months: 12);
    final r = buildMonthlyReport(year: 2026, month: 11, entries: entries, budgets: const [], loans: [loan], book: const PropertyBook());
    expect(r.loansOutstanding, 10000000);
    expect(r.loansEachMonth, closeTo(888488, 2));
    expect(r.rentCollected, 0);
  });

  test('the PDF is a real PDF file with content', () async {
    final r = buildMonthlyReport(year: 2026, month: 11, entries: entries, budgets: const [], loans: const [], book: const PropertyBook());
    final Uint8List bytes = await monthlyReportPdf(r, generatedOn: DateTime(2026, 11, 27));
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });
}
