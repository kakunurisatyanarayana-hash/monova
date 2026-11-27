import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/loans.dart';
import '../../core/rate_input.dart';
import '../../core/rate_units.dart';
import '../../core/reminders.dart' show addMonths;
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../shared/date_inputs.dart';

int _cents(String text) {
  final v = double.tryParse(text.replaceAll(',', '').trim());
  if (v == null || v < 0) return 0;
  return (v * 100).round();
}

String _id() => DateTime.now().microsecondsSinceEpoch.toString();

/// Loans you are repaying and money you borrowed, with repayments tracked on this phone.
class LoanTrackerScreen extends StatefulWidget {
  const LoanTrackerScreen({super.key});

  @override
  State<LoanTrackerScreen> createState() => _LoanTrackerScreenState();
}

class _LoanTrackerScreenState extends State<LoanTrackerScreen> {
  List<Loan> _loans = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loans = await LoanStore.load();
    if (mounted) setState(() {
      _loans = loans;
      _loaded = true;
    });
  }

  Future<void> _add() async {
    final loan = await FormSheet.show<Loan>(context, title: 'Add a loan or borrowing', child: const _LoanForm());
    if (loan == null) return;
    final next = [..._loans, loan];
    setState(() => _loans = next);
    await LoanStore.save(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final today = DateTime.now();
    final open = [for (final l in _loans) if (!l.finished) l];
    final done = [for (final l in _loans) if (l.finished) l];
    final owed = open.fold<int>(0, (s, l) => s + l.outstandingCents());
    final overdue = open.fold<int>(0, (s, l) => s + l.overdueInstallments(today));
    final monthly = open.fold<int>(0, (s, l) => s + l.emiCents);
    return Scaffold(
      appBar: AppBar(title: const Text('Loans and borrowing')),
      floatingActionButton: _loaded
          ? FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add_rounded), label: const Text('Add loan'))
          : null,
      body: !_loaded
          ? const LoadingBox()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                MonovaCard(
                  gradient: c.hero,
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(child: _Figure(label: 'Still to repay', value: money(owed / 100), onHero: true)),
                      Expanded(child: _Figure(label: 'Each month', value: money(monthly / 100), onHero: true)),
                      Expanded(child: _Figure(label: 'Overdue', value: '$overdue', onHero: true)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_loans.isEmpty)
                  EmptyState(
                    icon: Icons.account_balance_outlined,
                    title: 'No loans yet',
                    message: 'Add a bank loan to follow its instalments, or money you borrowed from someone to track what you have repaid.',
                    actionLabel: 'Add the first loan',
                    onAction: _add,
                  ),
                if (open.isNotEmpty) ...[
                  const SectionTitle('Open'),
                  const SizedBox(height: 8),
                  for (final l in open) _LoanCard(loan: l, today: today, onTap: () => _openDetail(l)),
                ],
                if (done.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const SectionTitle('Finished'),
                  const SizedBox(height: 8),
                  for (final l in done) _LoanCard(loan: l, today: today, onTap: () => _openDetail(l)),
                ],
              ],
            ),
    );
  }

  Future<void> _openDetail(Loan l) async {
    await context.push('/loans/${l.id}');
    await _load();
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.onHero = false});

  final String label;
  final String value;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final fg = onHero ? c.onAccent : c.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: onHero ? c.onAccent.withValues(alpha: 0.9) : c.muted, fontSize: 11)),
      ],
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan, required this.today, required this.onTap});

  final Loan loan;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final overdueCount = loan.overdueInstallments(today);
    final next = loan.nextDueDate();
    final status = loan.finished
        ? 'Fully repaid'
        : overdueCount > 0
            ? '$overdueCount instalment${overdueCount == 1 ? '' : 's'} overdue'
            : next != null
                ? 'Next instalment ${dayLabel(next)}'
                : 'Repay in any amount';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MonovaCard(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(loan.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: c.accentStart.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
                  child: Text(loan.isEmi ? 'Loan' : 'Borrowed', style: TextStyle(color: c.accentStart, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${money(loan.outstandingCents() / 100)} left of ${money(loan.principalCents / 100)}',
              style: TextStyle(color: c.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ProgressBar(value: loan.progress, color: loan.finished ? c.income : c.accentStart),
            const SizedBox(height: 6),
            Text(status, style: TextStyle(color: overdueCount > 0 ? c.expense : c.muted, fontSize: 12, fontWeight: overdueCount > 0 ? FontWeight.w700 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

/// One loan: the summary, its instalment schedule (for loans), the repayments, and record, edit and delete.
class LoanDetailScreen extends StatefulWidget {
  const LoanDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  Loan? _loan;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await LoanStore.load();
    final matches = all.where((l) => l.id == widget.id).toList();
    if (mounted) setState(() {
      _loan = matches.isEmpty ? null : matches.first;
      _loaded = true;
    });
  }

  Future<void> _save(Loan updated) async {
    setState(() => _loan = updated);
    final all = await LoanStore.load();
    await LoanStore.save([for (final l in all) l.id == updated.id ? updated : l]);
  }

  Future<void> _recordPayment() async {
    final loan = _loan;
    if (loan == null) return;
    final p = await FormSheet.show<LoanPayment>(
      context,
      title: loan.isEmi ? 'Record an instalment' : 'Record a repayment',
      child: _PaymentForm(defaultCents: loan.isEmi ? loan.emiCents : 0),
    );
    if (p == null) return;
    await _save(loan.withPayment(p));
  }

  Future<void> _edit() async {
    final loan = _loan;
    if (loan == null) return;
    final updated = await FormSheet.show<Loan>(context, title: 'Edit loan', child: _LoanForm(initial: loan));
    if (updated == null) return;
    await _save(updated);
  }

  Future<void> _deletePayment(LoanPayment p) async {
    final loan = _loan;
    if (loan == null) return;
    await _save(loan.withoutPayment(p.id));
  }

  Future<void> _delete() async {
    final loan = _loan;
    if (loan == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${loan.name}?'),
        content: const Text('The loan and its repayments will be removed. The money in and out already in Monova Finance is removed too.'),
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
    final all = await LoanStore.load();
    await LoanStore.save([for (final l in all) if (l.id != loan.id) l]);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final loan = _loan;
    if (!_loaded) return const Scaffold(body: LoadingBox());
    if (loan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loan')),
        body: const EmptyState(icon: Icons.error_outline_rounded, title: 'Loan not found', message: 'It may have been deleted.'),
      );
    }
    final today = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: Text(loan.name),
        actions: [
          IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: _edit),
          IconButton(tooltip: 'Delete', icon: Icon(Icons.delete_outline_rounded, color: c.expense), onPressed: _delete),
        ],
      ),
      floatingActionButton: loan.finished
          ? null
          : FloatingActionButton.extended(
              onPressed: _recordPayment,
              icon: const Icon(Icons.payments_rounded),
              label: Text(loan.isEmi ? 'Record instalment' : 'Record repayment'),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          MonovaCard(
            gradient: c.hero,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loan.isEmi ? 'Loan from ${loan.name}' : 'Borrowed from ${loan.name}', style: TextStyle(color: c.onAccent.withValues(alpha: 0.9), fontSize: 12)),
                const SizedBox(height: 10),
                Text(money(loan.outstandingCents() / 100), style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w800, fontSize: 28)),
                Text('still to repay', style: TextStyle(color: c.onAccent.withValues(alpha: 0.9), fontSize: 12)),
                const SizedBox(height: 14),
                ProgressBar(value: loan.progress, color: c.onAccent),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  children: [
                    _Figure(label: 'Borrowed', value: money(loan.principalCents / 100), onHero: true),
                    _Figure(label: 'Repaid so far', value: money(loan.paidCents / 100), onHero: true),
                    if (loan.isEmi) _Figure(label: 'Instalment', value: money(loan.emiCents / 100), onHero: true),
                    if (loan.isEmi) _Figure(label: 'Interest a year', value: '${loan.annualRatePercent.toStringAsFixed(2)}%', onHero: true),
                    if (loan.isEmi) _Figure(label: 'Months', value: '${loan.months}', onHero: true),
                  ],
                ),
              ],
            ),
          ),
          if (loan.overdueInstallments(today) > 0) ...[
            const SizedBox(height: 12),
            MonovaCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: c.expense),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${loan.overdueInstallments(today)} instalment(s) are overdue. Record them when you pay.', style: TextStyle(color: c.expense, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          ],
          if (loan.isEmi) ...[
            const SizedBox(height: 18),
            const SectionTitle('Instalments'),
            const SizedBox(height: 8),
            for (var k = 1; k <= loan.months; k++)
              _InstalmentRow(
                number: k,
                due: addMonths(loan.startDate, k),
                cents: loan.emiCents,
                paid: k <= loan.payments.length,
                overdue: k > loan.payments.length && !addMonths(loan.startDate, k).isAfter(DateTime(today.year, today.month, today.day)),
              ),
          ],
          const SizedBox(height: 18),
          const SectionTitle('Repayments'),
          const SizedBox(height: 8),
          if (loan.payments.isEmpty)
            MonovaCard(child: Text('Nothing repaid yet.', style: TextStyle(color: c.muted)))
          else
            for (final p in loan.payments.reversed) ...[
              MonovaCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(money(p.cents / 100), style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${dayLabel(p.date)}${p.note.isEmpty ? '' : ' · ${p.note}'}', style: TextStyle(color: c.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(tooltip: 'Delete repayment', icon: Icon(Icons.delete_outline_rounded, color: c.muted), onPressed: () => _deletePayment(p)),
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

class _InstalmentRow extends StatelessWidget {
  const _InstalmentRow({required this.number, required this.due, required this.cents, required this.paid, required this.overdue});

  final int number;
  final DateTime due;
  final int cents;
  final bool paid;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final color = paid ? c.income : (overdue ? c.expense : c.muted);
    final label = paid ? 'Paid' : (overdue ? 'Overdue' : 'Due');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 34, child: Text('$number', style: TextStyle(color: c.muted, fontSize: 12))),
          Expanded(child: Text(dayLabel(due), style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(money(cents / 100)),
          const SizedBox(width: 12),
          SizedBox(width: 70, child: Text(label, textAlign: TextAlign.right, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12))),
        ],
      ),
    );
  }
}

