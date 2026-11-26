import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Monthly budget (overall and per category) and savings goals. Budget spend is calculated from real expenses, including your share of group bills.
class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen> {
  late ({int year, int month}) _period = (year: DateTime.now().year, month: DateTime.now().month);

  void _shift(int delta) {
    final d = DateTime(_period.year, _period.month + delta);
    setState(() => _period = (year: d.year, month: d.month));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final budget = ref.watch(budgetProvider(_period));
    final goals = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets & savings')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(budgetProvider(_period));
          ref.invalidate(goalsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
                Text(monthLabel(_period.year, _period.month), style: Theme.of(context).textTheme.titleMedium),
                IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded)),
              ],
            ),
            budget.when(
              loading: () => const LoadingBox(),
              error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(budgetProvider(_period))),
              data: (b) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MonovaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('Overall budget', style: const TextStyle(fontWeight: FontWeight.w700))),
                            TextButton(
                              onPressed: () => FormSheet.show<void>(context, title: 'Overall budget', child: _BudgetForm(period: _period, categoryId: null, current: b.overallBudget)),
                              child: Text(b.overallBudget > 0 ? 'Change' : 'Set'),
                            ),
                          ],
                        ),
                        if (b.overallBudget > 0) ...[
                          Text('${money(b.overallSpent)} of ${money(b.overallBudget)}', style: TextStyle(color: c.muted)),
                          const SizedBox(height: 10),
                          ProgressBar(
                            value: b.overallPercentUsed,
                            color: b.overallStatus == 'Over' ? c.expense : (b.overallStatus == 'Warning' ? c.warning : c.accentStart),
                          ),
                        ] else
                          Text('No overall budget yet for this month.', style: TextStyle(color: c.muted)),
                        for (final w in b.warnings) ...[
                          const SizedBox(height: 8),
                          Text(w, style: TextStyle(color: c.warning, fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (b.lines.isNotEmpty)
                    MonovaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Category budgets', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          for (final line in b.lines)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(child: Text(line.name)),
                                    Text('${money(line.spent)} / ${money(line.budget)}', style: TextStyle(color: c.muted, fontSize: 12)),
                                  ]),
                                  const SizedBox(height: 6),
                                  ProgressBar(value: line.percentUsed, color: line.status == 'Over' ? c.expense : (line.status == 'Warning' ? c.warning : c.accentStart)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => FormSheet.show<void>(context, title: 'Category budget', child: _CategoryBudgetForm(period: _period)),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add category budget'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Text('Savings goals', style: Theme.of(context).textTheme.titleMedium)),
                TextButton.icon(
                  onPressed: () => FormSheet.show<void>(context, title: 'New savings goal', child: const _GoalForm()),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Goal'),
                ),
              ],
            ),
            goals.when(
              loading: () => const LoadingBox(),
              error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(goalsProvider)),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(icon: Icons.savings_rounded, title: 'No goals yet', message: 'Set a target and track progress as you save.');
                }
                return Column(
                  children: [
                    for (final g in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: MonovaCard(
                          onTap: () => FormSheet.show<void>(context, title: g.name, child: _ContributeForm(goal: g)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(child: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                                Text('${g.percentComplete.toStringAsFixed(0)}%', style: TextStyle(color: c.income, fontWeight: FontWeight.w800)),
                              ]),
                              const SizedBox(height: 6),
                              Text('${money(g.saved)} saved of ${money(g.target)}', style: TextStyle(color: c.muted, fontSize: 12)),
                              const SizedBox(height: 10),
                              ProgressBar(value: g.percentComplete, color: c.income),
                              if (g.monthlyNeeded != null) ...[
                                const SizedBox(height: 8),
                                Text('Save ${money(g.monthlyNeeded!)} a month to reach it by ${g.targetDate == null ? '' : dayLabel(g.targetDate!)}',
                                    style: TextStyle(color: c.muted, fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetForm extends ConsumerStatefulWidget {
  const _BudgetForm({required this.period, required this.categoryId, required this.current});

  final ({int year, int month}) period;
  final String? categoryId;
  final double current;

  @override
  ConsumerState<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends ConsumerState<_BudgetForm> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.current > 0 ? widget.current.toStringAsFixed(0) : '');
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await runAction(context, () async {
      await ref.read(repositoryProvider).setBudget(widget.period.year, widget.period.month, parseAmount(_amount.text)!, categoryId: widget.categoryId);
      ref.invalidate(budgetProvider(widget.period));
      ref.invalidate(dashboardProvider);
    }, success: 'Budget saved');
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
          TextFormField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monthly amount', prefixText: '₹ '), validator: validateAmount),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Save budget')),
        ],
      ),
    );
  }
}

