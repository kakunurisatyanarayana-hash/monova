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

String _kindLabel(String kind) => switch (kind) {
      'rent' => 'Rent received',
      'advance' => 'Advance received',
      'deposit' => 'Deposit received',
      'refund' => 'Deposit refunded',
      _ => 'Expense',
    };

/// The payment form. [expenseOnly] is used on the property dashboard; otherwise the guest's payment kinds are offered.
class PaymentForm extends StatefulWidget {
  const PaymentForm({
    super.key,
    required this.propertyId,
    this.personId = '',
    this.roomId = '',
    this.tenancyId = '',
    this.expenseOnly = false,
  });

  final String propertyId;
  final String personId;
  final String roomId;
  final String tenancyId;
  final bool expenseOnly;

  @override
  State<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  final _amount = TextEditingController();
  final _period = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  late String _kind = widget.expenseOnly ? 'expense' : 'rent';
  String _method = paymentMethods.first;
  String _category = expenseCategories.first;
  DateTime _date = dayOnly(DateTime.now());
  String? _error;

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
    Navigator.of(context).pop(Payment(
      id: PropertyStore.newId(),
      propertyId: widget.propertyId,
      kind: _kind,
      amountCents: cents,
      date: _date,
      roomId: widget.roomId,
      tenancyId: widget.tenancyId,
      personId: widget.personId,
      method: _method,
      periodLabel: _kind == 'rent' || _kind == 'advance' ? _period.text.trim() : '',
      reference: _reference.text.trim(),
      note: _note.text.trim(),
      category: _kind == 'expense' ? _category : '',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final isExpense = _kind == 'expense';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.expenseOnly)
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'What is this payment for?'),
            items: const [
              DropdownMenuItem(value: 'rent', child: Text('Rent received')),
              DropdownMenuItem(value: 'advance', child: Text('Advance received')),
              DropdownMenuItem(value: 'deposit', child: Text('Deposit received (kept separately)')),
              DropdownMenuItem(value: 'refund', child: Text('Deposit refunded')),
            ],
            onChanged: (v) => setState(() => _kind = v ?? _kind),
          ),
        if (!widget.expenseOnly) const SizedBox(height: 12),
        if (isExpense) ...[
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Expense type'),
            items: [for (final cat in expenseCategories) DropdownMenuItem(value: cat, child: Text(cat))],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
        ),
        const SizedBox(height: 12),
        DateSelector(label: 'Date', value: _date, firstYear: 2020, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 12),
        if (_kind == 'rent' || _kind == 'advance') ...[
          TextField(controller: _period, decoration: const InputDecoration(labelText: 'Month or period (optional)', hintText: 'Dec 2026')),
          const SizedBox(height: 12),
        ],
        DropdownButtonFormField<String>(
          initialValue: _method,
          decoration: const InputDecoration(labelText: 'How was it paid?'),
          items: [for (final m in paymentMethods) DropdownMenuItem(value: m, child: Text(m))],
          onChanged: (v) => setState(() => _method = v ?? _method),
        ),
        const SizedBox(height: 12),
        TextField(controller: _reference, decoration: const InputDecoration(labelText: 'Reference number (optional)')),
        const SizedBox(height: 12),
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)')),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: Text(isExpense ? 'Save expense' : 'Save payment')),
      ],
    );
  }
}

/// A list of payments with add and delete. Used on a person's page (guest payments) and on the property dashboard (expenses).
class PaymentsSection extends StatelessWidget {
  const PaymentsSection({
    super.key,
    required this.book,
    required this.payments,
    required this.onChanged,
    required this.propertyId,
    this.personId = '',
    this.roomId = '',
    this.tenancyId = '',
    this.expenseOnly = false,
  });

  final PropertyBook book;
  final List<Payment> payments;
  final ValueChanged<PropertyBook> onChanged;
  final String propertyId;
  final String personId;
  final String roomId;
  final String tenancyId;
  final bool expenseOnly;

  Future<void> _add(BuildContext context) async {
    final p = await FormSheet.show<Payment>(
      context,
      title: expenseOnly ? 'Add an expense' : 'Record a payment',
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

  Future<void> _delete(BuildContext context, Payment p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this payment?'),
        content: Text('${_kindLabel(p.kind)} of ${money(p.amountCents / 100)} will be removed from the records and from Monova Finance.'),
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
    onChanged(book.copyWith(payments: [for (final x in book.payments) if (x.id != p.id) x]));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SectionTitle(expenseOnly ? 'Expenses' : 'Payments')),
            TextButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(expenseOnly ? 'Add expense' : 'Record payment'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (payments.isEmpty)
          MonovaCard(
            child: Text(
              expenseOnly ? 'No expenses recorded yet. Electricity, water and repairs go here.' : 'No payments recorded yet.',
              style: TextStyle(color: c.muted),
            ),
          )
        else
          for (final p in payments.take(20)) ...[
            MonovaCard(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_kindLabel(p.kind)}${p.category.isEmpty ? '' : ' · ${p.category}'}${p.periodLabel.isEmpty ? '' : ' · ${p.periodLabel}'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${dayLabel(p.date)} · ${p.method}${p.reference.isEmpty ? '' : ' · ref ${p.reference}'}',
                          style: TextStyle(color: c.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${p.isExpense || p.kind == 'refund' ? '−' : ''}${money(p.amountCents / 100)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: p.isExpense || p.kind == 'refund' ? c.expense : c.income,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete payment',
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

/// This month's rent, expenses, net, and deposits held for a property (or all properties when [propertyId] is null).
class MoneyThisMonth extends StatelessWidget {
  const MoneyThisMonth({super.key, required this.book, this.propertyId});

  final PropertyBook book;
  final String? propertyId;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final now = DateTime.now();
    final m = monthMoney(book, propertyId: propertyId, year: now.year, month: now.month);
    Widget tile(String label, String value, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
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
          Text('Money in ${monthLabel(now.year, now.month)}', style: TextStyle(color: c.muted, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              tile('Rent collected', money(m.rentCents / 100), c.income),
              tile('Expenses', money(m.expenseCents / 100), c.expense),
              tile('Net', money(m.netCents / 100), m.netCents >= 0 ? c.income : c.expense),
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
