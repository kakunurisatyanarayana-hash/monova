import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/record_backup.dart';

void main() {
  test('a restore adds records this phone lacks and keeps the ones it already has', () {
    final current = {
      'monova.reminders': [
        {'id': 'r1', 'title': 'Rent (here)'},
      ],
    };
    final incoming = {
      'monova.reminders': [
        {'id': 'r1', 'title': 'Rent (in backup)'},
        {'id': 'r2', 'title': 'Electricity'},
      ],
      'monova.purchases': [
        {'id': 'p1', 'name': 'Fan'},
      ],
    };
    final (merged, added) = mergeRecordLists(current, incoming);
    expect(added, 2);
    expect(merged['monova.reminders']!.map((r) => r['title']), ['Rent (here)', 'Electricity']);
    expect(merged['monova.purchases']!.single['name'], 'Fan');
  });

  test('records without an id are matched by their full content', () {
    final (merged, added) = mergeRecordLists(
      {'monova.ledger': [{'name': 'Asha', 'cents': 100}]},
      {'monova.ledger': [{'name': 'Asha', 'cents': 100}, {'name': 'Ravi', 'cents': 50}]},
    );
    expect(added, 1);
    expect(merged['monova.ledger']!.length, 2);
  });
}
