import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/entry_store.dart';
import 'package:monova_app/core/property_money.dart';
import 'package:monova_app/core/property_store.dart';

Payment _pay(String id, String kind, int cents, DateTime date, {String prop = 'h', String person = 'a', String room = 'r1'}) =>
    Payment(id: id, propertyId: prop, kind: kind, amountCents: cents, date: date, personId: person, roomId: room);

void main() {
  final book = PropertyBook(
    properties: const [Property(id: 'h', name: 'Sunrise Hotel', category: 'Hotel'), Property(id: 'p', name: 'Green PG', category: 'PG')],
    rooms: const [Room(id: 'r1', propertyId: 'h', number: '101')],
    persons: [Person(id: 'a', name: 'Asha', createdAt: DateTime(2026, 11, 1))],
  );
  final nov = DateTime(2026, 11, 5);

  test('rent received becomes hotel income with the guest and room in the title', () {
    final e = financeEntryFor(_pay('1', 'rent', 500000, nov), book)!;
    expect(e.income, isTrue);
    expect(e.cents, 500000);
    expect(e.category, 'Hotel income');
    expect(e.title, 'Rent · Asha · Room 101');
    expect(e.id, 'prop-1');
  });

  test('rent at a PG is rental income', () {
    final pg = book.copyWith(rooms: const [Room(id: 'r2', propertyId: 'p', number: 'B1')]);
    final e = financeEntryFor(_pay('2', 'rent', 800000, nov, prop: 'p', room: 'r2'), pg)!;
    expect(e.category, 'Rental income');
  });

  test('deposits and refunds are not income or spending', () {
    expect(financeEntryFor(_pay('3', 'deposit', 100000, nov), book), isNull);
    expect(financeEntryFor(_pay('4', 'refund', 100000, nov), book), isNull);
  });

  test('an expense becomes a spending entry in its category', () {
    final p = Payment(id: '5', propertyId: 'h', kind: 'expense', amountCents: 25000, date: nov, category: 'Electricity');
    final e = financeEntryFor(p, book)!;
    expect(e.income, isFalse);
    expect(e.category, 'Electricity');
    expect(e.title, 'Electricity · Sunrise Hotel');
  });

  test('syncing twice does not duplicate, updates changed amounts, removes deleted payments, and keeps other entries', () {
    final own = MoneyEntry(id: 'salary-1', income: true, title: 'Salary', category: 'Salary', cents: 5000000, date: nov);
    final b1 = book.copyWith(payments: [_pay('1', 'rent', 500000, nov), _pay('2', 'advance', 200000, nov)]);
    var entries = mergeFinanceEntries([own], b1);
    entries = mergeFinanceEntries(entries, b1);
    expect(entries.length, 3);
    expect(entries.where((e) => e.id == 'salary-1').length, 1);

    final b2 = b1.copyWith(payments: [_pay('1', 'rent', 450000, nov)]);
    entries = mergeFinanceEntries(entries, b2);
    expect(entries.length, 2);
    expect(entries.firstWhere((e) => e.id == 'prop-1').cents, 450000);
    expect(entries.any((e) => e.id == 'prop-2'), isFalse);
    expect(entries.any((e) => e.id == 'salary-1'), isTrue);
  });

  test('monthly totals count rent and expenses in that month only, and deposits held net of refunds', () {
    final b = book.copyWith(payments: [
      _pay('1', 'rent', 500000, DateTime(2026, 11, 2)),
      _pay('2', 'rent', 300000, DateTime(2026, 10, 30)),
      Payment(id: '3', propertyId: 'h', kind: 'expense', amountCents: 40000, date: DateTime(2026, 11, 9), category: 'Water'),
      _pay('4', 'deposit', 200000, DateTime(2026, 11, 2)),
      _pay('5', 'refund', 50000, DateTime(2026, 11, 20)),
    ]);
    final m = monthMoney(b, propertyId: 'h', year: 2026, month: 11);
    expect(m.rentCents, 500000);
    expect(m.expenseCents, 40000);
    expect(m.netCents, 460000);
    expect(m.depositsHeldCents, 150000);
    expect(monthMoney(b, year: 2026, month: 10).rentCents, 300000);
  });

  test('when hotel guest data is erased, the amount stays in the accounts but the guest is removed from it', () {
    final old = Person(id: 'a', name: 'Asha', createdAt: DateTime(2026, 1, 1), propertyId: 'h');
    final stay = Tenancy(id: 's', propertyId: 'h', roomId: 'r1', bed: 1, name: 'Asha', checkIn: DateTime(2026, 1, 1), actualCheckout: DateTime(2026, 1, 10), personId: 'a');
    final b = PropertyBook(
      properties: book.properties,
      rooms: book.rooms,
      persons: [old],
      tenancies: [stay],
      payments: [_pay('1', 'rent', 500000, DateTime(2026, 1, 5))],
    );
    final (after, removed) = purgeExpiredGuests(b, DateTime(2026, 11, 27));
    expect(removed, 2);
    expect(after.payments.single.amountCents, 500000);
    expect(after.payments.single.personId, '');
    expect(financeEntryFor(after.payments.single, after)!.title, startsWith('Rent · '));
  });

  test('payments survive a JSON round trip', () {
    final p = Payment(id: 'j', propertyId: 'h', kind: 'expense', amountCents: 1234, date: DateTime(2026, 11, 3), category: 'Repairs', note: 'Door lock', method: 'UPI');
    final back = Payment.fromJson(p.toJson());
    expect(back.amountCents, 1234);
    expect(back.category, 'Repairs');
    expect(back.method, 'UPI');
    expect(back.date, DateTime(2026, 11, 3));
  });
}
