import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/groups_store.dart';

void main() {
  test('recording the suggested payments settles the group, which then has nothing left to settle', () {
    final g = LocalGroup(
      id: 'g',
      name: 'Trip',
      members: const [GroupMember(id: 'a', name: 'Asha'), GroupMember(id: 'r', name: 'Ravi')],
      expenses: [
        GroupExpense(id: 'e1', title: 'Dinner', cents: 30000, paidBy: 'a', shares: const {'a': 15000, 'r': 15000}, createdAt: DateTime(2026, 11, 1)),
      ],
    );
    expect(g.settlements.length, 1);
    expect(g.settlements.single.from, 'r');
    expect(g.settlements.single.cents, 15000);

    final s = g.settlements.single;
    final settled = g.copyWith(payments: [
      GroupPayment(id: 'p', from: s.from, to: s.to, cents: s.cents, createdAt: DateTime(2026, 11, 2)),
    ]);
    expect(settled.netByMember.values.every((v) => v == 0), isTrue);
    expect(settled.settlements, isEmpty);
  });

  test('payments survive a save and reload', () {
    final g = LocalGroup(
      id: 'g',
      name: 'Flat',
      members: const [GroupMember(id: 'a', name: 'Asha')],
      expenses: const [],
      payments: [GroupPayment(id: 'p', from: 'a', to: 'b', cents: 500, createdAt: DateTime(2026, 11, 2))],
    );
    final back = LocalGroup.fromJson(g.toJson());
    expect(back.payments.single.cents, 500);
  });
}
