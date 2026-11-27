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

/// Everything the app is tracking, read from this device: what customers owe, what groups and split bills
/// still need to settle, and how many cards and notes are saved. Each tile opens its page.
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
      final today = dateOnly(DateTime.now());
      final accounts = await CreditLedgerStore.load();
      var creditDue = 0;
      for (final a in accounts) {
        creditDue += computeStatement(a, today).totalCents;
      }

      final groups = await GroupStore.load();
      var groupsToSettle = 0;
      var groupPayments = 0;
      for (final g in groups) {
        for (final p in g.settlements) {
          groupsToSettle += p.cents;
          groupPayments++;
        }
      }

      final bills = await BillStore.load();
      var billsToSettle = 0;
      var billPayments = 0;
      for (final b in bills) {
        for (final s in b.settlements) {
          billsToSettle += s.cents;
          billPayments++;
        }
      }

      final cards = await CardStore.load();
      final notes = await VaultStore.load();

      if (mounted) {
        setState(
          () => _totals = _Totals(
            creditDue: creditDue,
            creditCustomers: accounts.length,
            groupsToSettle: groupsToSettle,
            groupPayments: groupPayments,
            billsToSettle: billsToSettle,
            billPayments: billPayments,
            billsSaved: bills.length,
            cards: cards.length,
            notes: notes.length,
          ),
        );
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
          Text(
            'Money overview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            'Read from this device only',
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Text(
              'The overview could not be read. Your data has not changed.',
              style: TextStyle(color: c.expense),
            )
          else if (t == null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 104,
              ),
              children: [
                _Tile(
                  label: 'Credit book due',
                  value: money(t.creditDue / 100),
                  note:
                      '${t.creditCustomers} ${t.creditCustomers == 1 ? 'customer' : 'customers'}',
                  color: t.creditDue > 0 ? c.expense : c.income,
                  onTap: () => context.push('/ledger'),
                ),
                _Tile(
                  label: 'Groups to settle',
                  value: money(t.groupsToSettle / 100),
                  note:
                      '${t.groupPayments} ${t.groupPayments == 1 ? 'payment' : 'payments'}',
                  color: t.groupsToSettle > 0 ? c.warning : c.income,
                  onTap: () => context.push('/groups'),
                ),
                _Tile(
                  label: 'Split bills to settle',
                  value: money(t.billsToSettle / 100),
                  note:
                      '${t.billsSaved} saved, ${t.billPayments} ${t.billPayments == 1 ? 'payment' : 'payments'}',
                  color: t.billsToSettle > 0 ? c.warning : c.income,
                  onTap: () => context.push('/tools/split'),
                ),
                _Tile(
                  label: 'Cards and notes',
                  value: '${t.cards} · ${t.notes}',
                  note: 'cards saved · notes saved',
                  color: c.accentStart,
                  onTap: () => context.push('/saved-cards'),
                ),
              ],
            ),
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
    required this.billsToSettle,
    required this.billPayments,
    required this.billsSaved,
    required this.cards,
    required this.notes,
  });

  final int creditDue;
  final int creditCustomers;
  final int groupsToSettle;
  final int groupPayments;
  final int billsToSettle;
  final int billPayments;
  final int billsSaved;
  final int cards;
  final int notes;
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.note,
    required this.color,
    required this.onTap,
  });

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
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
