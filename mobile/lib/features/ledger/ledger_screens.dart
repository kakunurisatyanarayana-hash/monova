import 'package:monova_app/core/input_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/bill_scanner.dart';
import '../../core/contacts_picker.dart';
import '../tools/contact_picker_sheet.dart';
import '../../core/credit_ledger.dart';
import '../../core/format.dart';
import '../../core/rate_input.dart';
import '../../core/rate_units.dart';
import '../../core/share_text.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../shared/date_inputs.dart';

String _id() => DateTime.now().microsecondsSinceEpoch.toString();

String _dateText(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

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
    final account = await FormSheet.show<CreditAccount>(
      context,
      title: 'Add customer or supplier',
      child: const _AccountForm(),
    );
    if (account == null) return;
    final updated = [..._accounts, account];
    setState(() => _accounts = updated);
    await CreditLedgerStore.save(updated);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final today = dateOnly(DateTime.now());
    final shown = _accounts
        .where(
          (a) => a.name.toLowerCase().contains(_query.trim().toLowerCase()),
        )
        .toList();
    final totalOutstanding = _accounts.fold<int>(
      0,
      (sum, a) => sum + computeStatement(a, today).totalCents,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _loaded ? _newCustomer : null,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Add person'),
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
                  gradient: c.hero,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total on all accounts today',
                        style: TextStyle(
                          color: c.onAccent.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        money(totalOutstanding / 100),
                        style: TextStyle(
                          color: c.onAccent,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_accounts.length} ${_accounts.length == 1 ? 'person' : 'people'}, including interest up to today',
                        style: TextStyle(
                          color: c.onAccent.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_accounts.length > 3)
                  TextField(
                    textInputAction: TextInputAction.next,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search people',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                const SizedBox(height: 12),
                if (_accounts.isEmpty)
                  EmptyState(
                    icon: Icons.menu_book_rounded,
                    title: 'No people yet',
                    message: 'Add a customer you sell to on credit, or a supplier you buy from on credit. Then record each bill and each payment. Interest is worked out for every day.',
                    actionLabel: 'Add the first person',
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
  const _CustomerTile({
    required this.account,
    required this.today,
    required this.onTap,
  });

  final CreditAccount account;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final s = computeStatement(account, today);
    final total = accountTotalCents(account, today);
    return MonovaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: c.aurora,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                account.name.isEmpty ? '?' : account.name[0].toUpperCase(),
                style: TextStyle(
                  color: c.onAccent,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${account.iOwe ? 'Supplier' : 'Customer'} · ${account.annualRatePercent}% a year simple · interest ${money(s.interestCents / 100)}',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(total / 100),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: total > 0 ? c.expense : c.income,
                ),
              ),
              Text(
                total > 0
                    ? (account.iOwe ? 'to pay' : 'to receive')
                    : (total < 0
                          ? (account.iOwe ? 'extra paid' : 'advance')
                          : 'settled'),
                style: TextStyle(color: c.muted, fontSize: 11),
              ),
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

  /// Fills the name and phone from one of the phone's contacts.
  Future<void> _pickContact() async {
    final messenger = ScaffoldMessenger.of(context);
    final List<PickedContact> contacts;
    try {
      contacts = await loadContacts();
    } on ContactsException catch (e) {
      await showContactsProblem(context, e.message);
      return;
    } catch (e) {
      await showContactsProblem(context, 'Contacts could not be opened. $e');
      return;
    }
    if (!mounted) return;
    final picked = await FormSheet.show<List<PickedContact>>(
      context,
      title: 'Pick a person',
      child: ContactPickerSheet(contacts: contacts, singleSelect: true),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      _name.text = picked.first.name;
      _phone.text = picked.first.phone;
    });
  }

  late final _rate = TextEditingController(
    text: plainRate(widget.initial?.annualRatePercent ?? 24),
  );
  RateUnit _unit = RateUnit.percentYear;

  /// The rate as a yearly percentage, whatever unit the person chose.
  double? get _annualRate {
    final typed = double.tryParse(_rate.text.trim());
    return typed == null ? null : toAnnualPercent(typed, _unit);
  }

  String _rateHelp() {
    final r = _annualRate;
    if (r == null)
      return 'Charged every day on the amount owed, divided by 365.';
    return 'Per day: ${(r / 365).toStringAsFixed(4)}% of the amount owed.';
  }

  late String _method =
      widget.initial?.interestMethod ?? CreditAccount.perBillInterest;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _save() {
    final rate = _annualRate;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter the name.');
      return;
    }
    if (rate == null || rate < 0 || rate > 120) {
      setState(() => _error = 'Enter the yearly interest rate, from 0 to 120.');
      return;
    }
    final initial = widget.initial;
    Navigator.of(context).pop(
      initial == null
          ? CreditAccount(
              id: _id(),
              name: _name.text.trim(),
              phone: _phone.text.trim(),
              annualRatePercent: rate,
              compound: false,
              interestMethod: _method,
              bills: const [],
              payments: const [],
            )
          : initial.copyWith(
              name: _name.text.trim(),
              phone: _phone.text.trim(),
              annualRatePercent: rate,
              compound: false,
              interestMethod: _method,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _pickContact,
          icon: const Icon(Icons.contacts_rounded, size: 18),
          label: const Text('Pick from contacts'),
        ),

        const SizedBox(height: 12),
        TextField(
          textInputAction: TextInputAction.next,
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const SizedBox(height: 12),

        TextField(
          textInputAction: TextInputAction.next,
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: phoneFormatters,
          decoration: const InputDecoration(labelText: 'Phone (optional)'),
        ),
        const SizedBox(height: 12),
        RateInput(
          controller: _rate,
          unit: _unit,
          onUnitChanged: (u) => setState(() => _unit = u),
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 6),
        Text(_rateHelp(), style: TextStyle(color: c.muted, fontSize: 12)),
        const SizedBox(height: 8),
        const SizedBox(height: 4),
        Text(
          'How interest is worked out',
          style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Each bill by days'),
              selected: _method == CreditAccount.perBillInterest,
              onSelected: (_) =>
                  setState(() => _method = CreditAccount.perBillInterest),
            ),
            ChoiceChip(
              label: const Text('On the whole bill'),
              selected: _method == CreditAccount.wholeBillInterest,
              onSelected: (_) =>
                  setState(() => _method = CreditAccount.wholeBillInterest),
            ),
            ChoiceChip(
              label: const Text('At each bill date'),
              selected: _method == CreditAccount.atBillDatesInterest,
              onSelected: (_) =>
                  setState(() => _method = CreditAccount.atBillDatesInterest),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _method == CreditAccount.wholeBillInterest
              ? 'Interest is worked out once on the full bill, from the bill date to the settlement date. Payments reduce what is owed.'
              : _method == CreditAccount.atBillDatesInterest
              ? 'Interest runs from one bill date to the next. At each new bill, it is added to the balance, so the next period earns interest on it too. The final settlement adds interest to the settlement date.'
              : 'Each bill earns simple interest every day on what is still owed, from its own date. Give 0% for no interest.',
          style: TextStyle(color: c.muted, fontSize: 12),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _save,
          child: Text(widget.initial == null ? 'Save person' : 'Save changes'),
        ),
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
    await CreditLedgerStore.save([
      for (final a in all) a.id == updated.id ? updated : a,
    ]);
  }

  Future<void> _addBill() async {
    final account = _account;
    if (account == null) return;
    final bill = await FormSheet.show<CreditBill>(
      context,
      title: account.iOwe
          ? 'Bill received from supplier'
          : 'Bill given to customer',
      child: _BillForm(defaultBiller: account.name),
    );
    if (bill == null) return;
    await _save(account.copyWith(bills: [...account.bills, bill]));
  }

  Future<void> _addPayment() async {
    final account = _account;
    if (account == null) return;
    final payment = await FormSheet.show<CreditPayment>(
      context,
      title: account.iOwe
          ? 'Money paid to supplier'
          : 'Money received from customer',
      child: _PaymentForm(bills: account.bills),
    );
    if (payment == null) return;
    await _save(account.copyWith(payments: [...account.payments, payment]));
  }

  Future<void> _editTerms() async {
    final account = _account;
    if (account == null) return;
    final updated = await FormSheet.show<CreditAccount>(
      context,
      title: 'Edit person',
      child: _AccountForm(initial: account),
    );
    if (updated != null) await _save(updated);
  }

  Future<void> _deleteCustomer() async {
    final account = _account;
    if (account == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this customer?'),
        content: Text(
          '"${account.name}" with all bills and payments will be removed from this device.',
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
        title: Text(account?.name ?? 'Person'),
        actions: [
          if (account != null) ...[
            IconButton(
              tooltip: 'Share statement',
              icon: const Icon(Icons.share_rounded),
              onPressed: () => _shareStatement(account),
            ),
            IconButton(
              tooltip: 'Edit interest and details',
              icon: const Icon(Icons.tune_rounded),
              onPressed: _editTerms,
            ),
            IconButton(
              tooltip: 'Delete person',
              icon: Icon(Icons.delete_outline_rounded, color: c.expense),
              onPressed: _deleteCustomer,
            ),
          ],
        ],
      ),
      floatingActionButton: account == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'payment',
                  onPressed: _addPayment,
                  icon: const Icon(Icons.payments_rounded),
                  label: Text(account.iOwe ? 'Money paid' : 'Money received'),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'bill',
                  onPressed: _addBill,
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: Text(account.iOwe ? 'Bill received' : 'Bill given'),
                ),
              ],
            ),
      body: !_loaded
          ? const LoadingBox()
          : account == null
          ? const EmptyState(
              icon: Icons.menu_book_rounded,
              title: 'Person not found',
              message: 'It may have been deleted.',
            )
          : _body(context, account),
    );
  }

  Widget _body(BuildContext context, CreditAccount account) {
    final c = context.monova;
    final s = computeStatement(account, _asOf);
    final months = s.interestByMonth.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final method = account.interestMethod;
    final whole = method == CreditAccount.wholeBillInterest;
    final atDates = method == CreditAccount.atBillDatesInterest;
    final wb = whole
        ? wholeBillBreakdowns(account, _asOf)
        : const <BillBreakdown>[];
    final steps = atDates
        ? billDateSettlement(account, _asOf)
        : const <SettlementStep>[];
    final billsUpTo = account.bills.where(
      (b) => !dateOnly(b.date).isAfter(dateOnly(_asOf)),
    );
    final paymentsUpTo = account.payments.where(
      (p) => !dateOnly(p.date).isAfter(dateOnly(_asOf)),
    );
    final totalNow = whole
        ? wb.fold<int>(0, (x, b) => x + b.openCents)
        : atDates
        ? (steps.isEmpty ? 0 : steps.last.balanceCents)
        : s.totalCents;
    final billsNow = whole
        ? wb.fold<int>(0, (x, b) => x + b.bill.finalCents)
        : atDates
        ? billsUpTo.fold<int>(0, (x, b) => x + b.finalCents)
        : s.principalCents;
    final interestNow = whole
        ? wb.fold<int>(0, (x, b) => x + b.interestCents)
        : atDates
        ? steps
              .where((st) => st.interestCents > 0)
              .fold<int>(0, (x, st) => x + st.interestCents)
        : s.interestCents;
    final paidNow = whole
        ? wb.fold<int>(0, (x, b) => x + b.paidCents)
        : atDates
        ? paymentsUpTo.fold<int>(0, (x, p) => x + p.cents)
        : s.totalPaidCents;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        MonovaCard(
          gradient: c.hero,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Final amount on ${_dateText(_asOf)}',
                      style: TextStyle(
                        color: c.onAccent.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickAsOf,
                    icon: Icon(
                      Icons.event_rounded,
                      color: c.onAccent,
                      size: 18,
                    ),
                    label: Text(
                      'Change date',
                      style: TextStyle(color: c.onAccent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      money(totalNow / 100),
                      style: TextStyle(
                        color: c.onAccent,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy final amount',
                    icon: Icon(Icons.copy_rounded, color: c.onAccent),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(
                          text:
                              '${account.name}: ${money(totalNow / 100)} on ${_dateText(_asOf)}',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Final amount copied')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _sum('Bills', money(billsNow / 100), c),
              _sum(
                whole
                    ? 'Interest on whole bills (${account.annualRatePercent}% a year)'
                    : 'Interest so far (${account.annualRatePercent}% a year)',
                money(interestNow / 100),
                c,
              ),
              _sum('Paid so far', money(paidNow / 100), c),
              _sum('How interest is worked out', switch (account.interestMethod) { CreditAccount.wholeBillInterest => 'On the whole bill', CreditAccount.atBillDatesInterest => 'At each bill date', _ => 'Each bill by days' }, c),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MonovaCard(
          padding: const EdgeInsets.all(14),
          child: Text(
            account.compound
                ? 'Interest is simple: worked out every day on what is still open, from the date of each bill.'
                : 'Payments clear the interest first, then the oldest open bill.',
            style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
          ),
        ),
        const SizedBox(height: 16),
        if (atDates && steps.isNotEmpty) ...[
          Text(
            'Settlement steps',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final st in steps) ...[
            MonovaCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${dayLabel(st.date)} · ${st.label}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          st.amountCents != 0
                              ? 'Amount ${money(st.amountCents.abs() / 100)}'
                              : 'Interest added ${money(st.interestCents / 100)}',
                          style: TextStyle(color: c.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Balance ${money(st.balanceCents / 100)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
        ],
        if (account.bills.isNotEmpty && !atDates) ...[
          Text('Each bill', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final b in (whole ? wb : billBreakdowns(account, _asOf, s))) ...[
            MonovaCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${dayLabel(b.bill.date)} · ${b.bill.billerName.isEmpty ? b.bill.description : b.bill.billerName}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        b.closedOn == null
                            ? 'Open'
                            : 'Cleared ${dayLabel(b.closedOn!)}',
                        style: TextStyle(
                          color: b.closedOn == null ? c.warning : c.income,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bill ${money(b.bill.finalCents / 100)} · paid ${money(b.paidCents / 100)} · still open ${money(b.openCents / 100)}',
                    style: TextStyle(color: c.muted, fontSize: 12),
                  ),
                  Text(
                    '${b.daysOpen} days · interest so far ${money(b.interestCents / 100)} at ${account.annualRatePercent}% a year',
                    style: TextStyle(color: c.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
        ],
        if (!whole && !atDates) ...[
          Text('Day by day', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (s.days.where((d) => !d.date.isAfter(_asOf)).isEmpty)
            Text(
              'No bills or payments yet. Tap the button below to start.',
              style: TextStyle(color: c.muted),
            )
          else
            for (final day in s.days.where((d) => !d.date.isAfter(_asOf))) ...[
              _dayCard(account, day, c),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 8),
          Text(
            'Tap a bill or payment to read or edit its notes.',
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Text(
            'Interest by month',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (months.isEmpty)
            Text(
              'Interest starts the day after the first bill.',
              style: TextStyle(color: c.muted),
            )
          else
            MonovaCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final m in months)
                    ListTile(
                      dense: true,
                      title: Text(_monthLabel(m.key)),
                      trailing: Text(
                        money(m.value / 100),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _shareStatement(CreditAccount account) async {
    final s = computeStatement(account, _asOf);
    final b = StringBuffer()
      ..writeln('Statement: ${account.name}')
      ..writeln('As of ${_dateText(s.asOf)}')
      ..writeln(
        'Final amount: ${money(accountTotalCents(account, _asOf) / 100)} (bills ${money(s.principalCents / 100)} + interest ${money(s.interestCents / 100)})',
      )
      ..writeln();
    for (final d in s.days.where((d) => !d.date.isAfter(s.asOf))) {
      b.write('${_dateText(d.date)}: owed ${money(d.balanceCents / 100)}');
      if (d.billedCents > 0) b.write(', bills +${money(d.billedCents / 100)}');
      if (d.paidCents > 0) b.write(', paid -${money(d.paidCents / 100)}');
      if (d.interestCents > 0)
        b.write(', interest +${money(d.interestCents / 100)}');
      b.writeln();
    }
    await shareText(b.toString(), subject: 'Statement: ${account.name}');
  }

  Widget _dayCard(CreditAccount account, DayRow day, MonovaColors c) {
    return MonovaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _dateText(day.date),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                'Balance ${money(day.balanceCents / 100)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          for (final b in day.bills)
            _entryRow(
              title: b.billerName.isEmpty
                  ? (b.description.isEmpty ? 'Bill' : b.description)
                  : '${b.billerName}${b.description.isEmpty ? '' : ' - ${b.description}'}',
              notes: b.notes,
              amount: '+ ${money(b.finalCents / 100)}',
              color: c.expense,
              onTap: () => _editBill(account, b),
              c: c,
            ),
          for (final p in day.payments)
            _entryRow(
              title: p.note.isEmpty ? 'Payment' : 'Payment: ${p.note}',
              notes: p.note.isEmpty ? '' : '',
              amount: '- ${money(p.cents / 100)}',
              color: c.income,
              onTap: () => _editPayment(account, p),
              c: c,
            ),
          if (day.interestCents > 0)
            _entryRow(
              title: 'Interest since the previous entry',
              notes: '${account.annualRatePercent}% a year, worked out per day',
              amount: '+ ${money(day.interestCents / 100)}',
              color: c.warning,
              onTap: null,
              c: c,
            ),
        ],
      ),
    );
  }

  Widget _entryRow({
    required String title,
    required String notes,
    required String amount,
    required Color color,
    required VoidCallback? onTap,
    required MonovaColors c,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      notes,
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              amount,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: c.muted, size: 18),
          ],
        ),
      ),
    );
  }

  /// Opens a bill or payment so its notes can be read, changed, or the entry deleted.
  Future<void> _editNotes(
    CreditAccount account, {
    CreditBill? bill,
    CreditPayment? payment,
  }) async {
    final initial = bill?.notes ?? payment?.note ?? '';
    final result = await FormSheet.show<({String notes, bool delete})>(
      context,
      title: bill != null ? 'Bill notes' : 'Payment note',
      child: _NotesForm(initial: initial, isBill: bill != null),
    );
    if (result == null) return;
    if (result.delete) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete this entry?'),
          content: const Text(
            'It will be removed from the statement and from the interest calculation.',
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
      if (bill != null) {
        await _save(
          account.copyWith(
            bills: account.bills.where((b) => b.id != bill.id).toList(),
          ),
        );
      } else if (payment != null) {
        await _save(
          account.copyWith(
            payments: account.payments
                .where((p) => p.id != payment.id)
                .toList(),
          ),
        );
      }
      return;
    }
    if (bill != null) {
      await _save(
        account.copyWith(
          bills: [
            for (final b in account.bills)
              b.id == bill.id ? b.copyWith(notes: result.notes) : b,
          ],
        ),
      );
    } else if (payment != null) {
      await _save(
        account.copyWith(
          payments: [
            for (final p in account.payments)
              p.id == payment.id ? p.copyWith(note: result.notes) : p,
          ],
        ),
      );
    }
  }

  Future<bool> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text(
          'It will be removed from the statement and from the interest calculation.',
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
    return ok == true;
  }

  /// Edit a bill's date, biller, description, amount and notes, or delete it.
  Future<void> _editBill(CreditAccount account, CreditBill bill) async {
    final r = await FormSheet.show<Object>(
      context,
      title: 'Edit bill',
      child: _BillEditForm(bill: bill),
    );
    if (r == null) return;
    if (r == _deleteSignal) {
      if (!await _confirmDelete()) return;
      await _save(
        account.copyWith(
          bills: account.bills.where((b) => b.id != bill.id).toList(),
        ),
      );
      return;
    }
    if (r is CreditBill) {
      await _save(
        account.copyWith(
          bills: [for (final b in account.bills) b.id == bill.id ? r : b],
        ),
      );
    }
  }

  /// Edit a payment's date, amount, note and the bill it is against, or delete it.
  Future<void> _editPayment(
    CreditAccount account,
    CreditPayment payment,
  ) async {
    final r = await FormSheet.show<Object>(
      context,
      title: 'Edit payment',
      child: _PaymentEditForm(payment: payment, bills: account.bills),
    );
    if (r == null) return;
    if (r == _deleteSignal) {
      if (!await _confirmDelete()) return;
      await _save(
        account.copyWith(
          payments: account.payments.where((p) => p.id != payment.id).toList(),
        ),
      );
      return;
    }
    if (r is CreditPayment) {
      await _save(
        account.copyWith(
          payments: [
            for (final p in account.payments) p.id == payment.id ? r : p,
          ],
        ),
      );
    }
  }

  static const _deleteSignal = 'delete-entry';

  Widget _sum(String label, String value, MonovaColors c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: c.onAccent.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w700),
        ),
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
  final _notes = TextEditingController();
  String? _error;
  String? _scanNote;

  @override
  void dispose() {
    _biller.dispose();
    _description.dispose();
    _amount.dispose();
    _final.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Reads a bill photo and fills in what it can find. Each value is shown in its box, so the user checks it before saving.
  Future<void> _scan() async {
    String note;
    try {
      final parsed = await scanBillPhoto(camera: false);
      setState(() {
        if (parsed.date != null) _date = dateOnly(parsed.date!);
        if (parsed.billerName != null && parsed.billerName!.isNotEmpty)
          _biller.text = parsed.billerName!;
        if (parsed.itemsText.isNotEmpty && _description.text.trim().isEmpty)
          _description.text = parsed.itemsText;
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
      setState(
        () => _error = 'Enter the final price to be paid for this bill.',
      );
      return;
    }
    if (gross != null && gross < finalAmount) {
      setState(
        () => _error =
            'The final price cannot be more than the amount before discount.',
      );
      return;
    }
    if (_description.text.trim().isEmpty) {
      setState(
        () => _error =
            'Say what was bought, for example "Urea 2 bags" or "Pesticide".',
      );
      return;
    }
    final finalCents = (finalAmount * 100).round();
    Navigator.of(context).pop(
      CreditBill(
        id: _id(),
        date: _date,
        billerName: _biller.text.trim(),
        description: _description.text.trim(),
        amountCents: gross == null ? finalCents : (gross * 100).round(),
        finalCents: finalCents,
        notes: _notes.text.trim(),
      ),
    );
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
          Text(
            _scanNote!,
            style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
          ),
        ],
        const SizedBox(height: 12),
        DateSelector(
          label: 'Date of purchase',
          value: _date,
          firstYear: 2000,
          onChanged: (d) => setState(() => _date = d),
        ),
        const SizedBox(height: 12),
        TextField(
          textInputAction: TextInputAction.next,
          controller: _biller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Customer or supplier name',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          textInputAction: TextInputAction.next,
          controller: _description,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'What was bought',
            hintText: 'Urea 2 bags, pesticide',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            hintText: 'Paid half in cash, balance after harvest',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          textInputAction: TextInputAction.next,
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: amountFormatters,
          decoration: const InputDecoration(
            labelText: 'Amount (before discount, optional)',
            prefixText: '₹ ',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          textInputAction: TextInputAction.next,
          controller: _final,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: amountFormatters,
          decoration: const InputDecoration(
            labelText: 'Final price (to be paid)',
            prefixText: '₹ ',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: const Text('Save bill')),
        const SizedBox(height: 6),
        Text(
          'Interest is counted from the day of purchase.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _PaymentForm extends StatefulWidget {
  const _PaymentForm({this.bills = const []});

  /// The bills this payment can be made against. Empty means no choice is offered.
  final List<CreditBill> bills;

  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  DateTime _date = dateOnly(DateTime.now());
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _billId = '';
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
    Navigator.of(context).pop(
      CreditPayment(
        id: _id(),
        date: _date,
        cents: (amount * 100).round(),
        note: _note.text.trim(),
        billId: _billId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.bills.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            initialValue: _billId,
            decoration: const InputDecoration(
              labelText: 'Pay against which bill?',
            ),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Oldest open bill (default)'),
              ),
              for (final b in widget.bills)
                DropdownMenuItem(
                  value: b.id,
                  child: Text(
                    '${dayLabel(b.date)} · ${b.billerName.isEmpty ? b.description : b.billerName} · ${money(b.finalCents / 100)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _billId = v ?? ''),
          ),
          const SizedBox(height: 12),
        ],
        DateSelector(
          label: 'Date paid',
          value: _date,
          firstYear: 2000,
          onChanged: (d) => setState(() => _date = d),
        ),
        const SizedBox(height: 12),
        TextField(
          textInputAction: TextInputAction.next,
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: amountFormatters,
          decoration: const InputDecoration(
            labelText: 'Amount paid',
            prefixText: '₹ ',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          textInputAction: TextInputAction.next,
          controller: _note,
          decoration: const InputDecoration(
            labelText: 'How (cash, UPI, cheque)',
          ),
        ),
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

/// Notes for a bill or payment: read, change, or delete.
class _NotesForm extends StatefulWidget {
  const _NotesForm({required this.initial, required this.isBill});

  final String initial;
  final bool isBill;

  @override
  State<_NotesForm> createState() => _NotesFormState();
}

class _NotesFormState extends State<_NotesForm> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: widget.isBill
                ? 'Notes for this bill'
                : 'Note for this payment',
            alignLabelWithHint: true,
            hintText: 'Anything to remember about it',
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () =>
              Navigator.of(context)
                  .pop((notes: _controller.text.trim(), delete: false)),
          child: const Text('Save notes'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop((notes: '', delete: true)),
          icon: Icon(Icons.delete_outline_rounded, color: c.expense),
          label: Text('Delete this entry', style: TextStyle(color: c.expense)),
        ),
      ],
    );
  }
}

class _BillEditForm extends StatefulWidget {
  const _BillEditForm({required this.bill});

  final CreditBill bill;

  @override
  State<_BillEditForm> createState() => _BillEditFormState();
}

class _BillEditFormState extends State<_BillEditForm> {
  late DateTime _date = dateOnly(widget.bill.date);
  late final _biller = TextEditingController(text: widget.bill.billerName);
  late final _description = TextEditingController(
    text: widget.bill.description,
  );
  late final _amount = TextEditingController(
    text: (widget.bill.finalCents / 100).toStringAsFixed(2),
  );
  late final _notes = TextEditingController(text: widget.bill.notes);
  String? _error;

  @override
  void dispose() {
    _biller.dispose();
    _description.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final amount = parseAmount(_amount.text);
    if (amount == null) {
      setState(
        () => _error = 'Enter the final amount, for example 1500 or 999.50.',
      );
      return;
    }
    final cents = (amount * 100).round();
    Navigator.pop(
      context,
      CreditBill(
        id: widget.bill.id,
        date: _date,
        billerName: _biller.text.trim(),
        description: _description.text.trim(),
        amountCents: cents,
        finalCents: cents,
        notes: _notes.text.trim(),
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
          DateSelector(
            label: 'Bill date',
            value: _date,
            onChanged: (d) => setState(() => _date = d),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _biller,
            decoration: const InputDecoration(
              labelText: 'Name of customer or supplier',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'What was bought'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Final amount (₹)'),
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
          FilledButton(onPressed: _save, child: const Text('Save changes')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: c.expense),
            onPressed: () =>
                Navigator.pop(context, _LedgerAccountScreenStateDelete.signal),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete this bill'),
          ),
        ],
      ),
    );
  }
}

class _PaymentEditForm extends StatefulWidget {
  const _PaymentEditForm({required this.payment, required this.bills});

  final CreditPayment payment;
  final List<CreditBill> bills;

  @override
  State<_PaymentEditForm> createState() => _PaymentEditFormState();
}

class _PaymentEditFormState extends State<_PaymentEditForm> {
  late DateTime _date = dateOnly(widget.payment.date);
  late String _billId = widget.payment.billId;
  late final _amount = TextEditingController(
    text: (widget.payment.cents / 100).toStringAsFixed(2),
  );
  late final _note = TextEditingController(text: widget.payment.note);
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
      setState(() => _error = 'Enter the amount paid.');
      return;
    }
    Navigator.pop(
      context,
      CreditPayment(
        id: widget.payment.id,
        date: _date,
        cents: (amount * 100).round(),
        note: _note.text.trim(),
        billId: _billId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final billIds = {for (final b in widget.bills) b.id};
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.bills.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: billIds.contains(_billId) ? _billId : '',
              decoration: const InputDecoration(
                labelText: 'Pay against which bill?',
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Oldest open bill (default)'),
                ),
                for (final b in widget.bills)
                  DropdownMenuItem(
                    value: b.id,
                    child: Text(
                      '${dayLabel(b.date)} · ${b.billerName.isEmpty ? b.description : b.billerName} · ${money(b.finalCents / 100)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _billId = v ?? ''),
            ),
            const SizedBox(height: 12),
          ],
          DateSelector(
            label: 'Date paid',
            value: _date,
            onChanged: (d) => setState(() => _date = d),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount paid (₹)'),
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
          FilledButton(onPressed: _save, child: const Text('Save changes')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: c.expense),
            onPressed: () =>
                Navigator.pop(context, _LedgerAccountScreenStateDelete.signal),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete this payment'),
          ),
        ],
      ),
    );
  }
}

/// The value a form returns to ask for deletion.
class _LedgerAccountScreenStateDelete {
  static const signal = 'delete-entry';
}
