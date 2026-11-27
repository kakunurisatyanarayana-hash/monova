import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/bill_store.dart';
import '../../core/entry_store.dart';
import '../../core/credit_ledger.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// One line in the activity list: what happened, when, and whether money came in or went out.
class _Activity {
  const _Activity({required this.date, required this.title, required this.subtitle, required this.cents, required this.incoming});

  final DateTime date;
  final String title;
  final String subtitle;
  final int cents;

  /// True for money received (a payment), false for money given out (a bill or a split).
  final bool incoming;
}

/// The latest credit book bills and payments, and split bills, newest first.
class RecentActivityCard extends StatefulWidget {
  const RecentActivityCard({super.key});

  @override
  State<RecentActivityCard> createState() => _RecentActivityCardState();
}

class _RecentActivityCardState extends State<RecentActivityCard> {
  List<_Activity>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = <_Activity>[];
    try {
      final accounts = await CreditLedgerStore.load();
      for (final a in accounts) {
        for (final b in a.bills) {
          items.add(_Activity(
            date: b.date,
            title: b.description.isEmpty ? 'Bill for ${a.name}' : b.description,
            subtitle: '${a.name} · ${_short(b.date)}',
            cents: b.finalCents,
            incoming: false,
          ));
        }
        for (final p in a.payments) {
          items.add(_Activity(
            date: p.date,
            title: p.note.isEmpty ? 'Payment received' : 'Payment: ${p.note}',
            subtitle: '${a.name} · ${_short(p.date)}',
            cents: p.cents,
            incoming: true,
          ));
        }
      }
      final bills = await BillStore.load();
      for (final b in bills) {
        items.add(_Activity(
          date: b.createdAt,
          title: b.title.isEmpty ? 'Split bill' : b.title,
          subtitle: 'Paid by ${b.payer} · ${_short(b.createdAt)}',
          cents: b.totalCents,
          incoming: false,
        ));
      }
      final entries = await EntryStore.loadEntries();
      for (final e in entries) {
        items.add(_Activity(
          date: e.date,
          title: e.title,
          subtitle: '${e.category}${e.notes.isEmpty ? '' : ' · ${e.notes}'} · ${_short(e.date)}',
          cents: e.cents,
          incoming: e.income,
        ));
      }
    } catch (_) {
      // A damaged list shows as empty instead of breaking the home page.
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) setState(() => _items = items.take(6).toList());
  }

  static String _short(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final items = _items;
    return MonovaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Recent activity', style: Theme.of(context).textTheme.titleMedium)),
              TextButton(onPressed: () => context.push('/ledger'), child: const Text('Credit book')),
            ],
          ),
          const SizedBox(height: 4),
          if (items == null)
            const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Bills, payments and split bills you record will appear here, newest first.',
                style: TextStyle(color: c.muted, fontSize: 13, height: 1.4),
              ),
            )
          else
            for (final a in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: (a.incoming ? c.income : c.expense).withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        a.incoming ? Icons.south_west_rounded : Icons.north_east_rounded,
                        size: 18,
                        color: a.incoming ? c.income : c.expense,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(a.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${a.incoming ? '+' : '-'} ${money(a.cents / 100)}',
                      style: TextStyle(color: a.incoming ? c.income : c.expense, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
