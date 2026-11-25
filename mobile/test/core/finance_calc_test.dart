import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/finance_calc.dart';

void main() {
  group('EMI', () {
    test('matches the standard figure for 1,00,000 at 12% over 12 months', () {
      final r = FinanceCalc.emi(principal: 100000, annualRatePercent: 12, months: 12);
      expect(r.emi, 8884.88);
      expect(r.totalInterest, closeTo(6618.56, 0.05));
    });

    test('zero interest divides evenly', () {
      final r = FinanceCalc.emi(principal: 1200, annualRatePercent: 0, months: 12);
      expect(r.emi, 100);
      expect(r.totalInterest, 0);
    });

    test('rejects invalid input', () {
      expect(() => FinanceCalc.emi(principal: 0, annualRatePercent: 5, months: 12), throwsArgumentError);
      expect(() => FinanceCalc.emi(principal: 1000, annualRatePercent: 5, months: 0), throwsArgumentError);
    });
  });

  group('interest', () {
    test('simple interest', () {
      expect(FinanceCalc.simpleInterest(principal: 10000, annualRatePercent: 12, years: 1), 1200);
    });

    test('compound interest with monthly compounding', () {
      final r = FinanceCalc.compound(principal: 10000, annualRatePercent: 12, years: 1);
      expect(r.amount, 11268.25);
      expect(r.interest, 1268.25);
    });
  });

  group('splitting', () {
    test('equal split gives leftover paise to the first people and sums exactly', () {
      final cents = FinanceCalc.splitCents(totalCents: 10000, mode: 'equal', values: [null, null, null]);
      expect(cents, [3334, 3333, 3333]);
      expect(cents.fold<int>(0, (a, b) => a + b), 10000);
    });

    test('exact split must match the total', () {
      expect(() => FinanceCalc.splitCents(totalCents: 90000, mode: 'exact', values: [500, 300]), throwsArgumentError);
      expect(FinanceCalc.splitCents(totalCents: 90000, mode: 'exact', values: [500, 300, 100]), [50000, 30000, 10000]);
    });

    test('percent split uses percentages that total 100', () {
      expect(FinanceCalc.splitCents(totalCents: 90000, mode: 'percent', values: [50, 30, 20]), [45000, 27000, 18000]);
      expect(() => FinanceCalc.splitCents(totalCents: 90000, mode: 'percent', values: [50, 40]), throwsArgumentError);
    });

    test('shares split by weight', () {
      expect(FinanceCalc.splitCents(totalCents: 90000, mode: 'shares', values: [2, 2, 1]), [36000, 36000, 18000]);
    });

    test('any split always sums to the total', () {
      for (final mode in ['equal', 'shares']) {
        final cents = FinanceCalc.splitCents(totalCents: 1000003, mode: mode, values: [1, 1, 1, 1, 1, 1, 1]);
        expect(cents.fold<int>(0, (a, b) => a + b), 1000003);
      }
    });
  });

  group('settling up', () {
    test('three people settle with two payments', () {
      final out = FinanceCalc.settle({'you': 60000, 'bo': -30000, 'cy': -30000});
      expect(out.length, 2);
      expect(out.every((p) => p.to == 'you'), isTrue);
      expect(out.fold<int>(0, (a, p) => a + p.cents), 60000);
    });

    test('balances that do not sum to zero are rejected', () {
      expect(() => FinanceCalc.settle({'a': 100, 'b': -50}), throwsArgumentError);
    });
  });
}
