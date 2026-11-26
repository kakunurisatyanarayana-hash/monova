import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

const _accountTypes = {'Bank': 'Bank account', 'Savings': 'Savings', 'Cash': 'Cash', 'Wallet': 'Wallet'};

/// Bank accounts and cash with calculated balances. Balances come from the ledger, never typed in directly.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final c = context.monova;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [IconButton(tooltip: 'Credit cards', icon: const Icon(Icons.credit_card_rounded), onPressed: () => context.push('/cards'))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accentStart,
        foregroundColor: c.onAccent,
        onPressed: () => FormSheet.show<void>(context, title: 'New account', child: const _AccountForm()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Account'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(accountsProvider.future),
        child: accounts.when(
          loading: () => const LoadingBox(),
          error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(accountsProvider)),
          data: (list) {
            final total = list.where((a) => a.isActive).fold<double>(0, (s, a) => s + a.currentBalance);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                MonovaCard(
                  gradient: c.hero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total across accounts', style: TextStyle(color: c.onAccent.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(money(total), style: TextStyle(color: c.onAccent, fontSize: 30, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (list.isEmpty)
                  EmptyState(
                    icon: Icons.account_balance_rounded,
                    title: 'Add your first account',
                    message: 'Enter the opening balance. Every later movement updates it automatically.',
                    actionLabel: 'Add account',
                    onAction: () => FormSheet.show<void>(context, title: 'New account', child: const _AccountForm()),
                  ),
                for (final a in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MonovaCard(
                      onTap: () => context.push('/accounts/${a.id}'),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: c.border,
                            child: Icon(a.isBank ? Icons.account_balance_rounded : Icons.payments_rounded, color: c.ink),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  '${_accountTypes[a.type] ?? a.type}${a.bankName.isEmpty ? '' : ' · ${a.bankName}'}${a.isActive ? '' : ' · inactive'}',
                                  style: TextStyle(color: c.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          AmountText(money(a.currentBalance), tone: a.currentBalance < 0 ? AmountTone.expense : AmountTone.neutral),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccountForm extends ConsumerStatefulWidget {
  const _AccountForm();

  @override
  ConsumerState<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<_AccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _bank = TextEditingController();
  final _opening = TextEditingController(text: '0');
  String _type = 'Bank';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _bank.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await runAction(context, () async {
      await ref.read(repositoryProvider).createAccount(
            name: _name.text.trim(),
            bankName: _bank.text.trim(),
            type: _type,
            openingBalance: double.tryParse(_opening.text.replaceAll(',', '')) ?? 0,
          );
      ref.invalidate(accountsProvider);
      ref.invalidate(dashboardProvider);
    }, success: 'Account added');
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
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Account name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _bank, decoration: const InputDecoration(labelText: 'Bank (optional)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            menuMaxHeight: 260,
            items: [for (final e in _accountTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => _type = v ?? 'Bank'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _opening,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(labelText: 'Opening balance', prefixText: '₹ '),
            validator: (v) => double.tryParse((v ?? '').replaceAll(',', '')) == null ? 'Enter a number' : null,
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Save account')),
        ],
      ),
    );
  }
}

/// One account: current balance and its movement history (income, expenses, transfers, loans, savings and more).
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final history = ref.watch(accountHistoryProvider(id));
    final c = context.monova;
    final account = accounts.maybeWhen(
      data: (list) {
        final matches = list.where((a) => a.id == id);
        return matches.isEmpty ? null : matches.first;
      },
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(title: Text(account?.name ?? 'Account')),
      body: history.when(
        loading: () => const LoadingBox(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(accountHistoryProvider(id))),
        data: (page) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (account != null)
              MonovaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current balance', style: TextStyle(color: c.muted)),
                    const SizedBox(height: 4),
                    Text(money(account.currentBalance), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Opening ${money(account.openingBalance)}', style: TextStyle(color: c.muted, fontSize: 12)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const SectionTitle('Activity'),
            const SizedBox(height: 8),
            if (page.items.isEmpty)
              const EmptyState(icon: Icons.timeline_rounded, title: 'No movements yet', message: 'Money in and out of this account will be listed here.')
            else
              MonovaCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final m in page.items)
                      ListTile(
                        title: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${m.kind} · ${relativeDay(m.date)}', style: TextStyle(color: c.muted)),
                        trailing: AmountText(
                          moneySigned(m.amount),
                          tone: m.amount >= 0 ? AmountTone.income : AmountTone.neutral,
                          size: 14,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Credit cards: limit, outstanding, available credit, utilisation, billing cycle and next due date.
class CardsScreen extends ConsumerWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(cardsProvider);
    final c = context.monova;
    return Scaffold(
      appBar: AppBar(title: const Text('Credit cards')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accentStart,
        foregroundColor: c.onAccent,
        onPressed: () => FormSheet.show<void>(context, title: 'Add credit card', child: const _CardForm()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Card'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(cardsProvider.future),
        child: cards.when(
          loading: () => const LoadingBox(),
          error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(cardsProvider)),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (list.isEmpty)
                EmptyState(
                  icon: Icons.credit_card_rounded,
                  title: 'No cards yet',
                  message: 'Add a card to see your outstanding balance and due dates.',
                  actionLabel: 'Add card',
                  onAction: () => FormSheet.show<void>(context, title: 'Add credit card', child: const _CardForm()),
                ),
              for (final card in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: MonovaCard(
                    gradient: LinearGradient(colors: [c.raised, c.border], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('${card.issuer} · ${card.name}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                            Text('••${card.last4}', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: _Stat(label: 'Outstanding', value: money(card.outstanding), tone: AmountTone.expense)),
                            Expanded(child: _Stat(label: 'Available', value: money(card.availableCredit), tone: AmountTone.income)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ProgressBar(value: card.utilizationPercent, color: card.utilizationPercent >= 70 ? c.warning : c.accentStart),
                        const SizedBox(height: 6),
                        Text('${card.utilizationPercent.toStringAsFixed(1)}% of ${money(card.creditLimit)} limit', style: TextStyle(color: c.muted, fontSize: 12)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.event_rounded, size: 16, color: c.muted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Next due ${dayLabel(card.nextDueDate)} · statement day ${card.statementDay}',
                                style: TextStyle(color: c.muted, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonal(
                            onPressed: card.outstanding <= 0 ? null : () => FormSheet.show<void>(context, title: 'Pay card bill', child: _PayCardForm(card: card)),
                            child: const Text('Pay bill'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final AmountTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
        const SizedBox(height: 2),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: AmountText(value, tone: tone, size: 18)),
      ],
    );
  }
}

class _CardForm extends ConsumerStatefulWidget {
  const _CardForm();

  @override
  ConsumerState<_CardForm> createState() => _CardFormState();
}

class _CardFormState extends ConsumerState<_CardForm> {
  final _formKey = GlobalKey<FormState>();
  final _issuer = TextEditingController();
  final _name = TextEditingController();
  final _last4 = TextEditingController();
  final _limit = TextEditingController();
  final _statement = TextEditingController(text: '15');
  final _due = TextEditingController(text: '5');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_issuer, _name, _last4, _limit, _statement, _due]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await runAction(context, () async {
      await ref.read(repositoryProvider).addCard(
            issuer: _issuer.text.trim(),
            name: _name.text.trim(),
            last4: _last4.text.trim(),
            limit: parseAmount(_limit.text)!,
            statementDay: int.parse(_statement.text),
            dueDay: int.parse(_due.text),
          );
      ref.invalidate(cardsProvider);
      ref.invalidate(dashboardProvider);
    }, success: 'Card added');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).maybePop();
  }

  String? _day(String? v) {
    final n = int.tryParse(v ?? '');
    return (n == null || n < 1 || n > 28) ? 'Use a day from 1 to 28' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(controller: _issuer, decoration: const InputDecoration(labelText: 'Issuer (e.g. HDFC)'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Card name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _last4, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'Last four digits', counterText: ''), validator: (v) => (v == null || v.length != 4 || int.tryParse(v) == null) ? 'Enter four digits' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _limit, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Credit limit', prefixText: '₹ '), validator: validateAmount),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextFormField(controller: _statement, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Statement day'), validator: _day)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _due, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Due day'), validator: _day)),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Save card')),
        ],
      ),
    );
  }
}

class _PayCardForm extends ConsumerStatefulWidget {
  const _PayCardForm({required this.card});

  final CardItem card;

  @override
  ConsumerState<_PayCardForm> createState() => _PayCardFormState();
}

class _PayCardFormState extends ConsumerState<_PayCardForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  String? _accountId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount.text = widget.card.outstanding.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _accountId == null) return;
    setState(() => _saving = true);
    final ok = await runAction(context, () async {
      await ref.read(repositoryProvider).payCard(widget.card.id, fromAccountId: _accountId!, amount: parseAmount(_amount.text)!);
      ref.invalidate(cardsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(dashboardProvider);
    }, success: 'Bill paid');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Outstanding ${money(widget.card.outstanding)}. A bill payment moves money from your account and is not counted as an expense.',
              style: TextStyle(color: context.monova.muted)),
          const SizedBox(height: 16),
          accounts.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Could not load accounts'),
            data: (list) => DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Pay from'),
              menuMaxHeight: 260,
              items: [for (final a in list.where((a) => a.isActive)) DropdownMenuItem(value: a.id, child: Text('${a.name} · ${money(a.currentBalance)}'))],
              onChanged: (v) => setState(() => _accountId = v),
              validator: (v) => v == null ? 'Choose an account' : null,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '), validator: validateAmount),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Pay')),
        ],
      ),
    );
  }
}
