import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/rate_units.dart';

void main() {
  test('every way of quoting interest converts to the yearly rate', () {
    expect(toAnnualPercent(18, RateUnit.percentYear), 18);
    expect(toAnnualPercent(1.5, RateUnit.percentMonth), closeTo(18, 1e-9));
    // Rs 1.50 for every Rs 100 a month is 1.5% a month, which is 18% a year.
    expect(toAnnualPercent(1.5, RateUnit.rupeesPer100Month), closeTo(18, 1e-9));
    // Rs 15 for every Rs 1,000 a month is also 1.5% a month.
    expect(toAnnualPercent(15, RateUnit.rupeesPer1000Month), closeTo(18, 1e-9));
    expect(toAnnualPercent(2, RateUnit.rupeesPer100Month), closeTo(24, 1e-9));
  });

  test('the plain explanation gives the monthly cost per hundred, per thousand, and on Rs 10,000', () {
    final text = plainRateExplanation(18);
    expect(text, contains('₹1.50 for every ₹100'));
    expect(text, contains('₹15 for every ₹1,000'));
    expect(text, contains('On ₹10,000 that is ₹150 a month'));
    expect(text, contains('18.0% a year'));
  });
}
