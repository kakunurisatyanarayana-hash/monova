import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/entry_store.dart';
import 'package:monova_app/core/loans.dart';

void main() {
  // Rs 1,00,000 at 12% a year for 12 months. The EMI is about Rs 8,884.88.
  final car = Loan(id: 'car', name: 'HDFC Bank', kind: 'emi', principalCents: 10000000, startDate: DateTime(2026, 1, 5), annualRatePercent: 12, months: 12);

  test('an EMI loan has a standard monthly instalment and the full balance at the start', () {
    expect(car.emiCents, closeTo(888488, 2));
    expect(car.outstandingCents(), 10000000);
  });

  test('after paying instalments the balance falls the way an amortising loan does', () {
    final afterTwo = car.withPayment(LoanPayment(id: 'p1', date: DateTime(2026, 2, 5), cents: car.emiCents)).withPayment(LoanPayment(id: 'p2', date: DateTime(2026, 3, 5), cents: car.emiCents));
    // Balance after two instalments at 1% a month is about Rs 84,151.
    expect(afterTwo.outstandingCents(), closeTo(8415139, 3000));
    expect(afterTwo.payments.length, 2);
  });

  test('overdue instalments are counted from the due dates, not from payments made', () {
    // The first instalment falls due a month after the start: 5 Feb and 5 Mar are due by 20 March.
    expect(car.dueInstallments(DateTime(2026, 3, 20)), 2);
    expect(car.overdueInstallments(DateTime(2026, 3, 20)), 2);
    final paidOne = car.withPayment(LoanPayment(id: 'p1', date: DateTime(2026, 1, 6), cents: car.emiCents));
    expect(paidOne.overdueInstallments(DateTime(2026, 3, 20)), 1);
    expect(paidOne.nextDueDate(), DateTime(2026, 3, 5));
  });

  test('a finished loan has nothing outstanding and no next due date', () {
    var l = car;
    for (var i = 0; i < 12; i++) {
      l = l.withPayment(LoanPayment(id: 'p$i', date: DateTime(2026, 1, 5 + i), cents: car.emiCents));
    }
    expect(l.outstandingCents(), 0);
    expect(l.finished, isTrue);
    expect(l.nextDueDate(), isNull);
  });

  test('borrowed money with no interest is repaid in any amounts and tracked to zero', () {
    final borrowed = Loan(id: 'b', name: 'Ravi', kind: 'open', principalCents: 500000, startDate: DateTime(2026, 11, 1));
    final part = borrowed.withPayment(LoanPayment(id: 'x', date: DateTime(2026, 11, 10), cents: 200000));
    expect(part.outstandingCents(), 300000);
    expect(part.progress, closeTo(0.4, 1e-9));
    expect(part.withPayment(LoanPayment(id: 'y', date: DateTime(2026, 11, 20), cents: 300000)).finished, isTrue);
  });

  test('Monova Finance gets the money in, and each repayment out, and stays in step when a repayment is deleted', () {
    final borrowed = Loan(id: 'b', name: 'Ravi', kind: 'open', principalCents: 500000, startDate: DateTime(2026, 11, 1))
        .withPayment(LoanPayment(id: 'x', date: DateTime(2026, 11, 10), cents: 200000));
    var entries = mergeLoanEntries([MoneyEntry(id: 'salary', income: true, title: 'Salary', category: 'Salary', cents: 5000000, date: DateTime(2026, 11, 1))], [borrowed]);
    expect(entries.length, 3);
    expect(entries.any((e) => e.id == 'salary'), isTrue);
    expect(entries.firstWhere((e) => e.id == 'loanin-b').income, isTrue);
    expect(entries.firstWhere((e) => e.id == 'loanpay-x').income, isFalse);

    // Running again changes nothing.
    expect(mergeLoanEntries(entries, [borrowed]).length, 3);

    // Deleting the repayment removes its spending entry.
    entries = mergeLoanEntries(entries, [borrowed.withoutPayment('x')]);
    expect(entries.any((e) => e.id == 'loanpay-x'), isFalse);
    expect(entries.length, 2);
  });

  test('a loan survives a save and reload', () {
    final back = Loan.fromJson(car.withPayment(LoanPayment(id: 'p', date: DateTime(2026, 2, 5), cents: 888488, note: 'Feb')).toJson());
    expect(back.months, 12);
    expect(back.payments.single.note, 'Feb');
    expect(back.payments.single.date, DateTime(2026, 2, 5));
  });
}
