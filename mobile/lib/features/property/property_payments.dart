import 'package:monova_app/core/input_rules.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/property_money.dart';
import '../../core/property_store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../shared/date_inputs.dart';

int _cents(String text) {
  final v = double.tryParse(text.replaceAll(',', '').trim());
  if (v == null || v <= 0) return 0;
  return (v * 100).round();
}

String kindLabel(String kind) => switch (kind) {
  'rent' => 'Rent received',
  'advance' => 'Advance received',
  'deposit' => 'Deposit received',
  'refund' => 'Deposit refunded',
  _ => 'Expense',
};

/// The payment form, for a new payment or to edit one. A property-level form (no guest) also records expenses.
class PaymentForm extends StatefulWidget {
  const PaymentForm({
    super.key,
    required this.propertyId,
    this.personId = '',
    this.roomId = '',
    this.tenancyId = '',
    this.expenseOnly = false,
    this.initial,
  });

  final String propertyId;
  final String personId;
  final String roomId;
  final String tenancyId;
  final bool expenseOnly;

  /// The payment being edited. Its id, guest and stay are kept.
  final Payment? initial;

  @override
  State<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  late final _amount = TextEditingController(
    text: widget.initial == null
        ? ''
        : (widget.initial!.amountCents / 100).toStringAsFixed(2),
  );
  late final _period = TextEditingController(
    text: widget.initial?.periodLabel ?? '',
  );
  late final _reference = TextEditingController(
    text: widget.initial?.reference ?? '',
  );
  late final _note = TextEditingController(text: widget.initial?.note ?? '');
  late String _kind =
      widget.initial?.kind ?? (widget.expenseOnly ? 'expense' : 'rent');
  late String _method = widget.initial?.method ?? paymentMethods.first;
  late String _category = widget.initial?.category.isNotEmpty == true
      ? widget.initial!.category
      : expenseCategories.first;
  late DateTime _date = widget.initial?.date ?? dayOnly(DateTime.now());
  String? _error;

  /// Expenses are offered only at property level, not on a guest's page.
  bool get _canRecordExpense => widget.personId.isEmpty;

  @override
  void dispose() {
    _amount.dispose();
    _period.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final cents = _cents(_amount.text);
    if (cents <= 0) {
      setState(() => _error = 'Enter the amount.');
      return;
    }
    final base = widget.initial;
    Navigator.of(context).pop(
      Payment(
        id: base?.id ?? PropertyStore.newId(),
        propertyId: base?.propertyId ?? widget.propertyId,
        kind: _kind,
        amountCents: cents,
        date: _date,
        roomId: base?.roomId ?? widget.roomId,
        tenancyId: base?.tenancyId ?? widget.tenancyId,
        personId: base?.personId ?? widget.personId,
        method: _method,
        periodLabel: _kind == 'rent' || _kind == 'advance'
            ? _period.text.trim()
            : '',
        reference: _reference.text.trim(),
        note: _note.text.trim(),
        category: _kind == 'expense' ? _category : '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final isExpense = _kind == 'expense';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _kind,
          decoration: const InputDecoration(labelText: 'What is this for?'),
          items: [
            if (!widget.expenseOnly || isExpense)
              const DropdownMenuItem(
                value: 'rent',
                child: Text('Rent received'),
              ),
            if (!widget.expenseOnly || isExpense)
              const DropdownMenuItem(
                value: 'advance',
                child: Text('Advance received'),
              ),
            if (!widget.expenseOnly || isExpense)
              const DropdownMenuItem(
                value: 'deposit',
                child: Text('Deposit received (kept separately)'),
              ),
            if (!widget.expenseOnly || isExpense)
              const DropdownMenuItem(
                value: 'refund',
                child: Text('Deposit refunded'),
              ),
            if (_canRecordExpense || isExpense)
              const DropdownMenuItem(
                value: 'expense',
                child: Text('Expense (electricity, repairs...)'),
              ),
          ],
          onChanged: (v) => setState(() => _kind = v ?? _kind),
        ),
        const SizedBox(height: 12),
        if (isExpense) ...[
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Expense type'),
            items: [
              for (final cat in expenseCategories)
                DropdownMenuItem(value: cat, child: Text(cat)),
            ],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _amount,
          autofocus: widget.initial == null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: amountFormatters,
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '₹ ',
          ),
        ),
        const SizedBox(height: 12),
        DateSelector(
          label: 'Date',
          value: _date,
          firstYear: 2020,
          onChanged: (d) => setState(() => _date = d),
        ),
        const SizedBox(height: 12),
        if (_kind == 'rent' || _kind == 'advance') ...[
          TextField(
            controller: _period,
            decoration: const InputDecoration(
              labelText: 'Month or period (optional)',
              hintText: 'Dec 2026',
            ),
          ),
          const SizedBox(height: 12),
        ],
        DropdownButtonFormField<String>(
          initialValue: _method,
          decoration: const InputDecoration(labelText: 'How was it paid?'),
          items: [
            for (final m in paymentMethods)
              DropdownMenuItem(value: m, child: Text(m)),
          ],
          onChanged: (v) => setState(() => _method = v ?? _method),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reference,
          decoration: const InputDecoration(
            labelText: 'Reference number (optional)',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _save,
          child: Text(
            widget.initial == null
                ? (isExpense ? 'Save expense' : 'Save payment')
                : 'Save changes',
          ),
        ),
      ],
    );
  }
}