/// A loan or borrowing: loans take principal, rate and months; borrowed money takes only the amount.
class _LoanForm extends StatefulWidget {
  const _LoanForm({this.initial});

  final Loan? initial;

  @override
  State<_LoanForm> createState() => _LoanFormState();
}

class _LoanFormState extends State<_LoanForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _principal = TextEditingController(
    text: widget.initial == null ? '' : (widget.initial!.principalCents / 100).toStringAsFixed(0),
  );
  late final _rate = TextEditingController(text: widget.initial == null ? '' : '${widget.initial!.annualRatePercent}');
  RateUnit _unit = RateUnit.percentYear;
  late final _months = TextEditingController(text: widget.initial == null || widget.initial!.months == 0 ? '' : '${widget.initial!.months}');
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');
  late String _kind = widget.initial?.kind ?? 'emi';
  late DateTime _start = widget.initial?.startDate ?? DateTime.now();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _principal.dispose();
    _rate.dispose();
    _months.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final principal = _cents(_principal.text);
    final rate = toAnnualPercent(double.tryParse(_rate.text.trim()) ?? 0, _unit);
    final months = int.tryParse(_months.text.trim()) ?? 0;
    if (name.isEmpty) {
      setState(() => _error = _kind == 'emi' ? 'Name the lender, for example "HDFC Bank".' : 'Name who you borrowed from.');
      return;
    }
    if (principal <= 0) {
      setState(() => _error = 'Enter the amount.');
      return;
    }
    if (_kind == 'emi' && (months < 1 || months > 360)) {
      setState(() => _error = 'Enter the number of monthly instalments (1 to 360).');
      return;
    }
    if (_kind == 'emi' && (rate < 0 || rate > 60)) {
      setState(() => _error = 'Enter the yearly interest rate (0 to 60).');
      return;
    }
    final base = widget.initial;
    final loan = Loan(
      id: base?.id ?? _id(),
      name: name,
      kind: _kind,
      principalCents: principal,
      startDate: DateTime(_start.year, _start.month, _start.day),
      annualRatePercent: _kind == 'emi' ? rate : 0,
      months: _kind == 'emi' ? months : 0,
      payments: base?.payments ?? const [],
      notes: _notes.text.trim(),
    );
    Navigator.of(context).pop(loan);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final isEmi = _kind == 'emi';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'emi', label: Text('Loan (monthly)')),
            ButtonSegment(value: 'open', label: Text('Borrowed')),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() => _kind = s.first),
        ),
        const SizedBox(height: 6),
        Text(
          isEmi ? 'A bank or company loan repaid in equal monthly instalments.' : 'Money from a friend or family, repaid in any amounts you choose.',
          style: TextStyle(color: c.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextField(controller: _name, autofocus: widget.initial == null, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: isEmi ? 'Lender *' : 'Borrowed from *')),
        const SizedBox(height: 12),
        TextField(controller: _principal, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: isEmi ? 'Loan amount *' : 'Amount borrowed *', prefixText: '₹ ')),
        if (isEmi) ...[
          const SizedBox(height: 12),
          RateInput(
            controller: _rate,
            unit: _unit,
            onUnitChanged: (u) => setState(() => _unit = u),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(controller: _months, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly instalments *')),
        ],
        const SizedBox(height: 12),
        DateSelector(label: isEmi ? 'Loan started on' : 'Borrowed on', value: _start, firstYear: DateTime.now().year - 30, lastYear: DateTime.now().year + 1, onChanged: (d) => setState(() => _start = d)),
        const SizedBox(height: 12),
        TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Note (optional)')),
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

class _PaymentForm extends StatefulWidget {
  const _PaymentForm({required this.defaultCents});

  final int defaultCents;

  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  late final _amount = TextEditingController(
    text: widget.defaultCents > 0 ? (widget.defaultCents / 100).toStringAsFixed(2) : '',
  );
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final cents = _cents(_amount.text);
    if (cents <= 0) {
      setState(() => _error = 'Enter the amount paid.');
      return;
    }
    Navigator.of(context).pop(LoanPayment(id: _id(), date: DateTime(_date.year, _date.month, _date.day), cents: cents, note: _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _amount, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount paid', prefixText: '₹ ')),
        const SizedBox(height: 12),
        DateSelector(label: 'Paid on', value: _date, firstYear: DateTime.now().year - 30, lastYear: DateTime.now().year + 1, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 12),
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)')),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
