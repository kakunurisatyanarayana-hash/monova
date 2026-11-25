import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/calculator_engine.dart';
import 'package:monova_app/core/loan_calc.dart';

void main() {
  group('calculator expressions', () {
    final calc = CalculatorEngine();

    double ev(String s) => calc.evaluate(s);

    test('basic arithmetic follows operator precedence', () {
      expect(ev('2+3*4'), 14);
      expect(ev('(2+3)*4'), 20);
      expect(ev('10-4-3'), 3);
      expect(ev('8/2/2'), 2);
    });

    test('the textbook example evaluates correctly', () {
      expect(ev('3 + 4 * 2 / ( 1 - 5 ) ^ 2 ^ 3'), closeTo(3.0001220703125, 1e-12));
    });

    test('unary minus and powers', () {
      expect(ev('-2^2'), -4);
      expect(ev('(-2)^2'), 4);
      expect(ev('2^-3'), 0.125);
      expect(ev('2*-3'), -6);
    });

    test('percent and factorial', () {
      expect(ev('50%'), 0.5);
      expect(ev('200*10%'), 20);
      expect(ev('5!'), 120);
    });

    test('scientific functions and constants', () {
      expect(ev('sqrt(16)'), 4);
      expect(ev('cbrt(27)'), closeTo(3, 1e-9));
      expect(ev('log(1000)'), closeTo(3, 1e-9));
      expect(ev('ln(e)'), closeTo(1, 1e-9));
      expect(ev('sin(30)'), closeTo(0.5, 1e-9));
      expect(ev('2*pi'), closeTo(6.283185307, 1e-8));
    });

    test('radian mode changes trigonometry', () {
      final rad = CalculatorEngine(degrees: false);
      expect(rad.evaluate('sin(pi/2)'), closeTo(1, 1e-9));
    });

    test('errors are reported, not silently wrong', () {
      expect(() => ev('1/0'), throwsFormatException);
      expect(() => ev('2+'), throwsFormatException);
      expect(() => ev('((2)'), throwsFormatException);
      expect(() => ev('2)'), throwsFormatException);
      expect(() => ev('foo(2)'), throwsFormatException);
      expect(() => ev('2.3.4'), throwsFormatException);
      expect(() => ev('(-1)!'), throwsFormatException);
    });

    test('results are trimmed of floating point noise', () {
      expect(CalculatorEngine.format(0.1 + 0.2), '0.3');
      expect(CalculatorEngine.format(4), '4');
      expect(CalculatorEngine.format(1 / 3), '0.333333333333');
    });
  });

  group('loan calculator', () {
    test('home loan EMI matches the standard figure (50 lakh, 8.5%, 20 years)', () {
      final r = LoanCalculator.calculate(const LoanInput(principal: 5000000, annualRatePercent: 8.5, tenureMonths: 240));
      expect(r.emi, closeTo(43391, 1));
      expect(r.schedule.length, 240);
    });

    test('schedule clears the principal exactly', () {
      final r = LoanCalculator.calculate(const LoanInput(principal: 5000000, annualRatePercent: 8.5, tenureMonths: 240));
      expect(r.schedule.last.balance, 0);
      final principalPaid = r.schedule.fold<double>(0, (a, row) => a + row.principal);
      expect(principalPaid, closeTo(5000000, 0.01));
    });

    test('processing fee carries 18% GST, and interest does not', () {
      final r = LoanCalculator.calculate(const LoanInput(
        principal: 5000000,
        annualRatePercent: 8.5,
        tenureMonths: 240,
        charges: LoanCharges(processingFeePercent: 0.5),
      ));
      expect(r.serviceFees, 25000);
      expect(r.gstOnFees, 4500);
      expect(r.upfrontCharges, 29500);
      expect(r.netDisbursed, 4970500);

      // Turning GST off on fees changes only the GST line, never the interest.
      final noGst = LoanCalculator.calculate(const LoanInput(
        principal: 5000000,
        annualRatePercent: 8.5,
        tenureMonths: 240,
        charges: LoanCharges(processingFeePercent: 0.5, applyGstOnServiceFees: false),
      ));
      expect(noGst.gstOnFees, 0);
      expect(noGst.totalInterest, r.totalInterest);
    });

    test('effective rate rises above the stated rate once upfront charges are counted', () {
      final r = LoanCalculator.calculate(const LoanInput(
        principal: 5000000,
        annualRatePercent: 8.5,
        tenureMonths: 240,
        charges: LoanCharges(processingFeePercent: 0.5),
      ));
      expect(r.effectiveAnnualRatePercent, greaterThan(8.5));
      expect(r.effectiveAnnualRatePercent, lessThan(9.0));
    });

    test('with no charges the effective rate equals the stated rate', () {
      final r = LoanCalculator.calculate(const LoanInput(principal: 100000, annualRatePercent: 12, tenureMonths: 12));
      expect(r.effectiveAnnualRatePercent, closeTo(12, 0.05));
    });

    test('total cost is principal-equivalent payments plus every upfront charge', () {
      final r = LoanCalculator.calculate(const LoanInput(
        principal: 100000,
        annualRatePercent: 10,
        tenureMonths: 12,
        charges: LoanCharges(processingFeePercent: 1, insurancePremium: 500),
      ));
      final paid = r.schedule.fold<double>(0, (a, row) => a + row.emi);
      expect(r.totalCost, closeTo(paid + r.upfrontCharges, 0.01));
      expect(r.otherCharges, 500);
    });

    test('compareAll covers every loan type with its default terms', () {
      final rows = LoanCalculator.compareAll(1000000);
      expect(rows.length, LoanProduct.all.length);
      final names = rows.map((r) => r.product.name);
      expect(names, containsAll(['Home loan', 'Personal loan', 'Car loan', 'Two-wheeler loan', 'Education loan', 'Business loan', 'Loan against property', 'Gold loan']));
      expect(rows.every((r) => r.result.emi > 0), isTrue);
    });

    test('invalid input is rejected', () {
      expect(() => LoanCalculator.calculate(const LoanInput(principal: 0, annualRatePercent: 8, tenureMonths: 12)), throwsArgumentError);
      expect(() => LoanCalculator.calculate(const LoanInput(principal: 1000, annualRatePercent: 8, tenureMonths: 0)), throwsArgumentError);
    });
  });
}
