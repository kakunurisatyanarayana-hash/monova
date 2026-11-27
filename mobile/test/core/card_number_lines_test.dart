import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/card_text_parser.dart';

void main() {
  test('a number printed in four rows is read in full', () {
    final p = parseCardText('4111 1111\n1111 1111\n12/28\nRAVI KUMAR\nHDFC BANK');
    expect(p.digits, '4111111111111111');
    expect(p.expiryMonth, 12);
    expect(p.expiryYear, 2028);
  });
  test('a number in one line with dashes is read in full', () {
    expect(parseCardText('4111-1111-1111-1111').digits, '4111111111111111');
  });
  test('a CVV printed after the number does not change it', () {
    expect(parseCardText('4111 1111 1111 1111 123').digits, '4111111111111111');
  });
  test('a phone number above the card does not hide it', () {
    expect(parseCardText('9876543210\n4111 1111 1111 1111').digits, '4111111111111111');
  });
}
