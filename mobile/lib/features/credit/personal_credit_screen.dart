import 'package:flutter/material.dart';

import '../../core/credit_ledger.dart';
import '../../core/format.dart';
import '../../core/personal_credit_store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Credit manager: money I lent to people or businesses, and money I borrowed. Recorded by hand, on this phone.
/// Separate from the customer book (Customers) and from bank, FD, SIP and savings balances.
class PersonalCreditScreen extends StatefulWidget {
  const PersonalCreditScreen({super.key});

  @override
  State<PersonalCreditScreen> createState() => _PersonalCreditScreenState();
}

class _PersonalCreditScreenState extends State<PersonalCreditScreen> {
  List<CreditAccount> _items = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await PersonalCreditStore.load();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loaded = true;
    });
  }

  Future<void> _write(List<CreditAccount> next) async {
    setState(() => _items = next);
    await PersonalCreditStore.save(next);
  }

  Future<void> _add() async {
    final item = await FormSheet.show<CreditAccount>(
      context,
      title: 'Add lending or borrowing',
      child: const _PersonalForm(),
    );
    if (item == null) return;
    await _write([..._items, item]);
  }

  Future<void> _open(CreditAccount a) async {
    await FormSheet.show<void>(
      context,
      title: a.name,
      child: _PersonalDetail(
        account: a,
        onChanged: (updated) =>
            _write([for (final x in _items) x.id == updated.id ? updated : x]),
        onDelete: () => _write([
          for (final x in _items)
            if (x.id != a.id) x,
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final today = DateTime.now();
    final t = personalCreditTotals(_items, today);
    final lent = [
      for (final a in _items)
        if (!a.iOwe) a,
    ];
    final borrowed = [
      for (final a in _items)
        if (a.iOwe) a,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Credit manager')),
      floatingActionButton: _loaded
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            )
          : null,
      body: !_loaded
          ? const LoadingBox()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                MonovaCard(
                  gradient: c.hero,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net balance',
                        style: TextStyle(
                          color: c.onAccent.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        money(t.net / 100),
                        style: TextStyle(
                          color: c.onAccent,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _figure(
                              'To receive (I lent)',
                              money(t.toReceive / 100),
                              c,
                            ),
                          ),
                          Expanded(
                            child: _figure(
                              'To pay (I borrowed)',
                              money(t.toPay / 100),
                              c,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionTitle('Money I lent'),
                const SizedBox(height: 8),
                if (lent.isEmpty)
                  Text(
                    'Nothing lent yet. Tap Add to record money you gave someone.',
                    style: TextStyle(color: c.muted),
                  )
                else
                  for (final a in lent) ...[
                    _tile(a, today, c),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 16),
                const SectionTitle('Money I borrowed'),
                const SizedBox(height: 8),
                if (borrowed.isEmpty)
                  Text(
                    'Nothing borrowed yet. Tap Add to record money you took from someone.',
                    style: TextStyle(color: c.muted),
                  )
                else
                  for (final a in borrowed) ...[
                    _tile(a, today, c),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 12),
                Text(
                  'Kept on this phone. Bank, FD, SIP and savings balances are shown separately, from the server.',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ],
            ),
    );
  }

  Widget _figure(String label, String value, MonovaColors c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: c.onAccent.withValues(alpha: 0.85),
          fontSize: 12,
        ),
      ),
      Text(
        value,
        style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w800),
      ),
    ],
  );

  Widget _tile(CreditAccount a, DateTime today, MonovaColors c) {
    final total = accountTotalCents(a, today);
    final party = a.partyType == 'thirdParty' ? 'Third party' : 'Person';
    final rate = a.annualRatePercent == 0
        ? 'no interest'
        : '${a.annualRatePercent}% a year simple';
    return MonovaCard(
      padding: const EdgeInsets.all(12),
      onTap: () => _open(a),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '$party · $rate',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            money(total / 100),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: a.iOwe ? c.expense : c.income,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalForm extends StatefulWidget {
  const _PersonalForm();

  @override
  State<_PersonalForm> createState() => _PersonalFormState();
}

class _PersonalFormState extends State<_PersonalForm> {
  bool _iLent = true;
  String _party = 'person';
  DateTime _date = DateTime.now();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _rate = TextEditingController(text: '0');
  final _notes = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _rate.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final name = _name.text.trim();
    final amount = parseAmount(_amount.text);
    final rate = double.tryParse(_rate.text.trim());
    String? problem;
    if (name.isEmpty) {
      problem = 'Enter the name of the person or business.';
    } else if (amount == null) {
      problem = 'Enter a positive amount.';
    } else if (rate == null || rate < 0) {
      problem = 'Enter the yearly interest. Use 0 for no interest.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final cents = (amount! * 100).round();
    final day = DateTime(_date.year, _date.month, _date.day);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    Navigator.pop(
      context,
      CreditAccount(
        id: id,
        name: name,
        phone: '',
        annualRatePercent: rate!,
        compound: false,
        iOwe: !_iLent,
        partyType: _party,
        bills: [
          CreditBill(
            id: '${id}b',
            date: day,
            billerName: name,
            description: _notes.text.trim().isEmpty
                ? (_iLent ? 'Lent' : 'Borrowed')
                : _notes.text.trim(),
            amountCents: cents,
            finalCents: cents,
            notes: _notes.text.trim(),
          ),
        ],
        payments: const [],
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
              ChoiceChip(
                label: const Text('I lent money'),
                selected: _iLent,
                onSelected: (_) => setState(() => _iLent = true),
              ),
              ChoiceChip(
                label: const Text('I borrowed money'),
                selected: !_iLent,
                onSelected: (_) => setState(() => _iLent = false),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('A person'),
                selected: _party == 'person',
                onSelected: (_) => setState(() => _party = 'person'),
              ),
              ChoiceChip(
                label: const Text('A third party (vendor, shop, business)'),
                selected: _party == 'thirdParty',
                onSelected: (_) => setState(() => _party = 'thirdParty'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: _party == 'person'
                  ? 'Person\'s name'
                  : 'Business or vendor name',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount (₹)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Text('Date: ${dayLabel(_date)}'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Interest % a year (0 for no interest)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: c.expense)),
          ],
          const SizedBox(height: 14),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}

class _PersonalDetail extends StatefulWidget {
  const _PersonalDetail({
    required this.account,
    required this.onChanged,
    required this.onDelete,
  });

  final CreditAccount account;
  final Future<void> Function(CreditAccount) onChanged;
  final Future<void> Function() onDelete;

  @override
  State<_PersonalDetail> createState() => _PersonalDetailState();
}

class _PersonalDetailState extends State<_PersonalDetail> {
  late CreditAccount _account = widget.account;

  Future<void> _repay() async {
    final p = await FormSheet.show<CreditPayment>(
      context,
      title: _account.iOwe
          ? 'Record payment I made'
          : 'Record money received back',
      child: const _RepaymentForm(),
    );
    if (p == null) return;
    final updated = _account.copyWith(payments: [..._account.payments, p]);
    setState(() => _account = updated);
    await widget.onChanged(updated);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text(
          '"${_account.name}" and its payments will be removed from this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.onDelete();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final today = DateTime.now();
    final s = computeStatement(_account, today);
    final principal = _account.bills.fold<int>(0, (x, b) => x + b.finalCents);
    final repaid = _account.payments.fold<int>(0, (x, p) => x + p.cents);
    final outstanding = accountTotalCents(_account, today);
    final payments = [..._account.payments]
      ..sort((a, b) => b.date.compareTo(a.date));
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_account.iOwe ? 'I borrowed' : 'I lent'} · ${_account.partyType == 'thirdParty' ? 'third party' : 'person'} · '
            '${_account.annualRatePercent == 0 ? 'no interest' : '${_account.annualRatePercent}% a year simple'}',
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _row('Amount', money(principal / 100), c),
          _row('Repaid so far', money(repaid / 100), c),
          _row('Interest so far', money(s.interestCents / 100), c),
          _row(
            _account.iOwe ? 'I still owe' : 'Still to receive',
            money(outstanding / 100),
            c,
            strong: true,
          ),
          const SizedBox(height: 12),
          Text(
            'Repayments',
            style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
          ),
          if (payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('None yet.', style: TextStyle(color: c.muted)),
            )
          else
            for (final p in payments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(money(p.cents / 100)),
                subtitle: Text(
                  '${dayLabel(p.date)}${p.note.isEmpty ? '' : ' · ${p.note}'}',
                ),
              ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _repay,
            icon: const Icon(Icons.payments_rounded),
            label: Text(
              _account.iOwe
                  ? 'Record payment I made'
                  : 'Record money received back',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _delete,
            style: OutlinedButton.styleFrom(foregroundColor: c.expense),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete this entry'),
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value,
    MonovaColors c, {
    bool strong = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: c.muted)),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _RepaymentForm extends StatefulWidget {
  const _RepaymentForm();

  @override
  State<_RepaymentForm> createState() => _RepaymentFormState();
}

class _RepaymentFormState extends State<_RepaymentForm> {
  DateTime _date = DateTime.now();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final amount = parseAmount(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Enter a positive amount.');
      return;
    }
    Navigator.pop(
      context,
      CreditPayment(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: DateTime(_date.year, _date.month, _date.day),
        cents: (amount * 100).round(),
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount (₹)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() => _date = picked);
          },
          icon: const Icon(Icons.event_rounded, size: 18),
          label: Text('Date: ${dayLabel(_date)}'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
