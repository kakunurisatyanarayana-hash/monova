import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/bill_store.dart';
import 'package:monova_app/core/groups_store.dart';

void main() {
  test('a bill where you paid for Ravi means Ravi owes you; a bill where Meena paid for you means you owe her', () {
    final bills = [
      SavedBill(id: '1', title: 'Dinner', createdAt: DateTime(2026, 11, 20), totalCents: 50000, payer: 'Asha', people: const ['Asha', 'Ravi'], settlements: const [Settlement(from: 'Ravi', to: 'Asha', cents: 25000)]),
      SavedBill(id: '2', title: 'Tickets', createdAt: DateTime(2026, 11, 21), totalCents: 30000, payer: 'Meena', people: const ['Asha', 'Meena'], settlements: const [Settlement(from: 'Asha', to: 'Meena', cents: 15000)]),
    ];
    final b = youBalances(bills: bills, groups: const [], me: 'Asha');
    expect(b['Ravi'], 25000);
    expect(b['Meena'], -15000);
  });

  test('group settlements count the same way, and cancel out when paid', () {
    final g = LocalGroup(
      id: 'g',
      name: 'Trip',
      members: const [GroupMember(id: 'a', name: 'Asha'), GroupMember(id: 'r', name: 'Ravi')],
      expenses: [GroupExpense(id: 'e', title: 'Fuel', cents: 60000, paidBy: 'a', shares: const {'a': 30000, 'r': 30000}, createdAt: DateTime(2026, 11, 22))],
      meId: 'a',
    );
    expect(youBalances(bills: const [], groups: [g], me: 'Asha')['Ravi'], 30000);
    final paid = g.copyWith(payments: [GroupPayment(id: 'p', from: 'r', to: 'a', cents: 30000, createdAt: DateTime(2026, 11, 23))]);
    expect(youBalances(bills: const [], groups: [paid], me: 'Asha'), isEmpty);
  });
}
