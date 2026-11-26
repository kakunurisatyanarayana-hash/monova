import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/bill_scanner.dart';
import '../../core/credit_ledger.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../shared/date_inputs.dart';

String _id() => DateTime.now().microsecondsSinceEpoch.toString();

String _dateText(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _monthLabel(String key) {
  final parts = key.split('-');
  return '${_monthNames[int.parse(parts[1]) - 1]} ${parts[0]}';
}

/// Credit book for shops: customers, the bills given on credit, payments, and interest calculated day by day.
class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  List<CreditAccount> _accounts = [];
  bool _loaded = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final accounts = await CreditLedgerStore.load();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _loaded = true;
      });
    }
  }

  Future<void> _newCustomer() async {
    final account = await FormSheet.show<CreditAccount>(context, title: 'New customer', child: const _AccountForm());
    if (account == null) return;
    final updated = [..._accounts, account];
    setState(() => _accounts = updated);
    await CreditLedgerStore.save(updated);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final today = dateOnly(DateTime.now());
    final shown = _accounts.where((a) => a.name.toLowerCase().contains(_query.trim().toLowerCase())).toList();
    final totalOutstanding = _accounts.fold<int>(0, (sum, a) => sum + computeStatement(a, today).totalCents);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit book'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _loaded ? _newCustomer : null,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('New customer'),
            ),
          ),
        ],
      ),
      body: !_loaded
          ? const LoadingBox()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                MonovaCard(
                  gradient: c.aurora,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total due today', style: TextStyle(color: c.onAccent.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(money(totalOutstanding / 100), style: TextStyle(color: c.onAccent, fontSize: 30, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${_accounts.length} ${_accounts.length == 1 ? 'customer' : 'customers'}, including interest up to today',
                          style: TextStyle(color: c.onAccent.withValues(alpha: 0.85), fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_accounts.length > 3)
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(hintText: 'Search customers', prefixIcon: Icon(Icons.search_rounded)),
                  ),
                const SizedBox(height: 12),
                if (_accounts.isEmpty)
                  EmptyState(
                    icon: Icons.menu_book_rounded,
                    title: 'No customers yet',
                    message: 'Add a customer, then record each bill given on credit and each payment. Interest is worked out for every day.',
                    actionLabel: 'Add the first customer',
                    onAction: _newCustomer,
                  )
                else
                  for (final a in shown) ...[
                    _CustomerTile(
                      account: a,
                      today: today,
                      onTap: () async {
                        await context.push('/ledger/${a.id}');
                        await _reload();
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.account, required this.today, required this.onTap});

  final CreditAccount account;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final s = computeStatement(account, today);
    return MonovaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(gradient: c.aurora, borderRadius: BorderRadius.circular(14)),
            child: Center(
              child: Text(account.name.isEmpty ? '?' : account.name[0].toUpperCase(),
                  style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w800, fontSize: 18)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '${account.annualRatePercent}% a year · ${account.compound ? 'compound' : 'simple'} · interest ${money(s.interestCents / 100)}',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(money(s.totalCents / 100), style: TextStyle(fontWeight: FontWeight.w800, color: s.totalCents > 0 ? c.expense : c.income)),
              Text(s.totalCents > 0 ? 'due' : (s.totalCents < 0 ? 'advance' : 'clear'), style: TextStyle(color: c.muted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountForm extends StatefulWidget {
  const _AccountForm({this.initial});

  final CreditAccount? initial;

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _phone = TextEditingController(text: widget.initial?.phone ?? '');
  late final _rate = TextEditingController(text: (widget.initial?.annualRatePercent ?? 24).toString());
  late bool _compound = widget.initial?.compound ?? false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _save() {
    final rate = double.tryParse(_rate.text.trim());
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter the customer name.');
      return;
    }
    if (rate == null || rate < 0 || rate > 120) {
      setState(() => _error = 'Enter the yearly interest rate, from 0 to 120.');
      return;
    }
    final initial = widget.initial;
    Navigator.of(context).pop(initial == null
        ? CreditAccount(id: _id(), name: _name.text.trim(), phone: _phone.text.trim(), annualRatePercent: rate, compound: _compound, bills: const [], payments: const [])
        : initial.copyWith(name: _name.text.trim(), phone: _phone.text.trim(), annualRatePercent: rate, compound: _compound));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Customer name')),
        const SizedBox(height: 12),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
        const SizedBox(height: 12),
        TextField(
          controller: _rate,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Interest per year (%)', helperText: 'Charged every day on the amount owed, divided by 365.'),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _compound,
          contentPadding: EdgeInsets.zero,
          title: const Text('Add interest to the balance'),
          subtitle: Text('Off: simple interest on the bills. On: interest also earns interest each day.', style: TextStyle(color: c.muted, fontSize: 12)),
          onChanged: (v) => setState(() => _compound = v),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: Text(widget.initial == null ? 'Save customer' : 'Save changes')),
      ],
    );
  }
}

class LedgerAccountScreen extends StatefulWidget {
  const LedgerAccountScreen({super.key, required this.id});

  final String id;

  @override
  State<LedgerAccountScreen> createState() => _LedgerAccountScreenState();
}

class _LedgerAccountScreenState extends State<LedgerAccountScreen> {
  CreditAccount? _account;
  bool _loaded = false;
  DateTime _asOf = dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final all = await CreditLedgerStore.load();
    final matches = all.where((a) => a.id == widget.id).toList();
    if (mounted) {
      setState(() {
        _account = matches.isEmpty ? null : matches.first;
        _loaded = true;
      });
    }
  }

  Future<void> _save(CreditAccount updated) async {
    setState(() => _account = updated);
    final all = await CreditLedgerStore.load();
    await CreditLedgerStore.save([for (final a in all) a.id == updated.id ? updated : a]);
  }

  Future<void> _addBill() async {
    final account = _account;
    if (account == null) return;
    final bill = await FormSheet.show<CreditBill>(context, title: 'Add a bill', child: _BillForm(defaultBiller: account.name));
    if (bill == null) return;
    await _save(account.copyWith(bills: [...account.bills, bill]));
  }

  Future<void> _addPayment() async {
    final account = _account;
    if (account == null) return;
    final payment = await FormSheet.show<CreditPayment>(context, title: 'Record a payment', child: const _PaymentForm());
    if (payment == null) return;
    await _save(account.copyWith(payments: [...account.payments, payment]));
  }

  Future<void> _editTerms() async {
    final account = _account;
    if (account == null) return;
    final updated = await FormSheet.show<CreditAccount>(context, title: 'Edit customer', child: _AccountForm(initial: account));
    if (updated != null) await _save(updated);
  }

  Future<void> _deleteCustomer() async {
    final account = _account;
    if (account == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this customer?'),
        content: Text('"${account.name}" with all bills and payments will be removed from this device.'),
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
    final all = await CreditLedgerStore.load();
    await CreditLedgerStore.save(all.where((a) => a.id != account.id).toList());
    if (mounted) context.pop();
  }

  Future<void> _pickAsOf() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOf,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _asOf = dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final account = _account;
    return Scaffold(
      appBar: AppBar(
        title: Text(account?.name ?? 'Customer'),
        actions: [
          if (account != null) ...[
            IconButton(tooltip: 'Edit interest and details', icon: const Icon(Icons.tune_rounded), onPressed: _editTerms),
            IconButton(tooltip: 'Delete customer', icon: Icon(Icons.delete_outline_rounded, color: c.expense), onPressed: _deleteCustomer),
          ],
        ],
      ),
      floatingActionButton: account == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(heroTag: 'payment', onPressed: _addPayment, icon: const Icon(Icons.payments_rounded), label: const Text('Payment')),
                const SizedBox(height: 10),
                FloatingActionButton.extended(heroTag: 'bill', onPressed: _addBill, icon: const Icon(Icons.receipt_long_rounded), label: const Text('Add bill')),
              ],
            ),
      body: !_loaded
          ? const LoadingBox()
          : account == null
              ? const EmptyState(icon: Icons.menu_book_rounded, title: 'Customer not found', message: 'It may have been deleted.')
              : _body(context, account),
    );
  }

  Widget _body(BuildContext context, CreditAccount account) {
    final c = context.monova;
    final s = computeStatement(account, _asOf);
    final months = s.interestByMonth.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        MonovaCard(
          gradient: c.aurora,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Final amount on ${_dateText(_asOf)}',
                        style: TextStyle(color: c.onAccent.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
                  ),
                  TextButton.icon(
                    onPressed: _pickAsOf,
                    icon: Icon(Icons.event_rounded, color: c.onAccent, size: 18),
                    label: Text('Change date', style: TextStyle(color: c.onAccent)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(money(s.totalCents / 100), style: TextStyle(color: c.onAccent, fontSize: 34, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _sum('Bills and unpaid amount', money(s.principalCents / 100), c),
              _sum('Interest so far (${account.annualRatePercent}% a year)', money(s.interestCents / 100), c),
              _sum('Paid so far', money(s.totalPaidCents / 100), c),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MonovaCard(
          padding: const EdgeInsets.all(14),
          child: Text(
            account.compound
                ? 'Interest is worked out every day and added to the balance, so it also earns interest.'
                : 'Interest is worked out every day on the amount owed (simple interest). Payments clear the interest first.',
            style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
          ),
        ),
        const SizedBox(height: 16),
        Text('Statement', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (s.lines.isEmpty)
          Text('No bills or payments yet. Tap "Add bill" to start.', style: TextStyle(color: c.muted))
        else
          MonovaCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final line in s.lines.where((l) => !l.date.isAfter(_asOf)))
                  ListTile(
                    dense: true,
                    title: Text(line.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(_dateText(line.date), style: TextStyle(color: c.muted, fontSize: 12)),
                    trailing: Text(
                      line.creditCents > 0 ? '- ${money(line.creditCents / 100)}' : '+ ${money(line.debitCents / 100)}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: line.creditCents > 0 ? c.income : c.expense),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Text('Interest by month', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (months.isEmpty)
          Text('Interest starts the day after the first bill.', style: TextStyle(color: c.muted))
        else
          MonovaCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final m in months)
                  ListTile(
                    dense: true,
                    title: Text(_monthLabel(m.key)),
                    trailing: Text(money(m.value / 100), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _sum(String label, String value, MonovaColors c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: c.onAccent.withValues(alpha: 0.9), fontSize: 13))),
            Text(value, style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _BillForm extends StatefulWidget {
  const _BillForm({required this.defaultBiller});

  final String defaultBiller;

  @override
  State<_BillForm> createState() => _BillFormState();
}

class _BillFormState extends State<_BillForm> {
  DateTime _date = dateOnly(DateTime.now());
  late final _biller = TextEditingController(text: widget.defaultBiller);
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _final = TextEditingController();
  String? _error;
  String? _scanNote;

  @override
  void dispose() {
    _biller.dispose();
    _description.dispose();
    _amount.dispose();
    _final.dispose();
    super.dispose();
  }

  /// Reads a bill photo and fills in what it can find. Each value is shown in its box, so the user checks it before saving.
  Future<void> _scan() async {
    String note;
    try {
      final parsed = await scanBillPhoto(camera: false);
      setState(() {
        if (parsed.date != null) _date = dateOnly(parsed.date!);
        if (parsed.billerName != null && parsed.billerName!.isNotEmpty) _biller.text = parsed.billerName!;
        if (parsed.amountRupees != null) {
          _final.text = parsed.amountRupees!.toStringAsFixed(2);
        }
      });
      final found = [
        if (parsed.date != null) 'date',
        if (parsed.billerName != null) 'biller',
        if (parsed.amountRupees != null) 'amount',
      ];
      note = found.isEmpty
          ? 'Nothing could be read from this photo. Type the details by hand.'
          : 'Read from the bill: ${found.join(', ')}. Check them before saving.';
    } on BillScanException catch (e) {
      note = e.message;
    } catch (e) {
      note = 'The photo could not be read. $e';
    }
    if (mounted) setState(() => _scanNote = note);
  }

  void _save() {
    final finalAmount = double.tryParse(_final.text.replaceAll(',', '').trim());
    final gross = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (finalAmount == null || finalAmount <= 0) {
      setState(() => _error = 'Enter the final price to be paid for this bill.');
      return;
    }
    if (gross != null && gross < finalAmount) {
      setState(() => _error = 'The final price cannot be more than the amount before discount.');
      return;
    }
    final finalCents = (finalAmount * 100).round();
    Navigator.of(context).pop(CreditBill(
      id: _id(),
      date: _date,
      billerName: _biller.text.trim(),
      description: _description.text.trim(),
      amountCents: gross == null ? finalCents : (gross * 100).round(),
      finalCents: finalCents,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _scan,
          icon: const Icon(Icons.document_scanner_rounded, size: 18),
          label: const Text('Scan a bill photo'),
        ),
        if (_scanNote != null) ...[
          const SizedBox(height: 6),
          Text(_scanNote!, style: TextStyle(color: c.muted, fontSize: 12, height: 1.4)),
        ],
        const SizedBox(height: 12),
        DateSelector(label: 'Date of purchase', value: _date, firstYear: 2000, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 12),
        TextField(controller: _biller, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name of biller')),
        const SizedBox(height: 12),
        TextField(controller: _description, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'What was bought', hintText: 'Urea 2 bags, pesticide')),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount (before discount, optional)', prefixText: '₹ '),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _final,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Final price (to be paid)', prefixText: '₹ '),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: const Text('Save bill')),
        const SizedBox(height: 6),
        Text('Interest is counted from the day of purchase.', textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12)),
      ],
    );
  }
}

class _PaymentForm extends StatefulWidget {
  const _PaymentForm();

  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  DateTime _date = dateOnly(DateTime.now());
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
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter the amount paid.');
      return;
    }
    Navigator.of(context).pop(CreditPayment(id: _id(), date: _date, cents: (amount * 100).round(), note: _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DateSelector(label: 'Date paid', value: _date, firstYear: 2000, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount paid', prefixText: '₹ '),
        ),
        const SizedBox(height: 12),
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'How (cash, UPI, cheque)')),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: const Text('Record payment')),
      ],
    );
  }
}
