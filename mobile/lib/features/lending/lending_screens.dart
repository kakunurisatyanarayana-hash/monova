import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Money you owe (borrowings) and money owed to you (lendings), each with its outstanding balance and a repay or collect action.
class LendingScreen extends ConsumerStatefulWidget {
  const LendingScreen({super.key});

  @override
  ConsumerState<LendingScreen> createState() => _LendingScreenState();
}

class _LendingScreenState extends ConsumerState<LendingScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lending & borrowing'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'I owe'), Tab(text: 'Owed to me')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accentStart,
        foregroundColor: c.onAccent,
        onPressed: () => _tabs.index == 0
            ? FormSheet.show<void>(context, title: 'Record a borrowing', child: const _DebtForm())
            : FormSheet.show<void>(context, title: 'Record a lending', child: const _ReceivableForm()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Record'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_DebtList(), _ReceivableList()],
      ),
    );
  }
}

class _DebtList extends ConsumerWidget {
  const _DebtList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(debtsProvider);
    final c = context.monova;
    return debts.when(
      loading: () => const LoadingBox(),
      error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(debtsProvider)),
      data: (list) {
        final open = list.where((d) => !d.isClosed).toList();
        final total = open.fold<double>(0, (s, d) => s + d.totalOutstanding);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            MonovaCard(
              child: Row(
                children: [
                  Expanded(child: Text('Total I owe', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600))),
                  AmountText(money(total), tone: AmountTone.expense, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const EmptyState(icon: Icons.handshake_rounded, title: 'No borrowings', message: 'Record money you borrowed to track interest and repayments.'),
            for (final d in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MonovaCard(
                  onTap: d.isClosed ? null : () => FormSheet.show<void>(context, title: 'Repay ${d.counterparty}', child: _RepayForm(debt: d)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(d.counterparty, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                          Text(d.isClosed ? 'Settled' : 'Open', style: TextStyle(color: d.isClosed ? c.income : c.warning, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Borrowed ${money(d.principal)}${d.annualRate > 0 ? ' at ${d.annualRate.toStringAsFixed(1)}% a year' : ' interest-free'}',
                        style: TextStyle(color: c.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      AmountText('Outstanding ${money(d.totalOutstanding)}', tone: AmountTone.expense),
                      if (d.dueOn != null) ...[
                        const SizedBox(height: 4),
                        Text('Due ${dayLabel(d.dueOn!)}', style: TextStyle(color: c.muted, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ReceivableList extends ConsumerWidget {
  const _ReceivableList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(receivablesProvider);
    final c = context.monova;
    return items.when(
      loading: () => const LoadingBox(),
      error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(receivablesProvider)),
      data: (list) {
        final total = list.where((r) => !r.isClosed).fold<double>(0, (s, r) => s + r.remaining);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            MonovaCard(
              child: Row(
                children: [
                  Expanded(child: Text('Total owed to me', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600))),
                  AmountText(money(total), tone: AmountTone.income, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const EmptyState(icon: Icons.volunteer_activism_rounded, title: 'No lendings', message: 'Record money you lent to see what is still coming back.'),
            for (final r in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MonovaCard(
                  onTap: r.isClosed ? null : () => FormSheet.show<void>(context, title: 'Collect from ${r.counterparty}', child: _CollectForm(item: r)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(r.counterparty, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                          Text(r.isClosed ? 'Collected' : 'Receivable', style: TextStyle(color: r.isClosed ? c.income : c.muted, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Lent ${money(r.principal)} on ${dayLabel(r.lentOn)}', style: TextStyle(color: c.muted, fontSize: 12)),
                      const SizedBox(height: 10),
                      AmountText('Remaining ${money(r.remaining)}', tone: AmountTone.income),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AccountPicker extends ConsumerWidget {
  const _AccountPicker({required this.value, required this.onChanged, this.label = 'Account'});

  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    return accounts.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Could not load accounts'),
      data: (list) => DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [for (final a in list.where((a) => a.isActive)) DropdownMenuItem(value: a.id, child: Text('${a.name} · ${money(a.currentBalance)}'))],
        onChanged: onChanged,
        validator: (v) => v == null ? 'Choose an account' : null,
      ),
    );
  }
}

class _DebtForm extends ConsumerStatefulWidget {
  const _DebtForm();

  @override
  ConsumerState<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends ConsumerState<_DebtForm> {
  final _formKey = GlobalKey<FormState>();
  final _who = TextEditingController();
  final _amount = TextEditingController();
  final _rate = TextEditingController(text: '0');
  String? _accountId;
  DateTime _on = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_who, _amount, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await runAction(context, () async {
      await ref.read(repositoryProvider).addDebt(
            counterparty: _who.text.trim(),
            principal: parseAmount(_amount.text)!,
            annualRate: double.tryParse(_rate.text) ?? 0,
            borrowedOn: _on,
            accountId: _accountId!,
          );
      ref.invalidate(debtsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(dashboardProvider);
    }, success: 'Borrowing recorded');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(controller: _who, decoration: const InputDecoration(labelText: 'Borrowed from'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '), validator: validateAmount),
          const SizedBox(height: 12),
          TextFormField(controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Annual interest % (0 if none)')),
          const SizedBox(height: 12),
          _AccountPicker(value: _accountId, onChanged: (v) => setState(() => _accountId = v), label: 'Money arrived in'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(context: context, initialDate: _on, firstDate: DateTime(2000), lastDate: DateTime.now());
              if (picked != null) setState(() => _on = picked);
            },
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: Text('Borrowed on ${dayLabel(_on)}'),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      ),
    );
  }
}

class _RepayForm extends ConsumerStatefulWidget {
  const _RepayForm({required this.debt});

  final DebtItem debt;

  @override
  ConsumerState<_RepayForm> createState() => _RepayFormState();
}

class _RepayFormState extends ConsumerState<_RepayForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  String? _accountId;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _accountId == null) return;
    setState(() => _saving = true);
    final ok = await runAction(context, () async {
      await ref.read(repositoryProvider).repayDebt(widget.debt.id, amount: parseAmount(_amount.text)!, accountId: _accountId!);
      ref.invalidate(debtsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(dashboardProvider);
    }, success: 'Repayment recorded');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Outstanding ${money(widget.debt.totalOutstanding)}. Interest is settled first, then principal.', style: TextStyle(color: context.monova.muted)),
          const SizedBox(height: 16),
          _AccountPicker(value: _accountId, onChanged: (v) => setState(() => _accountId = v), label: 'Pay from'),
          const SizedBox(height: 12),
          TextFormField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Repayment', prefixText: '₹ '), validator: validateAmount),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Record repayment')),
        ],
      ),
    );
  }
}

class _ReceivableForm extends ConsumerStatefulWidget {
  const _ReceivableForm();

  @override
  ConsumerState<_ReceivableForm> createState() => _ReceivableFormState();
}

class _ReceivableFormState extends ConsumerState<_ReceivableForm> {
  final _formKey = GlobalKey<FormState>();
  final _who = TextEditingController();
  final _amount = TextEditingController();
  String? _accountId;
  DateTime _on = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _who.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await runAction(context, () async {
      await ref.read(repositoryProvider).addReceivable(
            counterparty: _who.text.trim(),
            principal: parseAmount(_amount.text)!,
            lentOn: _on,
            accountId: _accountId!,
          );
      ref.invalidate(receivablesProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(dashboardProvider);
    }, success: 'Lending recorded');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(controller: _who, decoration: const InputDecoration(labelText: 'Lent to'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '), validator: validateAmount),
          const SizedBox(height: 12),
          _AccountPicker(value: _accountId, onChanged: (v) => setState(() => _accountId = v), label: 'Money left from'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(context: context, initialDate: _on, firstDate: DateTime(2000), lastDate: DateTime.now());
              if (picked != null) setState(() => _on = picked);
            },
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: Text('Lent on ${dayLabel(_on)}'),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      ),
    );
  }
}

class _CollectForm extends ConsumerStatefulWidget {
  const _CollectForm({required this.item});

  final ReceivableItem item;

  @override
  ConsumerState<_CollectForm> createState() => _CollectFormState();
}

class _CollectFormState extends ConsumerState<_CollectForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  String? _accountId;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _accountId == null) return;
    setState(() => _saving = true);
    final ok = await runAction(context, () async {
      await ref.read(repositoryProvider).collect(widget.item.id, amount: parseAmount(_amount.text)!, accountId: _accountId!);
      ref.invalidate(receivablesProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(dashboardProvider);
    }, success: 'Collection recorded');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Still to collect ${money(widget.item.remaining)}', style: TextStyle(color: context.monova.muted)),
          const SizedBox(height: 16),
          _AccountPicker(value: _accountId, onChanged: (v) => setState(() => _accountId = v), label: 'Money arrives in'),
          const SizedBox(height: 12),
          TextFormField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount received', prefixText: '₹ '), validator: validateAmount),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Record collection')),
        ],
      ),
    );
  }
}

/// Loans and EMIs: outstanding principal, schedule, and paying the next installment in order.
class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loans = ref.watch(loansProvider);
    final c = context.monova;
    return Scaffold(
      appBar: AppBar(title: const Text('Loans & EMI')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accentStart,
        foregroundColor: c.onAccent,
        onPressed: () => FormSheet.show<void>(context, title: 'New loan', child: const _LoanForm()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Loan'),
      ),
      body: loans.when(
        loading: () => const LoadingBox(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(loansProvider)),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            if (list.isEmpty)
              const EmptyState(icon: Icons.directions_car_rounded, title: 'No loans', message: 'Add a loan to see its EMI schedule and what is still outstanding.'),
            for (final loan in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: MonovaCard(
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => _LoanDetailSheet(loanId: loan.id),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(loan.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                          Text(loan.isClosed ? 'Closed' : 'Active', style: TextStyle(color: loan.isClosed ? c.income : c.warning, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      Text(loan.lender, style: TextStyle(color: c.muted, fontSize: 12)),
                      const SizedBox(height: 10),
                      ProgressBar(value: loan.termMonths == 0 ? 0 : loan.paidInstallments / loan.termMonths * 100, color: c.accentStart),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: Text('EMI ${money(loan.emiAmount)} · ${loan.paidInstallments}/${loan.termMonths} paid', style: TextStyle(color: c.muted, fontSize: 12))),
                          AmountText('Outstanding ${money(loan.outstanding)}', tone: AmountTone.expense, size: 13),
                        ],
                      ),
                      if (loan.nextDueOn != null) ...[
                        const SizedBox(height: 6),
                        Text('Next EMI ${money(loan.nextAmount ?? 0)} due ${dayLabel(loan.nextDueOn!)}', style: TextStyle(color: c.warning, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoanDetailSheet extends ConsumerStatefulWidget {
  const _LoanDetailSheet({required this.loanId});

  final String loanId;

  @override
  ConsumerState<_LoanDetailSheet> createState() => _LoanDetailSheetState();
}

class _LoanDetailSheetState extends ConsumerState<_LoanDetailSheet> {
  String? _accountId;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final loans = ref.watch(loansProvider);
    final c = context.monova;
    return loans.maybeWhen(
      data: (list) {
        final matches = list.where((l) => l.id == widget.loanId);
        if (matches.isEmpty) return const SizedBox.shrink();
        final loan = matches.first;
        final next = loan.schedule.where((i) => !i.isPaid).isEmpty ? null : loan.schedule.firstWhere((i) => !i.isPaid);
        return Container(
          decoration: BoxDecoration(color: c.raised, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 12),
              Text(loan.name, style: Theme.of(context).textTheme.titleLarge),
              Text('Principal ${money(loan.principal)} · ${loan.annualRate.toStringAsFixed(2)}% · ${loan.termMonths} months', style: TextStyle(color: c.muted)),
              const SizedBox(height: 8),
              Text('Total interest ${money(loan.totalInterest)}', style: TextStyle(color: c.muted)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final i in loan.schedule)
                      ListTile(
                        dense: true,
                        leading: Icon(i.isPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: i.isPaid ? c.income : c.muted),
                        title: Text('EMI ${i.number} · ${dayLabel(i.dueOn)}'),
                        subtitle: Text('Principal ${money(i.principalComponent)} · Interest ${money(i.interestComponent)}', style: TextStyle(color: c.muted, fontSize: 12)),
                        trailing: AmountText(money(i.amount), size: 13),
                      ),
                  ],
                ),
              ),
              if (next != null) ...[
                const SizedBox(height: 8),
                _AccountPicker(value: _accountId, onChanged: (v) => setState(() => _accountId = v), label: 'Pay EMI from'),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _busy || _accountId == null
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          final ok = await runAction(context, () async {
                            await ref.read(repositoryProvider).payInstallment(loan.id, next.number, accountId: _accountId!);
                            ref.invalidate(loansProvider);
                            ref.invalidate(accountsProvider);
                            ref.invalidate(dashboardProvider);
                          }, success: 'EMI ${next.number} paid');
                          if (!mounted) return;
                          setState(() => _busy = false);
                          if (ok) Navigator.of(context).maybePop();
                        },
                  child: Text('Pay EMI ${next.number} · ${money(next.amount)}'),
                ),
              ],
            ],
          ),
        );
      },
      orElse: () => const LoadingBox(),
    );
  }
}

class _LoanForm extends ConsumerStatefulWidget {
  const _LoanForm();

  @override
  ConsumerState<_LoanForm> createState() => _LoanFormState();
}

class _LoanFormState extends ConsumerState<_LoanForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _lender = TextEditingController();
  final _principal = TextEditingController();
  final _rate = TextEditingController();
  final _term = TextEditingController(text: '12');
  String? _accountId;
  DateTime _start = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _lender, _principal, _rate, _term]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await runAction(context, () async {
      await ref.read(repositoryProvider).addLoan(
            name: _name.text.trim(),
            lender: _lender.text.trim(),
            principal: parseAmount(_principal.text)!,
            annualRate: double.parse(_rate.text),
            termMonths: int.parse(_term.text),
            startOn: _start,
            accountId: _accountId!,
          );
      ref.invalidate(loansProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(dashboardProvider);
    }, success: 'Loan added');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Loan name (e.g. Car loan)'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _lender, decoration: const InputDecoration(labelText: 'Lender'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _principal, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Principal', prefixText: '₹ '), validator: validateAmount),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Interest % a year'),
                  validator: (v) {
                    final r = double.tryParse(v ?? '');
                    return (r == null || r < 0 || r > 100) ? '0–100' : null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _term,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Months'),
                  validator: (v) {
                    final t = int.tryParse(v ?? '');
                    return (t == null || t < 1 || t > 600) ? '1–600' : null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AccountPicker(value: _accountId, onChanged: (v) => setState(() => _accountId = v), label: 'Proceeds arrive in'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime(2000), lastDate: DateTime.now());
              if (picked != null) setState(() => _start = picked);
            },
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: Text('Started on ${dayLabel(_start)}'),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Create loan and schedule')),
        ],
      ),
    );
  }
}
