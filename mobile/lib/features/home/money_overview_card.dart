import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/bill_store.dart';
import '../../core/card_store.dart';
import '../../core/credit_ledger.dart';
import '../../core/format.dart';
import '../../core/groups_store.dart';
import '../../core/theme.dart';
import '../../core/vault_store.dart';
import '../../core/widgets.dart';

/// One place for everything the app is tracking: what customers owe, what groups and bills still need to settle,
/// and how many cards, passwords and notes are saved. Every figure is read from this device.
class MoneyOverviewCard extends StatefulWidget {
  const MoneyOverviewCard({super.key});

  @override
  State<MoneyOverviewCard> createState() => _MoneyOverviewCardState();
}

class _MoneyOverviewCardState extends State<MoneyOverviewCard> {
  _Totals? _totals;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final accounts = await CreditLedgerStore.load();
      final today = dateOnly(DateTime.now());
      var creditDue = 0;
      for (final a in accounts) {
        creditDue += computeStatement(a, today).totalCents;
      }

      final groups = await GroupStore.load();
      var groupsToSettle = 0;
      var groupPayments = 0;
      for (final g in groups) {
        final s = g.settlements;
        groupPayments += s.length;
        for (final p in s) {
          groupsToSettle += p.cents;
        }
      }

      final bills = await BillStore.load();
      var billPayments = 0;
      for (final b in bills) {
        billPayments += b.settlements.length;
      }

      final cards = await CardStore.load();
      final vault = await VaultStore.load();

      if (mounted) {
        setState(() => _totals = _Totals(
              creditDue: creditDue,
              creditCustomers: accounts.length,
              groupsToSettle: groupsToSettle,
              groupPayments: groupPayments,
              billsSaved: bills.length,
              billPayments: billPayments,
              cards: cards.length,
              vault: vault.length,
            ));
      }
    } catch (e) {
      debugPrint('Money overview failed: $e');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final t = _totals;
    return MonovaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Money overview', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Everything is read from this device.', style: TextStyle(color: c.muted, fontSize: 12)),
          const SizedBox(height: 14),
          if (_error != null)
            Text('The overview could not be read. Your data has not changed.', style: TextStyle(color: c.expense))
          else if (t == null)
            const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
          else ...[
            Row(
              children: [
                Expanded(
                  child: _Tile(
                    label: 'Credit book due today',
                    value: money(t.creditDue / 100),
                    note: '${t.creditCustomers} ${t.creditCustomers == 1 ? 'customer' : 'customers'}',
                    color: t.creditDue > 0 ? c.expense : c.income,
                    onTap: () => context.push('/ledger'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Tile(
                    label: 'Groups to settle',
                    value: money(t.groupsToSettle / 100),
                    note: '${t.groupPayments} ${t.groupPayments == 1 ? 'payment' : 'payments'} to make',
                    color: t.groupsToSettle > 0 ? c.warning : c.income,
                    onTap: () => context.push('/groups'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Tile(
                    label: 'Split bills saved',
                    value: '${t.billsSaved}',
                    note: '${t.billPayments} ${t.billPayments == 1 ? 'payment' : 'payments'} to make',
                    color: c.accentStart,
                    onTap: () => context.push('/tools/split'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Tile(
                    label: 'Saved cards',
                    value: '${t.cards}',
                    note: 'details and photos',
                    color: c.accentStart,
                    onTap: () => context.push('/saved-cards'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Tile(
                    label: 'Passwords and notes',
                    value: '${t.vault}',
                    note: 'stored on this device',
                    color: c.accentStart,
                    onTap: () => context.push('/vault'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Totals {
  const _Totals({
    required this.creditDue,
    required this.creditCustomers,
    required this.groupsToSettle,
    required this.groupPayments,
    required this.billsSaved,
    required this.billPayments,
    required this.cards,
    required this.vault,
  });

  final int creditDue;
  final int creditCustomers;
  final int groupsToSettle;
  final int groupPayments;
  final int billsSaved;
  final int billPayments;
  final int cards;
  final int vault;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.note, required this.color, required this.onTap});

  final String label;
  final String value;
  final String note;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
