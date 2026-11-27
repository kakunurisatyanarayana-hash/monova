import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/groups_store.dart';

void main() {
  // You (Asha) pay Rs 1,000 for dinner for four people: Rs 250 each.
  final dinner = GroupExpense(
    id: 'd',
    title: 'Dinner',
    cents: 100000,
    paidBy: 'a',
    shares: const {'a': 25000, 'r': 25000, 'm': 25000, 'k': 25000},
    createdAt: DateTime(2026, 11, 20),
  );
  final trip = LocalGroup(
    id: 'g',
    name: 'Goa trip',
    members: const [
      GroupMember(id: 'a', name: 'Asha'),
      GroupMember(id: 'r', name: 'Ravi'),
      GroupMember(id: 'm', name: 'Meena'),
      GroupMember(id: 'k', name: 'Kiran'),
    ],
    expenses: [dinner],
    meId: 'a',
  );

  test('only your share is spending; the rest is money owed to you, not spending', () {
    final entries = groupShareEntries([trip]);
    expect(entries.length, 1);
    expect(entries.single.income, isFalse);
    expect(entries.single.cents, 25000);
    expect(entries.single.category, 'Shared expenses');
  });

  test('the three others owe you Rs 750 in total until they pay', () {
    final owed = trip.settlements.where((s) => s.to == 'a').fold<int>(0, (t, s) => t + s.cents);
    expect(owed, 75000);
    expect(trip.settlements.every((s) => s.from != 'a'), isTrue);
  });

  test('when someone pays you, the balance drops and no spending is recorded', () {
    final paid = trip.copyWith(payments: [GroupPayment(id: 'p', from: 'r', to: 'a', cents: 25000, createdAt: DateTime(2026, 11, 22))]);
    final owed = paid.settlements.where((s) => s.to == 'a').fold<int>(0, (t, s) => t + s.cents);
    expect(owed, 50000);
    expect(groupShareEntries([paid]).single.cents, 25000, reason: 'the payment is a transfer, not spending');
  });

  test('a group with no chosen member falls back to the first member', () {
    final noMe = trip.copyWith(meId: '');
    expect(noMe.myId, 'a');
  });
}
