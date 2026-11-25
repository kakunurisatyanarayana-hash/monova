import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/format.dart';
import 'package:monova_app/data/models.dart';

void main() {
  group('money formatting', () {
    test('formats rupees with Indian grouping and two decimals', () {
      expect(money(482310), '₹4,82,310.00');
      expect(money(0.5), '₹0.50');
    });

    test('signed amounts show the sign', () {
      expect(moneySigned(1200), '+₹1,200.00');
      expect(moneySigned(-450), '−₹450.00');
    });

    test('parseAmount rounds to paise and rejects non-positive values', () {
      expect(parseAmount('1,250.5'), 1250.5);
      expect(parseAmount('0'), isNull);
      expect(parseAmount('-4'), isNull);
      expect(parseAmount('abc'), isNull);
    });

    test('validateAmount explains what is wrong', () {
      expect(validateAmount(''), 'Enter an amount');
      expect(validateAmount('12.5'), isNull);
    });
  });

  group('dashboard parsing', () {
    test('reads the server dashboard payload', () {
      final json = <String, dynamic>{
        'bankBalance': 165000,
        'cashBalance': 1550,
        'totalLiquid': 166550,
        'monthIncome': 120000,
        'monthExpenses': 18850,
        'monthNet': 101150,
        'cardOutstanding': 13400,
        'cardLimit': 100000,
        'cardAvailable': 86600,
        'debtsOutstanding': 0,
        'loansOutstanding': 0,
        'receivablesOutstanding': 0,
        'groupOwedToYou': 600,
        'groupYouOwe': 0,
        'netWorth': 153150,
        'upcoming': [
          {'kind': 'Card bill', 'title': 'Regalia', 'amount': 13400, 'dueOn': '2026-12-05', 'isIncoming': false},
        ],
        'recentTransactions': [
          {'id': 'x', 'title': 'Lunch', 'type': 'Expense', 'amount': 450, 'date': '2026-11-25', 'categoryName': 'Food'},
        ],
        'spendingTrend': [
          {'year': 2026, 'month': 11, 'expenses': 18850, 'income': 120000},
        ],
        'categorySpending': [
          {'categoryId': null, 'name': 'Food', 'amount': 18850, 'percent': 100},
        ],
        'budget': {
          'year': 2026,
          'month': 11,
          'overallBudget': 20000,
          'overallSpent': 18850,
          'overallPercentUsed': 94.3,
          'overallStatus': 'Warning',
          'lines': [],
          'warnings': ['You have used 94% of your monthly budget.'],
        },
        'savingsSaved': 10000,
      };

      final d = Dashboard.fromJson(json);
      expect(d.totalLiquid, 166550);
      expect(d.cardAvailable, 86600);
      expect(d.upcoming.single.dueOn, DateTime(2026, 12, 5));
      expect(d.recent.single.categoryName, 'Food');
      expect(d.budget.overallStatus, 'Warning');
      expect(d.budget.warnings, hasLength(1));
    });

    test('loan status maps to closed flag', () {
      final loan = LoanItem.fromJson(<String, dynamic>{
        'id': 'l1',
        'name': 'Car',
        'lender': 'HDFC',
        'principal': 100000,
        'annualInterestRatePercent': 12,
        'termMonths': 12,
        'emiAmount': 8884.88,
        'startOn': '2026-01-01',
        'accountId': 'a1',
        'outstanding': 0,
        'paidInstallments': 12,
        'nextDueOn': null,
        'nextAmount': null,
        'totalInterest': 6618.56,
        'status': 'Closed',
        'schedule': [],
      });
      expect(loan.isClosed, isTrue);
      expect(loan.nextDueOn, isNull);
    });
  });
}
