import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saved records survive a reopen', () async {
    final store = await LocalStore.open();
    await store.writeList('monova.test', [
      {'name': 'Flat', 'amount': '5000000', 'rate': '8.5'},
    ]);

    final reopened = await LocalStore.open();
    final items = reopened.readList('monova.test');
    expect(items.single['name'], 'Flat');
    expect(items.single['rate'], '8.5');
  });

  test('a missing key reads as an empty list', () async {
    final store = await LocalStore.open();
    expect(store.readList('monova.missing'), isEmpty);
  });

  test('damaged data is ignored instead of crashing', () async {
    SharedPreferences.setMockInitialValues({'monova.bad': 'not json'});
    final store = await LocalStore.open();
    expect(store.readList('monova.bad'), isEmpty);
  });
}
