import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/credit_ledger.dart';

void main() {
  // Rs 1,000 lent on 1 Jan at 12% a year. Rs 500 is paid back on 31 Jan (30 days of interest).
  final account = CreditAccount(
    id: 'a',
    name: 'Ramesh',
    phone: '',
    annualRatePercent: 12,
    compound: false,
    bills: [
      CreditBill(id: 'b', date: DateTime(2026, 1, 1), billerName: 'Ramesh', description: 'Urea', amountCents: 100000, finalCents: 100000),
    ],
    payments: [CreditPayment(id: 'p', date: DateTime(2026, 1, 31), cents: 50000, note: 'cash')],
  );

  test('the part of a payment that clears interest is recorded as interest income, on the payment day', () {
    final entries = creditInterestEntries([account]);
    expect(entries.length, 1);
    final e = entries.single;
    expect(e.income, isTrue);
    expect(e.category, 'Interest received');
    expect(e.date, DateTime(2026, 1, 31));
    // About Rs 9.86 of interest had built up, so about 986 paise is interest income and the rest is principal.
    expect(e.cents, closeTo(986, 3));
  });

  test('a payment made before any interest has built up adds no interest income', () {
    final early = CreditAccount(
      id: 'b',
      name: 'Sita',
      phone: '',
      annualRatePercent: 12,
      compound: false,
      bills: [CreditBill(id: 'c', date: DateTime(2026, 1, 1), billerName: 'Sita', description: 'Rice', amountCents: 100000, finalCents: 100000)],
      payments: [CreditPayment(id: 'q', date: DateTime(2026, 1, 1), cents: 20000, note: '')],
    );
    expect(creditInterestEntries([early]), isEmpty);
  });
}
