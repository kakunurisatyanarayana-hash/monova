import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/input_patterns.dart';

void main() {
  test('amounts accept digits, commas and up to two decimals, and refuse letters', () {
    expect(fitsPattern(amountPattern, '1,20,000.50'), isTrue);
    expect(fitsPattern(amountPattern, '250'), isTrue);
    expect(fitsPattern(amountPattern, '12.'), isTrue);
    expect(fitsPattern(amountPattern, ''), isTrue);
    expect(fitsPattern(amountPattern, '12a'), isFalse);
    expect(fitsPattern(amountPattern, '1.2.3'), isFalse);
    expect(fitsPattern(amountPattern, '5.555'), isFalse);
    expect(fitsPattern(amountPattern, '₹100'), isFalse);
  });

  test('whole numbers accept digits only', () {
    expect(fitsPattern(wholeNumberPattern, '600072'), isTrue);
    expect(fitsPattern(wholeNumberPattern, ''), isTrue);
    expect(fitsPattern(wholeNumberPattern, '12x'), isFalse);
    expect(fitsPattern(wholeNumberPattern, '1.5'), isFalse);
    expect(fitsPattern(wholeNumberPattern, '-3'), isFalse);
  });

  test('phone numbers accept digits, plus, spaces and hyphens only', () {
    expect(fitsPattern(phonePattern, '+91 95053-23902'), isTrue);
    expect(fitsPattern(phonePattern, '95053a'), isFalse);
  });

  test('coordinates accept a minus sign and one decimal point', () {
    expect(fitsPattern(signedDecimalPattern, '-17.385044'), isTrue);
    expect(fitsPattern(signedDecimalPattern, '17.3.85'), isFalse);
    expect(fitsPattern(signedDecimalPattern, '1a'), isFalse);
  });
}
