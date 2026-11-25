import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Every transaction, newest first. Search and type filters narrow the list; long-press actions refund or delete.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  final _search = TextEditingController();
  final List<TransactionItem> _items = [];
  String? _type;
  int _page = 0;
  int _totalPages = 1;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadNext(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadNext({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _page = 0;
      _totalPages = 1;
    }
    if (_page >= _totalPages) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(repositoryProvider).transactions(
            page: _page + 1,
            search: _search.text.trim(),
            type: _type,
          );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(result.items);
        _page = result.page;
        _totalPages = result.totalPages == 0 ? 1 : result.totalPages;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(TransactionItem t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text(t.isExpense ? 'Its balance effect and any refunds will be reversed.' : 'Its balance effect will be reversed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await runAction(context, () => ref.read(repositoryProvider).deleteTransaction(t.id), success: 'Deleted');
    if (ok) {
      ref.invalidate(dashboardProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(cardsProvider);
      _loadNext(reset: true);
    }
  }

  Future<void> _refund(TransactionItem t) async {
    final controller = TextEditingController();
    final amount = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record a refund'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Refund amount (up to ${money(t.amount - t.refundedTotal)})'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Refund')),
        ],
      ),
    );
    controller.dispose();
    if (amount == null) return;
    final value = parseAmount(amount);
    if (value == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a positive amount')));
      return;
    }
    final ok = await runAction(context, () => ref.read(repositoryProvider).refund(t.id, value), success: 'Refund recorded');
    if (ok) {
      ref.invalidate(dashboardProvider);
      ref.invalidate(accountsProvider);
      _loadNext(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final grouped = <DateTime, List<TransactionItem>>{};
    for (final t in _items) {
      final day = DateTime(t.occurredOn.year, t.occurredOn.month, t.occurredOn.day);
      grouped.putIfAbsent(day, () => []).add(t);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: RefreshIndicator(
        onRefresh: () => _loadNext(reset: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _loadNext(reset: true),
              decoration: InputDecoration(
                hintText: 'Search title or note',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          _loadNext(reset: true);
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in const {null: 'All', 'Expense': 'Expenses', 'Income': 'Income', 'Refund': 'Refunds'}.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _type == entry.key,
                    onSelected: (_) {
                      setState(() => _type = entry.key);
                      _loadNext(reset: true);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null && _items.isEmpty)
              ErrorState(error: _error!, onRetry: () => _loadNext(reset: true))
            else if (!_loading && _items.isEmpty)
              const EmptyState(icon: Icons.receipt_long_rounded, title: 'Nothing here yet', message: 'Expenses, income and refunds will appear here.'),
            for (final day in days) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(relativeDay(day), style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
              ),
              MonovaCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final t in grouped[day]!)
                      ListTile(
                        onLongPress: () => showModalBottomSheet(
                          context: context,
                          builder: (ctx) => SafeArea(
                            child: Wrap(children: [
                              if (t.isExpense)
                                ListTile(
                                  leading: const Icon(Icons.undo_rounded),
                                  title: const Text('Record a refund'),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _refund(t);
                                  },
                                ),
                              ListTile(
                                leading: Icon(Icons.delete_outline_rounded, color: c.expense),
                                title: Text('Delete', style: TextStyle(color: c.expense)),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _delete(t);
                                },
                              ),
                            ]),
                          ),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: c.border,
                          child: Icon(
                            t.isIncome ? Icons.trending_up_rounded : (t.isRefund ? Icons.undo_rounded : Icons.shopping_bag_outlined),
                            color: c.ink,
                            size: 18,
                          ),
                        ),
                        title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [t.categoryName, t.accountName ?? (t.creditCardName == null ? null : 'Card · ${t.creditCardName}')]
                              .whereType<String>()
                              .join(' · '),
                          style: TextStyle(color: c.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: AmountText(
                          t.isExpense ? '−${money(t.amount)}' : '+${money(t.amount)}',
                          tone: t.isExpense ? AmountTone.neutral : AmountTone.income,
                          size: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (_loading) const LoadingBox(),
            if (!_loading && _page < _totalPages && _items.isNotEmpty)
              Center(child: TextButton(onPressed: () => _loadNext(), child: const Text('Load more'))),
          ],
        ),
      ),
    );
  }
}
