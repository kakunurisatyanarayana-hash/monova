import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/entry_store.dart';

void main() {
  test('borrowed money is not income, while rent and salary are', () {
    final entries = [
      MoneyEntry(id: 's', income: true, title: 'Salary', category: 'Salary', cents: 5000000, date: DateTime(2026, 11, 1)),
      MoneyEntry(id: 'rent', income: true, title: 'Rent received', category: 'Rental income', cents: 1500000, date: DateTime(2026, 11, 3)),
      MoneyEntry(id: 'loan', income: true, title: 'Borrowed from Ravi', category: 'Loan received', cents: 500000, date: DateTime(2026, 11, 4)),
      MoneyEntry(id: 'food', income: false, title: 'Groceries', category: 'Food', cents: 800000, date: DateTime(2026, 11, 5)),
      MoneyEntry(id: 'emi', income: false, title: 'Repaid Bank', category: 'Loan repayment', cents: 888488, date: DateTime(2026, 11, 6)),
    ];
    final s = monthSummary(entries, 2026, 11);
    expect(s.income, 6500000);
    expect(s.spent, 800000 + 888488);
    expect(s.savings, 6500000 - 1688488);
  });

  test('money from another month is left out of the totals', () {
    final entries = [
      MoneyEntry(id: 'old', income: true, title: 'Salary', category: 'Salary', cents: 5000000, date: DateTime(2026, 10, 1)),
    ];
    final s = monthSummary(entries, 2026, 11);
    expect(s.income, 0);
    expect(s.spent, 0);
  });
}
