import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/entry_store.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../shared/date_inputs.dart';

const incomeCategories = ['Salary', 'Business income', 'Freelance income', 'Rental income', 'Other income'];
const spendingCategories = [
  'Food', 'Groceries', 'Shopping', 'Transport', 'Healthcare', 'Education', 'Utilities', 'Housing', 'Farming', 'Business',
  'Entertainment', 'Other',
];

String _id() => DateTime.now().microsecondsSinceEpoch.toString();

String _dmy(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Income and spending: a monthly summary, spending by category, every entry, and CSV export.
class EntriesScreen extends StatefulWidget {
  const EntriesScreen({super.key});

  @override
  State<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends State<EntriesScreen> {
  List<MoneyEntry> _entries = [];
  bool _loaded = false;
  Object? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await EntryStore.loadEntries();
      if (mounted) setState(() {
        _entries = list;
        _loaded = true;
      });
    } catch (e) {
      debugPrint('Entries load failed: $e');
      if (mounted) setState(() {
        _error = e;
        _loaded = true;
      });
    }
  }

  Future<void> _save(List<MoneyEntry> updated) async {
    setState(() => _entries = updated);
    try {
      await EntryStore.saveEntries(updated);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The entry could not be saved. Please try again.')));
    }
  }

  Future<void> _add({MoneyEntry? existing}) async {
    if (existing != null && existing.id.startsWith('prop-')) {
      _fromPropertyNotice();
      return;
    }
    final result = await FormSheet.show<MoneyEntry>(
      context,
      title: existing == null ? 'Add income or spending' : 'Edit entry',
      child: _EntryForm(initial: existing),
    );
    if (result == null) return;
    final updated = [for (final e in _entries) if (e.id != result.id) e, result]..sort((a, b) => b.date.compareTo(a.date));
    await _save(updated);
  }

  void _fromPropertyNotice() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('This was recorded from a property. Change it under Property and rooms.'),
    ));
  }

  Future<void> _delete(MoneyEntry e) async {
    if (e.id.startsWith('prop-')) {
      _fromPropertyNotice();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text('"${e.title}" ${money(e.cents / 100)} will be removed.'),
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
    await _save(_entries.where((x) => x.id != e.id).toList());
  }

  Future<void> _copyCsv() async {
    await Clipboard.setData(ClipboardData(text: entriesToCsv(_entries)));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copied. Paste it into a spreadsheet.')));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final now = DateTime.now();
    final month = monthSummary(_entries, now.year, now.month);
    final categories = spendingByCategory(_entries, now.year, now.month);
    final shown = _entries.where((e) => _filter == 'all' || (_filter == 'income' ? e.income : !e.income)).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Income and spending'),
        actions: [
          IconButton(tooltip: 'Copy as CSV', icon: const Icon(Icons.table_chart_outlined), onPressed: _entries.isEmpty ? null : _copyCsv),
        ],
      ),
      floatingActionButton: _loaded && _error == null
          ? FloatingActionButton.extended(onPressed: () => _add(), icon: const Icon(Icons.add_rounded), label: const Text('Add'))
          : null,
      body: !_loaded
          ? const LoadingBox()
          : _error != null
              ? const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not open your entries', message: 'Nothing has been changed. Close and open the page again.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    MonovaCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('This month', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _Figure(label: 'Income', value: money(month.income / 100), color: c.income)),
                              Expanded(child: _Figure(label: 'Spent', value: money(month.spent / 100), color: c.expense)),
                              Expanded(child: _Figure(label: 'Saved', value: money(month.savings / 100), color: month.savings >= 0 ? c.accentStart : c.expense)),
                            ],
                          ),
                          if (categories.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text('Where it went', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            for (final cat in categories.take(5))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(cat.key)),
                                        Text(money(cat.value / 100), style: const TextStyle(fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ProgressBar(value: month.spent == 0 ? 0 : cat.value * 100 / month.spent, color: c.expense),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(value: 'income', label: Text('Income')),
                        ButtonSegment(value: 'spent', label: Text('Spending')),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (s) => setState(() => _filter = s.first),
                    ),
                    const SizedBox(height: 12),
                    if (_entries.isEmpty)
                      EmptyState(
                        icon: Icons.swap_vert_rounded,
                        title: 'No entries yet',
                        message: 'Record your salary, business income, and everyday spending to see where your money goes.',
                        actionLabel: 'Add the first entry',
                        onAction: () => _add(),
                      )
                    else if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('Nothing in this list.', style: TextStyle(color: c.muted))),
                      )
                    else
                      for (final e in shown) ...[
                        MonovaCard(
                          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                          onTap: () => _add(existing: e),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(color: (e.income ? c.income : c.expense).withValues(alpha: 0.14), shape: BoxShape.circle),
                                child: Icon(e.income ? Icons.south_west_rounded : Icons.north_east_rounded, size: 18, color: e.income ? c.income : c.expense),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text('${e.category} · ${_dmy(e.date)}', style: TextStyle(color: c.muted, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Text(
                                '${e.income ? '+' : '-'} ${money(e.cents / 100)}',
                                style: TextStyle(color: e.income ? c.income : c.expense, fontWeight: FontWeight.w700),
                              ),
                              IconButton(tooltip: 'Delete', icon: Icon(Icons.delete_outline_rounded, color: c.muted), onPressed: () => _delete(e)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
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
        Text(label, style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800))),
      ],
    );
  }
}

class _EntryForm extends StatefulWidget {
  const _EntryForm({this.initial});

  final MoneyEntry? initial;

  @override
  State<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<_EntryForm> {
  late bool _income = widget.initial?.income ?? false;
  late DateTime _date = widget.initial?.date ?? DateTime.now();
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _amount = TextEditingController(text: widget.initial == null ? '' : (widget.initial!.cents / 100).toStringAsFixed(2));
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');
  late String _category = widget.initial?.category ?? (_income ? incomeCategories.first : spendingCategories.first);
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _setType(bool income) {
    setState(() {
      _income = income;
      final list = income ? incomeCategories : spendingCategories;
      if (!list.contains(_category)) _category = list.first;
    });
  }

  void _save() {
    final title = _title.text.trim();
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (title.isEmpty) {
      setState(() => _error = 'Describe it, for example "Salary" or "Milk and bread".');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    Navigator.of(context).pop(MoneyEntry(
      id: widget.initial?.id ?? _id(),
      income: _income,
      title: title,
      category: _category,
      cents: (amount * 100).round(),
      date: DateTime(_date.year, _date.month, _date.day),
      notes: _notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final categories = _income ? incomeCategories : spendingCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Spent'), icon: Icon(Icons.north_east_rounded)),
            ButtonSegment(value: true, label: Text('Income'), icon: Icon(Icons.south_west_rounded)),
          ],
          selected: {_income},
          onSelectionChanged: (s) => _setType(s.first),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          autofocus: widget.initial == null,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'What was it for?'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          textInputAction: TextInputAction.next,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('cat-$_income'),
          initialValue: categories.contains(_category) ? _category : categories.first,
          menuMaxHeight: 260,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [for (final cat in categories) DropdownMenuItem(value: cat, child: Text(cat))],
          onChanged: (v) => setState(() => _category = v ?? _category),
        ),
        const SizedBox(height: 12),
        DateSelector(label: 'Date', value: _date, firstYear: 2000, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: Text(widget.initial == null ? 'Save' : 'Save changes')),
      ],
    );
  }
}
