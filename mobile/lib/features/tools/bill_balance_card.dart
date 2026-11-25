import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/bill_store.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Who owes whom across every bill saved on this device. Shown on the dashboard.
class BillBalanceCard extends StatefulWidget {
  const BillBalanceCard({super.key});

  @override
  State<BillBalanceCard> createState() => _BillBalanceCardState();
}

class _BillBalanceCardState extends State<BillBalanceCard> {
  List<SavedBill>? _bills;
  Object? _error;

  @override
  void initState() {
    super.initState();
    BillStore.load().then((bills) {
      if (mounted) setState(() => _bills = bills);
    }).catchError((Object e) {
      debugPrint('Bill load failed: $e');
      if (mounted) setState(() => _error = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final bills = _bills;
    return MonovaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Bill balances', style: Theme.of(context).textTheme.titleMedium)),
              TextButton(onPressed: () => context.push('/tools/split'), child: const Text('Split a bill')),
            ],
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Text('Saved bills could not be read. Nothing was changed.', style: TextStyle(color: c.expense, fontSize: 13))
          else if (bills == null)
            const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
          else if (bills.isEmpty)
            Text(
              'Split a bill and tap "Save this bill". Who owes whom will show here, across all your saved bills.',
              style: TextStyle(color: c.muted, fontSize: 13, height: 1.4),
            )
          else ...[
            for (final entry in (netBalances(bills).entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(
                      entry.value > 0
                          ? 'is owed ${money(entry.value / 100)}'
                          : 'owes ${money(-entry.value / 100)}',
                      style: TextStyle(
                        color: entry.value > 0 ? c.income : c.expense,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (netBalances(bills).isEmpty)
              Text('Every saved bill is settled.', style: TextStyle(color: c.muted, fontSize: 13)),
            const SizedBox(height: 6),
            Text('${bills.length} saved ${bills.length == 1 ? 'bill' : 'bills'}', style: TextStyle(color: c.muted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