class _CategoryBudgetForm extends ConsumerStatefulWidget {
  const _CategoryBudgetForm({required this.period});

  final ({int year, int month}) period;

  @override
  ConsumerState<_CategoryBudgetForm> createState() => _CategoryBudgetFormState();
}

class _CategoryBudgetFormState extends ConsumerState<_CategoryBudgetForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  String? _categoryId;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _categoryId == null) return;
    setState(() => _saving = true);
    final ok = await runAction(context, () async {
      await ref.read(repositoryProvider).setBudget(widget.period.year, widget.period.month, parseAmount(_amount.text)!, categoryId: _categoryId);
      ref.invalidate(budgetProvider(widget.period));
    }, success: 'Category budget saved');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(expenseCategoriesProvider);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          categories.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Could not load categories'),
            data: (list) => DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              menuMaxHeight: 260,
              items: [for (final cat in list) DropdownMenuItem(value: cat.id, child: Text(cat.name))],
              onChanged: (v) => setState(() => _categoryId = v),
              validator: (v) => v == null ? 'Choose a category' : null,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monthly limit', prefixText: '₹ '), validator: validateAmount),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      ),
    );
  }
}

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm();

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _target = TextEditingController();
  DateTime? _targetDate;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await runAction(context, () async {
      await ref.read(repositoryProvider).addGoal(name: _name.text.trim(), target: parseAmount(_target.text)!, targetDate: _targetDate);
      ref.invalidate(goalsProvider);
    }, success: 'Goal created');
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
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Goal (e.g. Emergency fund)'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _target, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Target', prefixText: '₹ '), validator: validateAmount),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 180)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _targetDate = picked);
            },
            icon: const Icon(Icons.flag_rounded, size: 18),
            label: Text(_targetDate == null ? 'Target date (optional)' : 'By ${dayLabel(_targetDate!)}'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Create goal')),
        ],
      ),
    );
  }
}

class _ContributeForm extends ConsumerStatefulWidget {
  const _ContributeForm({required this.goal});

  final GoalItem goal;

  @override
  ConsumerState<_ContributeForm> createState() => _ContributeFormState();
}

class _ContributeFormState extends ConsumerState<_ContributeForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  String? _accountId;
  bool _withdraw = false;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _accountId == null) return;
    setState(() => _saving = true);
    final value = parseAmount(_amount.text)!;
    final ok = await runAction(context, () async {
      await ref.read(repositoryProvider).contribute(widget.goal.id, accountId: _accountId!, amount: _withdraw ? -value : value);
      ref.invalidate(goalsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(dashboardProvider);
    }, success: _withdraw ? 'Withdrawn' : 'Added to goal');
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
          Text('Saved ${money(widget.goal.saved)} of ${money(widget.goal.target)}', style: TextStyle(color: context.monova.muted)),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: false, label: Text('Add money')), ButtonSegment(value: true, label: Text('Withdraw'))],
            selected: {_withdraw},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _withdraw = s.first),
          ),
          const SizedBox(height: 12),
          accounts.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Could not load accounts'),
            data: (list) => DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: InputDecoration(labelText: _withdraw ? 'Return to account' : 'Take from account'),
              menuMaxHeight: 260,
              items: [for (final a in list.where((a) => a.isActive)) DropdownMenuItem(value: a.id, child: Text('${a.name} · ${money(a.currentBalance)}'))],
              onChanged: (v) => setState(() => _accountId = v),
              validator: (v) => v == null ? 'Choose an account' : null,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '), validator: validateAmount),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_withdraw ? 'Withdraw' : 'Add to goal')),
        ],
      ),
    );
  }
}
