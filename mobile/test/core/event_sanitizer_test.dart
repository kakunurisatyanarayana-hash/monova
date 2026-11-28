import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/event_sanitizer.dart';

void main() {
  test('keeps only allowed fields', () {
    final out = sanitizeEventFields({
      'kind': 'bill',
      'date': '2026-11-28',
      'count': 1,
      'name': 'Ravi',
      'amount': 500,
    });
    expect(out, {'kind': 'bill', 'date': '2026-11-28', 'count': 1});
  });

  test('drops phone and account numbers even in allowed fields', () {
    final out = sanitizeEventFields({
      'kind': '9848012345',
      'status': '1234567890123',
    });
    expect(out, isEmpty);
  });

  test('drops long free text', () {
    final out = sanitizeEventFields({
      'status': 'Paid half in cash, balance after harvest on the next visit to the shop',
    });
    expect(out, isEmpty);
  });

  test('drops empty values', () {
    expect(sanitizeEventFields({'kind': null, 'module': 'customers'}), {
      'module': 'customers',
    });
  });
}
