import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/attention.dart';
import 'package:monova_app/core/entry_store.dart';
import 'package:monova_app/core/property_store.dart';

void main() {
  final today = DateTime(2026, 11, 27);

  test('a return deadline within a week is urgent and listed first', () {
    final items = attentionItems(
      purchases: [
        Purchase(id: 'a', name: 'Fan', retailer: '', cents: 100, date: DateTime(2026, 11, 20), returnDays: 10),
        Purchase(id: 'b', name: 'Lamp', retailer: '', cents: 100, date: DateTime(2026, 11, 1), warrantyMonths: 24),
      ],
      book: const PropertyBook(),
      today: today,
    );
    expect(items.first.urgent, isTrue);
    expect(items.first.title, contains('Fan'));
  });

  test('a warranty ending far away is not listed', () {
    final items = attentionItems(
      purchases: [Purchase(id: 'c', name: 'TV', retailer: '', cents: 100, date: DateTime(2026, 11, 1), warrantyMonths: 36)],
      book: const PropertyBook(),
      today: today,
    );
    expect(items, isEmpty);
  });

  test('a guest leaving in two days is listed; a guest leaving in a month is not', () {
    final book = PropertyBook(tenancies: [
      Tenancy(id: 's1', propertyId: 'p', roomId: 'r', bed: 1, name: 'Asha', personId: 'a', checkIn: DateTime(2026, 11, 1), expectedCheckout: DateTime(2026, 11, 29)),
      Tenancy(id: 's2', propertyId: 'p', roomId: 'r', bed: 2, name: 'Ravi', personId: 'b', checkIn: DateTime(2026, 11, 1), expectedCheckout: DateTime(2026, 12, 27)),
    ]);
    final items = attentionItems(purchases: const [], book: book, today: today);
    expect(items.length, 1);
    expect(items.single.title, contains('Asha'));
    expect(items.single.route, '/person/a');
  });

  test('nothing due gives an empty list', () {
    expect(attentionItems(purchases: const [], book: const PropertyBook(), today: today), isEmpty);
  });
}
