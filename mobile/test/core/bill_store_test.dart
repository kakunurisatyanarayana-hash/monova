import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/bill_store.dart';
import 'package:monova_app/core/card_rules.dart';

void main() {
  test('balances add up across bills: who is owed and who owes', () {
    final bills = [
      SavedBill(
        id: '1', title: '', createdAt: DateTime(2026, 11, 20), totalCents: 90000, payer: 'Asha',
        people: const ['Asha', 'Ravi', 'Meena'],
        settlements: const [
          Settlement(from: 'Ravi', to: 'Asha', cents: 30000),
          Settlement(from: 'Meena', to: 'Asha', cents: 30000),
        ],
      ),
      SavedBill(
        id: '2', title: '', createdAt: DateTime(2026, 11, 22), totalCents: 40000, payer: 'Ravi',
        people: const ['Asha', 'Ravi'],
        settlements: const [Settlement(from: 'Asha', to: 'Ravi', cents: 10000)],
      ),
    ];
    final net = netBalances(bills);
    expect(net['Asha'], 50000, reason: 'owed 60000 in bill 1, owes 10000 in bill 2');
    expect(net['Ravi'], -20000);
    expect(net['Meena'], -30000);
  });

  test('a bill with nothing to settle leaves no balances', () {
    final bill = SavedBill(id: '3', title: '', createdAt: DateTime(2026), totalCents: 0, payer: 'A', people: const ['A', 'B'], settlements: const []);
    expect(netBalances([bill]), isEmpty);
  });

  test('a saved bill survives a JSON round trip', () {
    final bill = SavedBill(
      id: '4', title: 'Dinner', createdAt: DateTime.utc(2026, 11, 25), totalCents: 12345, payer: 'Asha',
      people: const ['Asha', 'Ravi'],
      settlements: const [Settlement(from: 'Ravi', to: 'Asha', cents: 6172)],
    );
    final back = SavedBill.fromJson(bill.toJson());
    expect(back.title, 'Dinner');
    expect(back.settlements.single.cents, 6172);
    expect(back.people, ['Asha', 'Ravi']);
  });

  test('card number errors say which check failed', () {
    expect(cardNumberError('4111111111111111'), isNull);
    expect(cardNumberError('411111111111'), contains('check digit'), reason: '12 digits is a valid length, so only the check fails');
    expect(cardNumberError('41111111111'), contains('You entered 11'));
    expect(cardNumberError('4111111111111112'), contains('check digit'));
  });
  test('a split bill keeps its group through a save and reload', () {
    final bill = SavedBill(id: 'g1', title: 'Dinner', createdAt: DateTime.utc(2026, 11, 27), totalCents: 30000, payer: 'Asha', people: const ['Asha', 'Ravi'], settlements: const [Settlement(from: 'Ravi', to: 'Asha', cents: 15000)], groupId: 'trip');
    final back = SavedBill.fromJson(bill.toJson());
    expect(back.groupId, 'trip');
    expect(bill.copyWith(title: 'Lunch').groupId, 'trip');
    expect(SavedBill.fromJson({'id': 'old', 'title': '', 'totalCents': 0}).groupId, '');
  });
}