import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/date_calc.dart';

void main() {
  group('calendar months', () {
    test('a month end is clamped to the last day of the target month', () {
      expect(DateCalc.addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(DateCalc.addMonths(DateTime(2024, 1, 31), 1), DateTime(2024, 2, 29));
    });

    test('months roll over the year boundary', () {
      expect(DateCalc.addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
      expect(DateCalc.addMonths(DateTime(2026, 3, 10), -4), DateTime(2025, 11, 10));
    });
  });

  group('age', () {
    test('exact age in years, months and days', () {
      final r = AgeCalc.between(birth: DateTime(2000, 1, 1), on: DateTime(2026, 11, 25));
      expect(r.years, 26);
      expect(r.months, 10);
      expect(r.days, 24);
    });

    test('birthday today means zero days to the next one', () {
      final r = AgeCalc.between(birth: DateTime(1990, 11, 25), on: DateTime(2026, 11, 25));
      expect(r.years, 36);
      expect(r.daysToNextBirthday, 0);
    });

    test('next birthday moves to next year once this year has passed', () {
      final r = AgeCalc.between(birth: DateTime(1990, 3, 10), on: DateTime(2026, 11, 25));
      expect(r.nextBirthday, DateTime(2027, 3, 10));
      expect(r.daysToNextBirthday, DateTime(2027, 3, 10).difference(DateTime(2026, 11, 25)).inDays);
    });

    test('total days and weeks', () {
      final r = AgeCalc.between(birth: DateTime(2026, 1, 1), on: DateTime(2027, 1, 1));
      expect(r.totalDays, 365);
      expect(r.totalWeeks, 52);
    });

    test('a birth date after the calculation date is rejected', () {
      expect(() => AgeCalc.between(birth: DateTime(2030, 1, 1), on: DateTime(2026, 1, 1)), throwsArgumentError);
    });
  });

  group('loan and rent terms', () {
    test('years and months convert to whole months', () {
      expect(DateCalc.termToMonths(2, TermUnit.years), 24);
      expect(DateCalc.termToMonths(18, TermUnit.months), 18);
    });

    test('days convert to months, rounded up', () {
      expect(DateCalc.termToMonths(30, TermUnit.days), 1);
      expect(DateCalc.termToMonths(400, TermUnit.days), 14);
    });

    test('end date from a start date and a term', () {
      expect(DateCalc.termEnd(DateTime(2026, 1, 1), 2, TermUnit.years), DateTime(2028, 1, 1));
      expect(DateCalc.termEnd(DateTime(2026, 1, 1), 90, TermUnit.days), DateTime(2026, 4, 1));
    });
  });

  group('rent', () {
    test('rent steps up each lease year', () {
      final r = RentCalc.calculate(monthlyRent: 10000, yearlyIncreasePercent: 5, months: 24);
      expect(r.years.length, 2);
      expect(r.years[0].yearTotal, 120000);
      expect(r.years[1].monthlyRent, 10500);
      expect(r.totalRent, 246000);
      expect(r.finalMonthlyRent, 10500);
    });

    test('a partial last year is counted in months', () {
      final r = RentCalc.calculate(monthlyRent: 1000, yearlyIncreasePercent: 0, months: 14);
      expect(r.totalRent, 14000);
      expect(r.years.last.yearTotal, 2000);
    });

    test('invalid input is rejected', () {
      expect(() => RentCalc.calculate(monthlyRent: 0, yearlyIncreasePercent: 0, months: 12), throwsArgumentError);
      expect(() => RentCalc.calculate(monthlyRent: 100, yearlyIncreasePercent: 0, months: 0), throwsArgumentError);
    });
  });
}
