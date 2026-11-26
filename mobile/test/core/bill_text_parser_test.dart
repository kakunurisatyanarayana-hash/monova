import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/bill_text_parser.dart';

void main() {
  test('reads date, total and biller from a typical printed bill', () {
    const text = '''
SHRI RAM FERTILIZERS
GSTIN 09ABCDE1234F1Z5
Bill No: 1043
Date: 12/09/2026
Name: Ramesh Kumar
Urea 2 bags        Rs 1,200.00
Total Amount: Rs 1,250.00
''';
    final p = parseBillText(text);
    expect(p.date, DateTime(2026, 9, 12));
    expect(p.amountRupees, 1250);
    expect(p.billerName, 'Ramesh Kumar');
    expect(p.isEmpty, isFalse);
  });

  test('reads a textual date and a grand total with a currency symbol', () {
    const text = '''
Date 3-Oct-2026
Bill to: Meena Devi
Grand Total ₹ 4,560.50
''';
    final p = parseBillText(text);
    expect(p.date, DateTime(2026, 10, 3));
    expect(p.amountRupees, 4560.5);
    expect(p.billerName, 'Meena Devi');
  });

  test('falls back to the largest amount when there is no total label', () {
    const text = '''
Pesticide 500
Fertiliser 2,300
Bag fee 40
''';
    final p = parseBillText(text);
    expect(p.amountRupees, 2300);
    expect(p.date, isNull);
    expect(p.billerName, isNull);
  });

  test('ignores a date when looking for the amount', () {
    const text = 'Date 12/09/2026\nSeed 180';
    final p = parseBillText(text);
    expect(p.amountRupees, 180);
    expect(p.date, DateTime(2026, 9, 12));
  });

  test('empty or unreadable text gives nothing', () {
    expect(parseBillText('').isEmpty, isTrue);
    expect(parseBillText('hello world').isEmpty, isTrue);
  });
}