/// Every payment of one scope (a guest, or a property), with totals, and add, edit and delete.
/// Changes go back through [onChanged], which saves them and updates Monova Finance.
class PaymentsSection extends StatelessWidget {
  const PaymentsSection({
    super.key,
    required this.book,
    required this.payments,
    required this.onChanged,
    required this.propertyId,
    this.title = 'Payments',
    this.personId = '',
    this.roomId = '',
    this.tenancyId = '',
    this.expenseOnly = false,
  });

  final PropertyBook book;
  final List<Payment> payments;
  final ValueChanged<PropertyBook> onChanged;
  final String propertyId;
  final String title;
  final String personId;
  final String roomId;
  final String tenancyId;
  final bool expenseOnly;

  Future<void> _add(BuildContext context) async {
    final p = await FormSheet.show<Payment>(
      context,
      title: expenseOnly ? 'Add an expense' : 'Record a transaction',
      child: PaymentForm(
        propertyId: propertyId,
        personId: personId,
        roomId: roomId,
        tenancyId: tenancyId,
        expenseOnly: expenseOnly,
      ),
    );
    if (p == null) return;
    onChanged(book.copyWith(payments: [...book.payments, p]));
  }

  Future<void> _edit(BuildContext context, Payment p) async {
    final updated = await FormSheet.show<Payment>(
      context,
      title: 'Edit ${kindLabel(p.kind).toLowerCase()}',
      child: PaymentForm(
        propertyId: p.propertyId,
        personId: p.personId,
        roomId: p.roomId,
        tenancyId: p.tenancyId,
        expenseOnly: expenseOnly,
        initial: p,
      ),
    );
    if (updated == null) return;
    onChanged(
      book.copyWith(
        payments: [for (final x in book.payments) x.id == p.id ? updated : x],
      ),
    );
  }

  Future<void> _delete(BuildContext context, Payment p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this transaction?'),
        content: Text(
          '${kindLabel(p.kind)} of ${money(p.amountCents / 100)} will be removed from the records and from Monova Finance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.monova.expense,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    onChanged(
      book.copyWith(
        payments: [
          for (final x in book.payments)
            if (x.id != p.id) x,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    var income = 0;
    var spent = 0;
    for (final p in payments) {
      if (p.isIncome) income += p.amountCents;
      if (p.isExpense) spent += p.amountCents;
    }
    final shown = [...payments]..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SectionTitle(title)),
            TextButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(expenseOnly ? 'Add expense' : 'Add'),
            ),
          ],
        ),
        MonovaCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: _Total(
                  label: 'Income',
                  value: money(income / 100),
                  color: c.income,
                ),
              ),
              Expanded(
                child: _Total(
                  label: 'Expenses',
                  value: money(spent / 100),
                  color: c.expense,
                ),
              ),
              Expanded(
                child: _Total(
                  label: 'Net',
                  value: money((income - spent) / 100),
                  color: income >= spent ? c.income : c.expense,
                ),
              ),
              Expanded(
                child: _Total(
                  label: 'Entries',
                  value: '${payments.length}',
                  color: c.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          MonovaCard(
            child: Text(
              expenseOnly
                  ? 'No expenses recorded yet. Electricity, water and repairs go here.'
                  : 'No transactions recorded yet.',
              style: TextStyle(color: c.muted),
            ),
          )
        else
          for (final p in shown.take(40)) ...[
            MonovaCard(
              padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
              onTap: () => _edit(context, p),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${kindLabel(p.kind)}${p.category.isEmpty ? '' : ' · ${p.category}'}${p.periodLabel.isEmpty ? '' : ' · ${p.periodLabel}'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${dayLabel(p.date)} · ${p.method}${p.reference.isEmpty ? '' : ' · ref ${p.reference}'}${p.note.isEmpty ? '' : ' · ${p.note}'}',
                          style: TextStyle(color: c.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${p.isExpense || p.kind == 'refund' ? '−' : ''}${money(p.amountCents / 100)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: p.isExpense || p.kind == 'refund'
                          ? c.expense
                          : c.income,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit',
                    icon: Icon(Icons.edit_outlined, color: c.accentStart),
                    onPressed: () => _edit(context, p),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: Icon(Icons.delete_outline_rounded, color: c.muted),
                    onPressed: () => _delete(context, p),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: c.muted, fontSize: 11)),
      ],
    );
  }
}

/// This month's rent, expenses, net, and deposits held for a property (or all properties when [propertyId] is null).
class MoneyThisMonth extends StatelessWidget {
  const MoneyThisMonth({super.key, required this.book, this.propertyId});

  final PropertyBook book;
  final String? propertyId;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final now = DateTime.now();
    final m = monthMoney(
      book,
      propertyId: propertyId,
      year: now.year,
      month: now.month,
    );
    Widget tile(String label, String value, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
        ],
      ),
    );
    return MonovaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Money in ${monthLabel(now.year, now.month)}',
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              tile('Rent collected', money(m.rentCents / 100), c.income),
              tile('Expenses', money(m.expenseCents / 100), c.expense),
              tile(
                'Net',
                money(m.netCents / 100),
                m.netCents >= 0 ? c.income : c.expense,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Deposits held: ${money(m.depositsHeldCents / 100)} (kept separately, not counted as income)',
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
