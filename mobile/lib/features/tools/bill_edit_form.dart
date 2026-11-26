import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/bill_store.dart';
import '../../core/finance_calc.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Changes a saved bill: what it was for, the amount, who paid, who shared it, and notes.
/// The amount is split equally among the people listed, and who pays whom is worked out again.
class BillEditForm extends StatefulWidget {
  const BillEditForm({super.key, required this.bill});

  final SavedBill bill;

  @override
  State<BillEditForm> createState() => _BillEditFormState();
}

class _BillEditFormState extends State<BillEditForm> {
  late final _title = TextEditingController(text: widget.bill.title);
  late final _total = TextEditingController(text: (widget.bill.totalCents / 100).toStringAsFixed(2));
  late final _people = TextEditingController(text: widget.bill.people.join(', '));
  late final _notes = TextEditingController(text: widget.bill.notes);
  late String _payer = widget.bill.payer;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _total.dispose();
    _people.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<String> get _names => _people.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();

  void _save() {
    final names = _names;
    final amount = double.tryParse(_total.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter the amount of the bill.');
      return;
    }
    if (names.length < 2) {
      setState(() => _error = 'Add at least two people, separated by commas.');
      return;
    }
    final payer = names.contains(_payer) ? _payer : names.first;
    final totalCents = (amount * 100).round();
    final shares = FinanceCalc.splitCents(
      totalCents: totalCents,
      mode: 'equal',
      values: List<double?>.filled(names.length, null),
    );
    final net = <String, int>{for (var i = 0; i < names.length; i++) names[i]: -shares[i]};
    net[payer] = (net[payer] ?? 0) + totalCents;
    final payments = FinanceCalc.settle(net);

    Navigator.of(context).pop(SavedBill(
      id: widget.bill.id,
      title: _title.text.trim(),
      createdAt: widget.bill.createdAt,
      totalCents: totalCents,
      payer: payer,
      people: names,
      notes: _notes.text.trim(),
      settlements: [for (final p in payments) Settlement(from: p.from, to: p.to, cents: p.cents)],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final names = _names;
    final payerValue = names.contains(_payer) ? _payer : (names.isEmpty ? null : names.first);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(textInputAction: TextInputAction.next, controller: _title, decoration: const InputDecoration(labelText: 'What was this bill for?')),
        const SizedBox(height: 12),
        TextField(textInputAction: TextInputAction.next, 
          controller: _total,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Total amount', prefixText: '₹ '),
        ),
        const SizedBox(height: 12),
        TextField(textInputAction: TextInputAction.next, 
          controller: _people,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'People (separate with commas)', helperText: 'Each person shares the bill equally.'),
        ),
        const SizedBox(height: 12),
        if (names.length >= 2)
          DropdownButtonFormField<String>(
            initialValue: payerValue,
            menuMaxHeight: 260,
            decoration: const InputDecoration(labelText: 'Who paid the bill?'),
            items: [for (final n in names) DropdownMenuItem(value: n, child: Text(n))],
            onChanged: (v) => setState(() => _payer = v ?? _payer),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Notes (optional)', alignLabelWithHint: true),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: const Text('Save changes')),
      ],
    );
  }
}

/// Opens the edit form for a saved bill and returns the changed bill, or null if cancelled.
Future<SavedBill?> editSavedBill(BuildContext context, SavedBill bill) {
  return FormSheet.show<SavedBill>(context, title: 'Edit bill', child: BillEditForm(bill: bill));
}
