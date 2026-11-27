import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/bill_store.dart';
import '../../core/format.dart';
import '../../core/groups_store.dart';
import '../../core/profile_store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';


/// Who owes you and whom you owe, across every saved split bill and every group on this phone.
class BillBalanceCard extends StatefulWidget {
  const BillBalanceCard({super.key});

  @override
  State<BillBalanceCard> createState() => _BillBalanceCardState();
}

class _BillBalanceCardState extends State<BillBalanceCard> {
  List<SavedBill>? _bills;
  List<LocalGroup> _groups = const [];
  String _me = '';
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bills = await BillStore.load();
      final groups = await GroupStore.load();
      final profile = await loadProfile();
      if (mounted) setState(() {
        _bills = bills;
        _groups = groups;
        _me = profile?.name.trim() ?? '';
      });
    } catch (e) {
      debugPrint('Balance load failed: $e');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final bills = _bills;
    if (_error != null) {
      return MonovaCard(
        padding: const EdgeInsets.all(18),
        child: Text('Balances could not be read. Nothing was changed.', style: TextStyle(color: c.expense)),
      );
    }
    if (bills == null) {
      return const MonovaCard(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator()));
    }
    final balances = youBalances(bills: bills, groups: _groups, me: _me);
    final owedToYou = balances.values.where((v) => v > 0).fold<int>(0, (t, v) => t + v);
    final youOwe = balances.values.where((v) => v < 0).fold<int>(0, (t, v) => t - v);
    final people = balances.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return MonovaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Split balances', style: Theme.of(context).textTheme.titleMedium)),
              TextButton(onPressed: () => context.push('/tools/split'), child: const Text('Split a bill')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _Total(label: 'Owed to you', value: money(owedToYou / 100), color: c.income)),
              Expanded(child: _Total(label: 'You owe', value: money(youOwe / 100), color: c.expense)),
            ],
          ),
          const SizedBox(height: 10),
          if (people.isEmpty)
            Text(
              'Nothing owed either way. Split a bill or add a group expense, and balances will show here.',
              style: TextStyle(color: c.muted, fontSize: 13, height: 1.4),
            )
          else
            for (final p in people)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(p.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(
                      p.value > 0 ? 'owes you ${money(p.value / 100)}' : 'you owe ${money(-p.value / 100)}',
                      style: TextStyle(color: p.value > 0 ? c.income : c.expense, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 6),
          Text(
            '${bills.length} saved ${bills.length == 1 ? 'bill' : 'bills'} · ${_groups.length} ${_groups.length == 1 ? 'group' : 'groups'}',
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
        Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
      ],
    );
  }
}
