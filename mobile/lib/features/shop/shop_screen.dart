import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/shop_store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Daily shop bills: what came in, what went out, what is on credit and what is still to pay, day by day.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  List<ShopEntry> _all = const [];
  bool _loaded = false;
  DateTime _day = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ShopStore.load();
    if (!mounted) return;
    setState(() {
      _all = list;
      _loaded = true;
    });
  }

  Future<void> _write(List<ShopEntry> next) async {
    setState(() => _all = next);
    await ShopStore.save(next);
  }

  Future<void> _add() async {
    final entry = await FormSheet.show<ShopEntry>(
      context,
      title: 'Add entry',
      child: _ShopEntryForm(day: _day),
    );
    if (entry == null) return;
    await _write([..._all, entry]);
  }

  Future<void> _edit(ShopEntry e) async {
    final updated = await FormSheet.show<ShopEntry>(
      context,
      title: 'Edit entry',
      child: _ShopEntryForm(day: e.day, initial: e),
    );
    if (updated == null) return;
    await _write([for (final x in _all) x.id == e.id ? updated : x]);
  }

  Future<void> _delete(ShopEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text('${shopKindLabel(e.kind)} of ${money(e.amountCents / 100)} will be removed from this day.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _write([for (final x in _all) if (x.id != e.id) x]);
  }

  void _moveDay(int days) => setState(() => _day = _day.add(Duration(days: days)));

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final isToday = _day == _today();
    final entries = [for (final e in _all) if (e.day == _day) e]..sort((a, b) => a.kind.index.compareTo(b.kind.index));
    final t = shopTotalsFor(_all, _day);
    return Scaffold(
      appBar: AppBar(title: const Text('Daily expenses')),
      floatingActionButton: _loaded
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add entry'),
            )
          : null,
      body: !_loaded
          ? const LoadingBox()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                Row(
                  children: [
                    IconButton(onPressed: () => _moveDay(-1), icon: const Icon(Icons.chevron_left_rounded)),
                    Expanded(
                      child: Text(
                        isToday ? 'Today · ${dayLabel(_day)}' : dayLabel(_day),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(onPressed: () => _moveDay(1), icon: const Icon(Icons.chevron_right_rounded)),
                  ],
                ),
                MonovaCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Figure(label: 'Expenses on this day', value: money(t.cashOut / 100), color: c.expense),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const SectionTitle('Entries'),
                const SizedBox(height: 8),
                if (entries.isEmpty)
                  const EmptyState(
                    icon: Icons.storefront_rounded,
                    title: 'No entries on this day',
                    message: 'Add an expense you paid, such as tea, fuel or electricity. Tap an entry to correct it.',
                  )
                else
                  for (final e in entries) ...[
                    MonovaCard(
                      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                      onTap: () => _edit(e),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.party.isEmpty ? e.description : '${e.party} · ${e.description}',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '${shopKindLabel(e.kind)}${e.kind == ShopKind.expense ? '' : (e.paid ? ' · paid' : ' · not paid yet')}',
                                  style: TextStyle(color: c.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            money(e.amountCents / 100),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: e.kind == ShopKind.sale ? c.income : c.expense,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: Icon(Icons.delete_outline_rounded, color: c.muted),
                            onPressed: () => _delete(e),
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
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _ShopEntryForm extends StatefulWidget {
  const _ShopEntryForm({required this.day, this.initial});

  final DateTime day;
  final ShopEntry? initial;

  @override
  State<_ShopEntryForm> createState() => _ShopEntryFormState();
}

class _ShopEntryFormState extends State<_ShopEntryForm> {
  late ShopKind _kind = widget.initial?.kind ?? ShopKind.expense;
  late bool _paid = widget.initial?.paid ?? true;
  late final _party = TextEditingController(text: widget.initial?.party ?? '');
  late final _description = TextEditingController(text: widget.initial?.description ?? '');
  late final _amount = TextEditingController(
    text: widget.initial == null ? '' : (widget.initial!.amountCents / 100).toStringAsFixed(2),
  );
  String? _error;

  @override
  void dispose() {
    _party.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final amount = parseAmount(_amount.text);
    final desc = _description.text.trim();
    final party = _party.text.trim();
    String? problem;
    if (amount == null) {
      problem = 'Enter a positive amount, for example 250 or 1499.50.';
    } else if (desc.isEmpty) {
      problem = 'Describe the entry, for example "Urea 2 bags" or "Electricity bill".';
    } else if (_kind != ShopKind.expense && party.isEmpty) {
      problem = _kind == ShopKind.sale ? 'Enter the customer name.' : 'Enter the supplier name.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final day = DateTime(widget.day.year, widget.day.month, widget.day.day);
    Navigator.pop(
      context,
      ShopEntry(
        id: widget.initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        day: widget.initial?.day ?? day,
        kind: _kind,
        party: _kind == ShopKind.expense ? '' : party,
        description: desc,
        amountCents: (amount! * 100).round(),
        paid: _kind == ShopKind.expense ? true : _paid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final k in const [ShopKind.expense])
                ChoiceChip(
                  label: Text(shopKindLabel(k)),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_kind != ShopKind.expense)
            TextField(
              controller: _party,
              decoration: InputDecoration(labelText: _kind == ShopKind.sale ? 'Customer name' : 'Supplier name'),
            ),
          if (_kind != ShopKind.expense) const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'What is it? (for example Urea 2 bags)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount (₹)'),
          ),
          if (_kind != ShopKind.expense) ...[
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_kind == ShopKind.sale ? 'Customer has paid' : 'Bill is paid'),
              subtitle: Text(
                _kind == ShopKind.sale
                    ? 'Off means it is on credit. Customer credit with interest is kept separately.'
                    : 'Off means it is still to pay.',
                style: TextStyle(color: c.muted, fontSize: 12),
              ),
              value: _paid,
              onChanged: (v) => setState(() => _paid = v),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: c.expense)),
          ],
          const SizedBox(height: 14),
          FilledButton(onPressed: _save, child: const Text('Save entry')),
        ],
      ),
    );
  }
}
