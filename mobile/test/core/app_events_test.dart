import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/app_events.dart';
import 'package:monova_app/core/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('an added event is queued on the phone with only safe fields', () async {
    await AppEvents.add('ledger.added', {
      'kind': 'bill',
      'date': '2026-11-28',
      'name': 'Ravi Kumar',
      'amount': 1200,
    });
    expect(await AppEvents.pending(), 1);
    final store = await LocalStore.open();
    final saved = store.readList(outboxKey).single;
    expect(saved['type'], 'ledger.added');
    final fields = saved['fields'] as Map;
    expect(fields.containsKey('name'), isFalse);
    expect(fields.containsKey('amount'), isFalse);
    expect(fields['kind'], 'bill');
  });

  test('queue keeps events in the order they happened', () async {
    await AppEvents.add('ledger.added', {'kind': 'bill'});
    await AppEvents.add('ledger.deleted', {'kind': 'payment'});
    final store = await LocalStore.open();
    final list = store.readList(outboxKey);
    expect(list.map((e) => e['type']).toList(), [
      'ledger.added',
      'ledger.deleted',
    ]);
  });

  test('flush does nothing when the test server is not set up', () async {
    await AppEvents.add('ledger.added', {'kind': 'bill'});
    final message = await AppEvents.flush();
    expect(message, contains('not set up'));
    expect(await AppEvents.pending(), 1);
  });
}
