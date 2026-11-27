import 'package:monova_app/core/input_rules.dart';
import 'package:flutter/material.dart';

import '../../core/entry_store.dart';
import '../../core/format.dart';
import '../../core/money_plans.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../shared/date_inputs.dart';

int _cents(String text) {
  final v = double.tryParse(text.replaceAll(',', '').trim());
  if (v == null || v < 0) return 0;
  return (v * 100).round();
}

String _id() => DateTime.now().microsecondsSinceEpoch.toString();

/// Budgets, savings goals and recurring money, all on this phone. Works without any network.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  List<Budget> _budgets = const [];
  List<SavingsGoal> _goals = const [];
  List<RecurringEntry> _recurring = const [];
  List<MoneyEntry> _entries = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    await PlansStore.runRecurring(now);
    final budgets = await PlansStore.loadBudgets();
    final goals = await PlansStore.loadGoals();
    final recurring = await PlansStore.loadRecurring();
    final entries = await EntryStore.loadEntries();
    if (!mounted) return;
    setState(() {
      _budgets = budgets;
      _goals = goals;
      _recurring = recurring;
      _entries = entries;
      _loaded = true;
    });
  }

  // ---- Budgets ----

  Future<void> _editBudget([Budget? existing]) async {
    final result = await FormSheet.show<Budget>(
      context,
      title: existing == null ? 'New budget' : 'Edit budget',
      child: _BudgetForm(initial: existing),
    );
    if (result == null) return;
    final next = existing == null ? [..._budgets, result] : [for (final b in _budgets) b.id == existing.id ? result : b];
    setState(() => _budgets = next);
    await PlansStore.saveBudgets(next);
  }

  Future<void> _deleteBudget(Budget b) async {
    final next = [for (final x in _budgets) if (x.id != b.id) x];
    setState(() => _budgets = next);
    await PlansStore.saveBudgets(next);
  }

  // ---- Goals ----

  Future<void> _editGoal([SavingsGoal? existing]) async {
    final result = await FormSheet.show<SavingsGoal>(
      context,
      title: existing == null ? 'New savings goal' : 'Edit goal',
      child: _GoalForm(initial: existing),
    );
    if (result == null) return;
    final next = existing == null ? [..._goals, result] : [for (final g in _goals) g.id == existing.id ? result.copyWith() : g];
    setState(() => _goals = next);
    await PlansStore.saveGoals(next);
  }

  Future<void> _addToGoal(SavingsGoal g) async {
    final cents = await FormSheet.show<int>(context, title: 'Add to ${g.name}', child: const _AmountForm(label: 'Amount saved', action: 'Add'));
    if (cents == null || cents == 0) return;
    final next = [for (final x in _goals) x.id == g.id ? x.withContribution(cents) : x];
    setState(() => _goals = next);
    await PlansStore.saveGoals(next);
  }

  Future<void> _deleteGoal(SavingsGoal g) async {
    final next = [for (final x in _goals) if (x.id != g.id) x];
    setState(() => _goals = next);
    await PlansStore.saveGoals(next);
  }

  // ---- Recurring ----

  Future<void> _editRecurring([RecurringEntry? existing]) async {
    final result = await FormSheet.show<RecurringEntry>(
      context,
      title: existing == null ? 'New recurring entry' : 'Edit recurring entry',
      child: _RecurringForm(initial: existing),
    );
    if (result == null) return;
    final next = existing == null ? [..._recurring, result] : [for (final r in _recurring) r.id == existing.id ? result : r];
    setState(() => _recurring = next);
    await PlansStore.saveRecurring(next);
    await _load();
  }

  Future<void> _deleteRecurring(RecurringEntry r) async {
    final next = [for (final x in _recurring) if (x.id != r.id) x];
    setState(() => _recurring = next);
    await PlansStore.saveRecurring(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets, goals and recurring')),
      body: !_loaded
          ? const LoadingBox()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _Section(
                  title: 'Monthly budgets',
                  subtitle: 'A limit for each category. Spending comes from your income and spending records.',
                  actionLabel: 'Add budget',
                  onAction: () => _editBudget(),
                  empty: 'No budgets yet. Add one for food, travel or shopping.',
                  isEmpty: _budgets.isEmpty,
                  children: [
                    for (final b in _budgets) _budgetTile(b, c, now),
                  ],
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Savings goals',
                  subtitle: 'Something you are saving towards.',
                  actionLabel: 'Add goal',
                  onAction: () => _editGoal(),
                  empty: 'No goals yet. Add a trip, a bike or an emergency fund.',
                  isEmpty: _goals.isEmpty,
                  children: [
                    for (final g in _goals) _goalTile(g, c),
                  ],
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Recurring every month',
                  subtitle: 'Rent, bills or a salary. Each month is added to your records once, on its day.',
                  actionLabel: 'Add recurring',
                  onAction: () => _editRecurring(),
                  empty: 'Nothing recurring yet.',
                  isEmpty: _recurring.isEmpty,
                  children: [
                    for (final r in _recurring) _recurringTile(r, c),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _budgetTile(Budget b, MonovaColors c, DateTime now) {
    final spent = spentInCategory(_entries, b.category, now.year, now.month);
    final status = BudgetStatus(spentCents: spent, limitCents: b.limitCents);
    final color = switch (status.state) {
      BudgetState.over => c.expense,
      BudgetState.nearLimit => c.warning,
      BudgetState.ok => c.income,
    };
    final note = switch (status.state) {
      BudgetState.over => 'Over by ${money(-status.remainingCents / 100)}',
      BudgetState.nearLimit => 'Close to the limit · ${money(status.remainingCents / 100)} left',
      BudgetState.ok => '${money(status.remainingCents / 100)} left',
    };
    return _Tile(
      title: b.category,
      subtitle: '${money(spent / 100)} of ${money(b.limitCents / 100)} in ${monthLabel(now.year, now.month)} · $note',
      progress: status.used.clamp(0.0, 1.0),
      color: color,
      onEdit: () => _editBudget(b),
      onDelete: () => _deleteBudget(b),
    );
  }

  Widget _goalTile(SavingsGoal g, MonovaColors c) {
    return _Tile(
      title: g.name,
      subtitle: g.reached
          ? 'Reached: ${money(g.savedCents / 100)}'
          : '${money(g.savedCents / 100)} of ${money(g.targetCents / 100)} · ${money(g.remainingCents / 100)} to go'
              '${g.dueDate == null ? '' : ' · by ${dayLabel(g.dueDate!)}'}',
      progress: g.progress,
      color: g.reached ? c.income : c.accentStart,
      actionLabel: g.reached ? null : 'Add money',
      onAction: g.reached ? null : () => _addToGoal(g),
      onEdit: () => _editGoal(g),
      onDelete: () => _deleteGoal(g),
    );
  }

  Widget _recurringTile(RecurringEntry r, MonovaColors c) {
    return _Tile(
      title: r.title,
      subtitle: '${r.income ? 'Income' : 'Spending'} · ${money(r.cents / 100)} on day ${r.dayOfMonth} every month'
          '${r.lastCreatedMonth.isEmpty ? '' : ' · last added ${r.lastCreatedMonth}'}',
      color: r.income ? c.income : c.expense,
      onEdit: () => _editRecurring(r),
      onDelete: () => _deleteRecurring(r),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.empty,
    required this.isEmpty,
    required this.children,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final String empty;
  final bool isEmpty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SectionTitle(title)),
            TextButton.icon(onPressed: onAction, icon: const Icon(Icons.add_rounded, size: 18), label: Text(actionLabel)),
          ],
        ),
        Text(subtitle, style: TextStyle(color: c.muted, fontSize: 12)),
        const SizedBox(height: 8),
        if (isEmpty) MonovaCard(child: Text(empty, style: TextStyle(color: c.muted))) else ...children,
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onEdit,
    required this.onDelete,
    this.progress,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final Color color;
  final double? progress;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MonovaCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        onTap: onEdit,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
                if (onAction != null && actionLabel != null)
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
                IconButton(tooltip: 'Edit', icon: Icon(Icons.edit_outlined, color: c.accentStart), onPressed: onEdit),
                IconButton(tooltip: 'Delete', icon: Icon(Icons.delete_outline_rounded, color: c.muted), onPressed: onDelete),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(subtitle, style: TextStyle(color: c.muted, fontSize: 12, height: 1.4)),
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              ProgressBar(value: progress!, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetForm extends StatefulWidget {
  const _BudgetForm({this.initial});

  final Budget? initial;

  @override
  State<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<_BudgetForm> {
  late final _category = TextEditingController(text: widget.initial?.category ?? '');
  late final _limit = TextEditingController(
    text: widget.initial == null ? '' : (widget.initial!.limitCents / 100).toStringAsFixed(0),
  );
  String? _error;

  @override
  void dispose() {
    _category.dispose();
    _limit.dispose();
    super.dispose();
  }

  void _save() {
    final category = _category.text.trim();
    final cents = _cents(_limit.text);
    if (category.isEmpty) {
      setState(() => _error = 'Name the category, exactly as you record spending, for example Food.');
      return;
    }
    if (cents <= 0) {
      setState(() => _error = 'Enter the monthly limit.');
      return;
    }
    Navigator.of(context).pop(Budget(id: widget.initial?.id ?? _id(), category: category, limitCents: cents));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _category, autofocus: widget.initial == null, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Category')),
        const SizedBox(height: 12),
        TextField(controller: _limit, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: amountFormatters, decoration: const InputDecoration(labelText: 'Monthly limit', prefixText: '₹ ')),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: const Text('Save budget')),
      ],
    );
  }
}

class _GoalForm extends StatefulWidget {
  const _GoalForm({this.initial});

  final SavingsGoal? initial;

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _target = TextEditingController(
    text: widget.initial == null ? '' : (widget.initial!.targetCents / 100).toStringAsFixed(0),
  );
  late DateTime? _due = widget.initial?.dueDate;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final cents = _cents(_target.text);
    if (name.isEmpty) {
      setState(() => _error = 'Name the goal, for example "Emergency fund".');
      return;
    }
    if (cents <= 0) {
      setState(() => _error = 'Enter the amount you are saving towards.');
      return;
    }
    final base = widget.initial;
    Navigator.of(context).pop(SavingsGoal(
      id: base?.id ?? _id(),
      name: name,
      targetCents: cents,
      savedCents: base?.savedCents ?? 0,
      dueDate: _due,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _name, autofocus: widget.initial == null, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Goal name')),
        const SizedBox(height: 12),
        TextField(controller: _target, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: amountFormatters, decoration: const InputDecoration(labelText: 'Target amount', prefixText: '₹ ')),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Set a date to reach it'),
          value: _due != null,
          onChanged: (v) => setState(() => _due = v ? DateTime.now().add(const Duration(days: 180)) : null),
        ),
        if (_due != null) DateSelector(label: 'Reach it by', value: _due, firstYear: DateTime.now().year, lastYear: DateTime.now().year + 20, onChanged: (d) => setState(() => _due = d)),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: const Text('Save goal')),
      ],
    );
  }
}

