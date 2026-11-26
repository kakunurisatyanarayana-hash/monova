import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

Future<void> showQuickAdd(BuildContext context) => FormSheet.show<void>(
      context,
      title: 'Add',
      child: const QuickAddForm(),
    );

enum _Kind { expense, income, transfer, lend, borrow }

/// One-screen quick entry. Defaults to today and the last-used-style first account, so a typical expense is amount + category + Save.
class QuickAddForm extends ConsumerStatefulWidget {
  const QuickAddForm({super.key});

  @override
  ConsumerState<QuickAddForm> createState() => _QuickAddFormState();
}

class _QuickAddFormState extends ConsumerState<QuickAddForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _counterparty = TextEditingController();
  final _rate = TextEditingController(text: '0');

  _Kind _kind = _Kind.expense;
  DateTime _on = DateTime.now();
  bool _onCard = false;
  String? _categoryId;
  String? _accountId;
  String? _cardId;
  String? _toAccountId;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_amount, _title, _note, _counterparty, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _on,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _on = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = parseAmount(_amount.text)!;
    final repo = ref.read(repositoryProvider);
    setState(() => _saving = true);

    final ok = await runAction(context, () async {
      switch (_kind) {
        case _Kind.expense:
        case _Kind.income:
          await repo.addTransaction(
            type: _kind == _Kind.expense ? 'Expense' : 'Income',
            amount: amount,
            on: _on,
            title: _title.text.trim().isEmpty ? (_kind == _Kind.expense ? 'Expense' : 'Income') : _title.text.trim(),
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            categoryId: _categoryId,
            accountId: _kind == _Kind.income || !_onCard ? _accountId : null,
            cardId: _kind == _Kind.expense && _onCard ? _cardId : null,
          );
          ref.invalidate(dashboardProvider);
          ref.invalidate(accountsProvider);
          ref.invalidate(cardsProvider);
          break;
        case _Kind.transfer:
          await repo.transfer(from: _accountId!, to: _toAccountId!, amount: amount, on: _on, note: _note.text.trim());
          ref.invalidate(dashboardProvider);
          ref.invalidate(accountsProvider);
          break;
        case _Kind.lend:
          await repo.addReceivable(counterparty: _counterparty.text.trim(), principal: amount, lentOn: _on, accountId: _accountId!, note: _note.text.trim());
          ref.invalidate(receivablesProvider);
          ref.invalidate(dashboardProvider);
          ref.invalidate(accountsProvider);
          break;
        case _Kind.borrow:
          await repo.addDebt(
            counterparty: _counterparty.text.trim(),
            principal: amount,
            annualRate: double.tryParse(_rate.text) ?? 0,
            borrowedOn: _on,
            accountId: _accountId!,
            note: _note.text.trim(),
          );
          ref.invalidate(debtsProvider);
          ref.invalidate(dashboardProvider);
          ref.invalidate(accountsProvider);
          break;
      }
    }, success: 'Saved');

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final cards = ref.watch(cardsProvider);
    final categories = ref.watch(_kind == _Kind.income ? incomeCategoriesProvider : expenseCategoriesProvider);
    final isMoneyIn = _kind == _Kind.income;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_Kind>(
            segments: const [
              ButtonSegment(value: _Kind.expense, label: Text('Expense')),
              ButtonSegment(value: _Kind.income, label: Text('Income')),
              ButtonSegment(value: _Kind.transfer, label: Text('Transfer')),
              ButtonSegment(value: _Kind.lend, label: Text('Lend')),
              ButtonSegment(value: _Kind.borrow, label: Text('Borrow')),
            ],
            selected: {_kind},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _kind = s.first;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(prefixText: 'â‚¹ ', labelText: 'Amount'),
            validator: validateAmount,
          ),
          const SizedBox(height: 12),
          if (_kind == _Kind.expense || _kind == _Kind.income)
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'What was it for? (optional)'),
            ),
          if (_kind == _Kind.lend || _kind == _Kind.borrow)
            TextFormField(
              controller: _counterparty,
              decoration: InputDecoration(labelText: _kind == _Kind.lend ? 'Lent to' : 'Borrowed from'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
          if ((_kind == _Kind.expense || _kind == _Kind.income)) ...[
            const SizedBox(height: 12),
            categories.when(
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                menuMaxHeight: 260,
                items: [for (final CategoryItem c in list) DropdownMenuItem(value: c.id, child: Text(c.name))],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load categories'),
            ),
          ],
          const SizedBox(height: 12),
          if (_kind == _Kind.expense) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Bank / cash')),
                ButtonSegment(value: true, label: Text('Credit card')),
              ],
              selected: {_onCard},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _onCard = s.first),
            ),
            const SizedBox(height: 12),
          ],
          if (_kind == _Kind.expense && _onCard)
            cards.when(
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _cardId,
                decoration: const InputDecoration(labelText: 'Credit card'),
                menuMaxHeight: 260,
                items: [for (final CardItem card in list) DropdownMenuItem(value: card.id, child: Text('${card.name} â€¢â€¢${card.last4}'))],
                onChanged: (v) => setState(() => _cardId = v),
                validator: (v) => v == null ? 'Choose a card' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => const Text('Could not load cards'),
            )
          else
            accounts.when(
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: InputDecoration(labelText: _kind == _Kind.transfer ? 'From account' : (isMoneyIn ? 'Receive into' : 'Account')),
                menuMaxHeight: 260,
                items: [for (final AccountItem a in list.where((a) => a.isActive)) DropdownMenuItem(value: a.id, child: Text(a.name))],
                onChanged: (v) => setState(() => _accountId = v),
                validator: (v) => v == null ? 'Choose an account' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => const Text('Could not load accounts'),
            ),
          if (_kind == _Kind.transfer) ...[
            const SizedBox(height: 12),
            accounts.maybeWhen(
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _toAccountId,
                decoration: const InputDecoration(labelText: 'To account'),
                menuMaxHeight: 260,
                items: [for (final AccountItem a in list.where((a) => a.isActive && a.id != _accountId)) DropdownMenuItem(value: a.id, child: Text(a.name))],
                onChanged: (v) => setState(() => _toAccountId = v),
                validator: (v) => v == null ? 'Choose the destination' : null,
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
          if (_kind == _Kind.borrow) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _rate,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Annual interest % (0 for none)'),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: Text(relativeDay(_on)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Save'),
          ),
          if (_kind == _Kind.expense) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).maybePop();
                GoRouter.of(context).go('/groups');
              },
              icon: const Icon(Icons.call_split_rounded),
              label: const Text('Split a group expense instead'),
            ),
          ],
        ],
      ),
    );
  }
}
