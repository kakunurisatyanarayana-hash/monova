import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/credit_ledger.dart';

CreditAccount account({double rate = 12, bool compound = false, List<CreditBill> bills = const [], List<CreditPayment> payments = const []}) =>
    CreditAccount(
      id: 'a', name: 'Ramesh', phone: '', annualRatePercent: rate, compound: compound, bills: bills, payments: payments,
    );

CreditBill bill(DateTime d, int finalCents, {int? amount}) =>
    CreditBill(id: '${d.millisecondsSinceEpoch}', date: d, billerName: 'Ramesh', description: 'Urea 2 bags', amountCents: amount ?? finalCents, finalCents: finalCents);

void main() {
  test('simple interest for a full year on Rs 1000 at 12% is Rs 120', () {
    final s = computeStatement(account(bills: [bill(DateTime(2026, 1, 1), 100000)]), DateTime(2027, 1, 1));
    expect(s.principalCents, 100000);
    expect(s.interestCents, closeTo(12000, 1));
    expect(s.totalCents, closeTo(112000, 1));
  });

  test('a payment clears the accrued interest first, then reduces the amount owed', () {
    // 30 days of interest on Rs 1000 at 12% is about Rs 9.86; the Rs 200 payment clears it first.
    final s = computeStatement(
      account(
        bills: [bill(DateTime(2026, 1, 1), 100000)],
        payments: [CreditPayment(id: 'p', date: DateTime(2026, 1, 31), cents: 20000, note: 'cash')],
      ),
      DateTime(2026, 1, 31),
    );
    expect(s.interestCents, 0);
    expect(s.principalCents, closeTo(100000 - (20000 - 986.3), 2));
  });

  test('compound interest comes out higher than simple interest over the same year', () {
    final simple = computeStatement(account(bills: [bill(DateTime(2026, 1, 1), 100000)]), DateTime(2027, 1, 1));
    final compound = computeStatement(account(compound: true, bills: [bill(DateTime(2026, 1, 1), 100000)]), DateTime(2027, 1, 1));
    expect(compound.totalCents, greaterThan(simple.totalCents));
    expect(compound.totalCents, closeTo(112747, 40), reason: 'about 12.75% effective for a year, compounded daily');
  });

  test('paying more than is owed leaves an advance (a negative amount owed)', () {
    final s = computeStatement(
      account(
        bills: [bill(DateTime(2026, 1, 1), 50000)],
        payments: [CreditPayment(id: 'p', date: DateTime(2026, 1, 2), cents: 60000, note: '')],
      ),
      DateTime(2026, 1, 2),
    );
    // One day of interest (about 16 paisa) accrues before the payment and is cleared first, so the advance is Rs 99.84.
    expect(s.principalCents, closeTo(-9984, 1));
    expect(s.totalCents, lessThan(0));
  });

  test('the statement running balance follows bills and payments', () {
    final s = computeStatement(
      account(
        bills: [bill(DateTime(2026, 1, 1), 100000), bill(DateTime(2026, 2, 1), 30000)],
        payments: [CreditPayment(id: 'p', date: DateTime(2026, 3, 1), cents: 20000, note: 'UPI')],
      ),
      DateTime(2026, 3, 1),
    );
    expect(s.lines, hasLength(3));
    expect(s.lines.first.balanceCents, 100000);
    expect(s.lines[1].balanceCents, 130000);
    expect(s.lines.last.balanceCents, 110000 - 0, reason: 'bills 1,30,000 less payment 20,000');
    expect(s.totalBilledCents, 130000);
    expect(s.totalPaidCents, 20000);
  });

  test('nothing before the first bill, and no interest on a zero balance', () {
    final empty = computeStatement(account(), DateTime(2026, 6, 1));
    expect(empty.totalCents, 0);
    final paidOff = computeStatement(
      account(
        bills: [bill(DateTime(2026, 1, 1), 10000)],
        payments: [CreditPayment(id: 'p', date: DateTime(2026, 1, 1), cents: 10000, note: '')],
      ),
      DateTime(2026, 6, 1),
    );
    expect(paidOff.totalCents, 0);
  });

  test('an account survives a JSON round trip', () {
    final a = account(rate: 18, compound: true, bills: [bill(DateTime(2026, 5, 5), 25000)]);
    final back = CreditAccount.fromJson(a.toJson());
    expect(back.annualRatePercent, 18);
    expect(back.compound, isTrue);
    expect(back.bills.single.finalCents, 25000);
    expect(back.bills.single.date, DateTime(2026, 5, 5));
  });
}