/// Returns the amount in cents, or null when cancelled.
class _AmountForm extends StatefulWidget {
  const _AmountForm({required this.label, required this.action});

  final String label;
  final String action;

  @override
  State<_AmountForm> createState() => _AmountFormState();
}

class _AmountFormState extends State<_AmountForm> {
  final _amount = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final cents = _cents(_amount.text);
    if (cents <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    Navigator.of(context).pop(cents);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _amount, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: amountFormatters, decoration: InputDecoration(labelText: widget.label, prefixText: '₹ ')),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: Text(widget.action)),
      ],
    );
  }
}

class _RecurringForm extends StatefulWidget {
  const _RecurringForm({this.initial});

  final RecurringEntry? initial;

  @override
  State<_RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends State<_RecurringForm> {
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _category = TextEditingController(text: widget.initial?.category ?? '');
  late final _amount = TextEditingController(
    text: widget.initial == null ? '' : (widget.initial!.cents / 100).toStringAsFixed(0),
  );
  late bool _income = widget.initial?.income ?? false;
  late int _day = widget.initial?.dayOfMonth ?? 1;
  late DateTime _start = widget.initial?.startDate ?? DateTime.now();
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    final cents = _cents(_amount.text);
    if (title.isEmpty) {
      setState(() => _error = 'Name it, for example "House rent" or "Salary".');
      return;
    }
    if (cents <= 0) {
      setState(() => _error = 'Enter the amount.');
      return;
    }
    final base = widget.initial;
    Navigator.of(context).pop(RecurringEntry(
      id: base?.id ?? _id(),
      title: title,
      category: _category.text.trim().isEmpty ? (_income ? 'Salary' : 'Other') : _category.text.trim(),
      cents: cents,
      income: _income,
      dayOfMonth: _day,
      startDate: DateTime(_start.year, _start.month, _start.day),
      lastCreatedMonth: base?.lastCreatedMonth ?? '',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Spending')),
            ButtonSegment(value: true, label: Text('Income')),
          ],
          selected: {_income},
          onSelectionChanged: (s) => setState(() => _income = s.first),
        ),
        const SizedBox(height: 12),
        TextField(controller: _title, autofocus: widget.initial == null, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Name *')),
        const SizedBox(height: 12),
        TextField(controller: _category, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Category (for example Housing, Internet)')),
        const SizedBox(height: 12),
        TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: amountFormatters, decoration: const InputDecoration(labelText: 'Amount each month', prefixText: '₹ ')),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _day,
          decoration: const InputDecoration(labelText: 'Day of the month'),
          items: [for (var d = 1; d <= 28; d++) DropdownMenuItem(value: d, child: Text('$d'))],
          onChanged: (v) => setState(() => _day = v ?? _day),
        ),
        const SizedBox(height: 12),
        DateSelector(label: 'Starts from', value: _start, firstYear: DateTime.now().year - 5, lastYear: DateTime.now().year + 5, onChanged: (d) => setState(() => _start = d)),
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
