import 'package:flutter/material.dart';

import '../../core/entry_store.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../shared/date_inputs.dart';

String _id() => DateTime.now().microsecondsSinceEpoch.toString();

String _dmy(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Purchases with warranty and return deadlines, so nothing expires without you noticing.
class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  List<Purchase> _items = [];
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await EntryStore.loadPurchases();
      if (mounted) setState(() {
        _items = list;
        _loaded = true;
      });
    } catch (e) {
      debugPrint('Purchases load failed: $e');
      if (mounted) setState(() {
        _error = e;
        _loaded = true;
      });
    }
  }

  Future<void> _save(List<Purchase> updated) async {
    setState(() => _items = updated);
    try {
      await EntryStore.savePurchases(updated);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The purchase could not be saved. Please try again.')));
    }
  }

  Future<void> _add() async {
    final result = await FormSheet.show<Purchase>(context, title: 'Add a purchase', child: const _PurchaseForm());
    if (result == null) return;
    await _save([result, ..._items]);
  }

  Future<void> _delete(Purchase p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this purchase?'),
        content: Text('"${p.name}" will be removed from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.monova.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _save(_items.where((x) => x.id != p.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final today = DateTime.now();
    final open = openWarranties(_items, today);
    return Scaffold(
      appBar: AppBar(title: const Text('Purchases and warranty')),
      floatingActionButton: _loaded && _error == null
          ? FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add_rounded), label: const Text('Add'))
          : null,
      body: !_loaded
          ? const LoadingBox()
          : _error != null
              ? const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not open purchases', message: 'Nothing has been changed. Close and open the page again.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    MonovaCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.verified_user_outlined, color: c.accentStart),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              open.isEmpty
                                  ? 'No warranty is running right now.'
                                  : '${open.length} ${open.length == 1 ? 'warranty is' : 'warranties are'} still running. The soonest ends ${_dmy(open.first.warrantyUntil!)}.',
                              style: TextStyle(color: c.ink, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_items.isEmpty)
                      EmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: 'No purchases yet',
                        message: 'Record what you bought, where, and the warranty. You will see when each one runs out.',
                        actionLabel: 'Add the first purchase',
                        onAction: _add,
                      )
                    else
                      for (final p in _items) ...[
                        _PurchaseTile(purchase: p, today: today, onDelete: () => _delete(p)),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({required this.purchase, required this.today, required this.onDelete});

  final Purchase purchase;
  final DateTime today;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final day = DateTime(today.year, today.month, today.day);
    final until = purchase.warrantyUntil;
    final left = until == null ? null : until.difference(day).inDays;
    final returnBy = purchase.returnBy;
    final returnOpen = returnBy != null && !returnBy.isBefore(day);
    return MonovaCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(purchase.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${purchase.retailer.isEmpty ? 'Shop not noted' : purchase.retailer} · ${_dmy(purchase.date)} · ${money(purchase.cents / 100)}',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (until != null)
                      _Chip(
                        text: left! >= 0 ? 'Warranty: $left days left' : 'Warranty ended ${_dmy(until)}',
                        color: left! >= 0 ? c.income : c.muted,
                      ),
                    if (returnOpen) _Chip(text: 'Return by ${_dmy(returnBy)}', color: c.warning),
                  ],
                ),
              ],
            ),
          ),
          IconButton(tooltip: 'Delete', icon: Icon(Icons.delete_outline_rounded, color: c.muted), onPressed: onDelete),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _PurchaseForm extends StatefulWidget {
  const _PurchaseForm();

  @override
  State<_PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends State<_PurchaseForm> {
  final _name = TextEditingController();
  final _retailer = TextEditingController();
  final _amount = TextEditingController();
  final _warranty = TextEditingController(text: '12');
  final _returnDays = TextEditingController(text: '0');
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _retailer.dispose();
    _amount.dispose();
    _warranty.dispose();
    _returnDays.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    final warranty = int.tryParse(_warranty.text.trim()) ?? -1;
    final ret = int.tryParse(_returnDays.text.trim()) ?? -1;
    if (name.isEmpty) {
      setState(() => _error = 'Name the item, for example "Ceiling fan".');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter the amount paid.');
      return;
    }
    if (warranty < 0 || warranty > 120 || ret < 0 || ret > 365) {
      setState(() => _error = 'Warranty is 0 to 120 months, and the return period is 0 to 365 days. Use 0 for none.');
      return;
    }
    Navigator.of(context).pop(Purchase(
      id: _id(),
      name: name,
      retailer: _retailer.text.trim(),
      cents: (amount * 100).round(),
      date: DateTime(_date.year, _date.month, _date.day),
      warrantyMonths: warranty,
      returnDays: ret,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _name, autofocus: true, textInputAction: TextInputAction.next, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Item')),
        const SizedBox(height: 12),
        TextField(controller: _retailer, textInputAction: TextInputAction.next, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Shop or website (optional)')),
        const SizedBox(height: 12),
        TextField(controller: _amount, textInputAction: TextInputAction.next, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount paid', prefixText: '₹ ')),
        const SizedBox(height: 12),
        DateSelector(label: 'Purchase date', value: _date, firstYear: 2000, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(controller: _warranty, textInputAction: TextInputAction.next, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Warranty (months)', helperText: '0 for none'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _returnDays, textInputAction: TextInputAction.done, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Return within (days)', helperText: '0 for none'))),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: const Text('Save purchase')),
      ],
    );
  }
}
