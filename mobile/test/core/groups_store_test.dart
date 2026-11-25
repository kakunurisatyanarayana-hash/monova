import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/groups_store.dart';

void main() {
  test('equal shares add up exactly to the total, leftover paisa go to the first people', () {
    final shares = equalShares(1000, ['a', 'b', 'c']);
    expect(shares.values.fold<int>(0, (s, v) => s + v), 1000);
    expect(shares['a'], 334);
    expect(shares['c'], 333);
  });

  test('balances and who pays whom for a group', () {
    final group = LocalGroup(
      id: 'g',
      name: 'Trip',
      members: const [GroupMember(id: 'a', name: 'Asha'), GroupMember(id: 'b', name: 'Ravi'), GroupMember(id: 'c', name: 'Meena')],
      expenses: [
        GroupExpense(
          id: '1', title: 'Hotel', cents: 90000, paidBy: 'a',
          shares: equalShares(90000, ['a', 'b', 'c']), createdAt: DateTime(2026, 11, 25),
        ),
        GroupExpense(
          id: '2', title: 'Fuel', cents: 30000, paidBy: 'b',
          shares: const {'a': 30000}, createdAt: DateTime(2026, 11, 25),
        ),
      ],
    );
    final net = group.netByMember;
    expect(net.values.fold<int>(0, (s, v) => s + v), 0, reason: 'money in and out always balance');
    expect(net['a'], 60000 - 30000);
    expect(net['b'], -30000 + 30000);
    expect(net['c'], -30000);

    final payments = group.settlements;
    expect(payments, hasLength(1));
    expect(payments.single.from, 'c');
    expect(payments.single.to, 'a');
    expect(payments.single.cents, 30000);
  });

  test('a group survives a JSON round trip', () {
    final group = LocalGroup(
      id: 'g', name: 'Flat',
      members: const [GroupMember(id: 'a', name: 'A'), GroupMember(id: 'b', name: 'B')],
      expenses: [GroupExpense(id: '1', title: 'Rent', cents: 1001, paidBy: 'a', shares: equalShares(1001, ['a', 'b']), createdAt: DateTime.utc(2026))],
    );
    final back = LocalGroup.fromJson(group.toJson());
    expect(back.name, 'Flat');
    expect(back.expenses.single.shares.values.fold<int>(0, (s, v) => s + v), 1001);
  });
}
