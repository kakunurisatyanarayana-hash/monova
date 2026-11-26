import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/card_text_parser.dart';

void main() {
  test('reads number, expiry, name and bank from a typical card', () {
    const text = '''
HDFC BANK
VISA
4111 1111 1111 1111
VALID THRU 08/29
ASHA RAO
''';
    final p = parseCardText(text);
    expect(p.digits, '4111111111111111');
    expect(p.expiryMonth, 8);
    expiryYearIs(p, 2029);
    expect(p.holder, 'ASHA RAO');
    expect(p.bank, 'HDFC BANK');
    expect(p.isEmpty, isFalse);
  });

  test('reads a number written with dashes and an expiry with a four-digit year', () {
    const text = '''
5500-0000-0000-0004
EXP 11/2028
RAVI KUMAR
''';
    final p = parseCardText(text);
    expect(p.digits, '5500000000000004');
    expect(p.expiryMonth, 11);
    expiryYearIs(p, 2028);
    expect(p.holder, 'RAVI KUMAR');
  });

  test('a card word on its own line is not taken as the name', () {
    const text = 'PLATINUM\nDEBIT CARD\n4111111111111111';
    final p = parseCardText(text);
    expect(p.holder, isNull);
    expect(p.digits, '4111111111111111');
  });

  test('text with nothing readable gives an empty result', () {
    expect(parseCardText('hello there').isEmpty, isTrue);
  });
}

void expiryYearIs(ParsedCard p, int year) => expect(p.expiryYear, year);
