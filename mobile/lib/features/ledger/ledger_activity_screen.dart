import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/ledger_activity.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Everything added, edited, deleted or settled for customers, newest first, with who did it and the reason given.
class LedgerActivityScreen extends StatefulWidget {
  const LedgerActivityScreen({super.key});

  @override
  State<LedgerActivityScreen> createState() => _LedgerActivityScreenState();
}

class _LedgerActivityScreenState extends State<LedgerActivityScreen> {
  List<LedgerActivity> _items = const [];
  bool _loaded = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await LedgerActivityStore.load();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final e in _items)
        if (q.isEmpty ||
            e.customer.toLowerCase().contains(q) ||
            e.label.toLowerCase().contains(q) ||
            e.who.toLowerCase().contains(q))
          e,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Activity log')),
      body: !_loaded
          ? const LoadingBox()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search by customer, item or person',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Kept on this phone. Every add, edit, delete and settlement is listed here with who did it and the reason.',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (shown.isEmpty)
                  EmptyState(
                    icon: Icons.history_rounded,
                    title: 'Nothing recorded yet',
                    message: 'Changes to customers, bills and payments will appear here.',
                  ),
                for (final e in shown) ...[
                  MonovaCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_actionLabel(e.action)} ${_kindLabel(e.kind)} · ${e.customer}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: e.action == 'deleted'
                                      ? c.expense
                                      : c.ink,
                                ),
                              ),
                            ),
                            Text(
                              dayLabel(e.at),
                              style: TextStyle(color: c.muted, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(e.label, style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          'By ${e.who} at ${_time(e.at)}',
                          style: TextStyle(color: c.muted, fontSize: 12),
                        ),
                        if (e.reason.isNotEmpty)
                          Text(
                            'Reason: ${e.reason}',
                            style: TextStyle(color: c.muted, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }

  static String _actionLabel(String a) => switch (a) {
    'added' => 'Added',
    'edited' => 'Edited',
    'deleted' => 'Deleted',
    'settled' => 'Settled',
    _ => a,
  };

  static String _kindLabel(String k) => switch (k) {
    'bill' => 'bill',
    'payment' => 'payment',
    'customer' => 'customer',
    _ => k,
  };

  static String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
