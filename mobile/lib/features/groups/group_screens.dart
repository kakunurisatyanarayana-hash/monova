import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/finance_repository.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../tools/tools_screens.dart';

/// Groups you split bills with. Balances are calculated by the server, so every device shows the same numbers.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.monova;
    if (!ref.watch(sessionProvider).isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Groups')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            MonovaCard(
              onTap: () => context.push('/tools/split'),
              child: Row(
                children: [
                  Icon(Icons.call_split_rounded, color: c.accentStart),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Split a bill now', style: TextStyle(fontWeight: FontWeight.w700))),
                  Icon(Icons.chevron_right_rounded, color: c.muted),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SignInGate(
              title: 'Save groups and balances',
              message: 'Sign in to keep your groups, settle up with friends and see balances on every device.',
              actionLabel: 'Sign in to save groups',
            ),
          ],
        ),
      );
    }
    final groups = ref.watch(groupsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accentStart,
        foregroundColor: c.onAccent,
        onPressed: () => FormSheet.show<void>(context, title: 'New group', child: const _NewGroupForm()),
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Group'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(groupsProvider.future),
        child: groups.when(
          loading: () => const LoadingBox(),
          error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(groupsProvider)),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (list.isEmpty)
                EmptyState(
                  icon: Icons.groups_rounded,
                  title: 'Split bills without the awkward chase',
                  message: 'Create a group for a trip, a flat or a dinner. Add who shares, and MONOVA works out who owes whom.',
                  actionLabel: 'Create a group',
                  onAction: () => FormSheet.show<void>(context, title: 'New group', child: const _NewGroupForm()),
                ),
              for (final g in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MonovaCard(
                    onTap: () => context.push('/groups/${g.id}'),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(16)),
                          child: Text(g.emoji ?? '👥', style: const TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              Text('${g.memberCount} people', style: TextStyle(color: c.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        _NetBadge(net: g.yourNet),
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

class _NetBadge extends StatelessWidget {
  const _NetBadge({required this.net});

  final double net;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    if (net.abs() < 0.005) return Text('Settled', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600));
    final owed = net > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(owed ? 'you are owed' : 'you owe', style: TextStyle(color: c.muted, fontSize: 11)),
        AmountText(money(net.abs()), tone: owed ? AmountTone.income : AmountTone.expense, size: 14),
      ],
    );
  }
}

class _NewGroupForm extends ConsumerStatefulWidget {
  const _NewGroupForm();

  @override
  ConsumerState<_NewGroupForm> createState() => _NewGroupFormState();
}

class _NewGroupFormState extends ConsumerState<_NewGroupForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _emoji = TextEditingController(text: '👥');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    String? newId;
    final ok = await runAction(context, () async {
      final group = await ref.read(repositoryProvider).createGroup(_name.text.trim(), emoji: _emoji.text.trim());
      newId = group.id;
      ref.invalidate(groupsProvider);
    }, success: 'Group created');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok && newId != null) {
      Navigator.of(context).maybePop();
      context.push('/groups/$newId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Group name (e.g. Goa trip)'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _emoji, decoration: const InputDecoration(labelText: 'Emoji')),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Create group')),
        ],
      ),
    );
  }
}

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(groupDetailProvider(id));
    final balances = ref.watch(groupBalancesProvider(id));
    final expenses = ref.watch(groupExpensesProvider(id));
    final c = context.monova;

    void refreshAll() {
      ref.invalidate(groupDetailProvider(id));
      ref.invalidate(groupBalancesProvider(id));
      ref.invalidate(groupExpensesProvider(id));
      ref.invalidate(groupsProvider);
      ref.invalidate(dashboardProvider);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.maybeWhen(data: (d) => '${d.emoji ?? ''} ${d.name}'.trim(), orElse: () => 'Group')),
        actions: [
          IconButton(
            tooltip: 'Add a person',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => FormSheet.show<void>(context, title: 'Add a person', child: _AddMemberForm(groupId: id)),
          ),
        ],
      ),
      floatingActionButton: detail.maybeWhen(
        data: (d) => FloatingActionButton.extended(
          backgroundColor: c.accentStart,
          foregroundColor: c.onAccent,
          onPressed: () => FormSheet.show<void>(context, title: 'Split an expense', child: _GroupExpenseForm(groupId: id, members: d.members)),
          icon: const Icon(Icons.receipt_long_rounded),
          label: const Text('Expense'),
        ),
        orElse: () => null,
      ),
      body: RefreshIndicator(
        onRefresh: () async => refreshAll(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            balances.when(
              loading: () => const LoadingBox(),
              error: (e, _) => ErrorState(error: e, onRetry: refreshAll),
              data: (b) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MonovaCard(
                    gradient: c.aurora,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your position', style: TextStyle(color: c.onAccent.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          b.yourNet.abs() < 0.005 ? 'All settled up' : (b.yourNet > 0 ? '+${money(b.yourNet)} owed to you' : '−${money(-b.yourNet)} you owe'),
                          style: TextStyle(color: c.onAccent, fontSize: 24, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SectionTitle('Who pays whom'),
                  const SizedBox(height: 8),
                  if (b.suggestions.isEmpty)
                    MonovaCard(child: Text('Everyone is settled.', style: TextStyle(color: c.muted)))
                  else
                    for (final s in b.suggestions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: MonovaCard(
                          child: Row(
                            children: [
                              Expanded(child: Text('${s.fromName} → ${s.toName}', style: const TextStyle(fontWeight: FontWeight.w600))),
                              AmountText(money(s.amount), size: 15),
                              if (detail.maybeWhen(data: (d) => d.members.any((m) => m.isSelf && (m.id == s.fromMemberId || m.id == s.toMemberId)), orElse: () => false)) ...[
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: () => FormSheet.show<void>(context, title: 'Settle up', child: _SettleForm(groupId: id, suggestion: s)),
                                  child: const Text('Settle'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  const SizedBox(height: 16),
                  const SectionTitle('Members'),
                  const SizedBox(height: 8),
                  MonovaCard(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in b.members)
                          Chip(
                            avatar: CircleAvatar(child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase(), style: const TextStyle(fontSize: 12))),
                            label: Text(m.isSelf ? 'You' : m.name),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionTitle('Expenses'),
            const SizedBox(height: 8),
            expenses.when(
              loading: () => const LoadingBox(),
              error: (e, _) => ErrorState(error: e, onRetry: refreshAll),
              data: (page) => page.items.isEmpty
                  ? const EmptyState(icon: Icons.receipt_long_rounded, title: 'No shared expenses', message: 'Add the first bill and choose how it is split.')
                  : MonovaCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          for (final e in page.items)
                            ListTile(
                              onLongPress: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete this expense?'),
                                    content: const Text('Balances will be recalculated for everyone.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                    ],
                                  ),
                                );
                                if (ok != true) return;
                                await runAction(context, () => ref.read(repositoryProvider).deleteGroupExpense(id, e.id), success: 'Deleted');
                                refreshAll();
                              },
                              title: Text(e.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('Paid by ${e.payerNames.join(', ')} · ${relativeDay(e.occurredOn)}', style: TextStyle(color: c.muted)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  AmountText(money(e.amount), size: 14),
                                  Text('your share ${money(e.yourShare)}', style: TextStyle(color: c.muted, fontSize: 11)),
                                ],
                              ),
                            ),
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

class _AddMemberForm extends ConsumerStatefulWidget {
  const _AddMemberForm({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_AddMemberForm> createState() => _AddMemberFormState();
}

class _AddMemberFormState extends ConsumerState<_AddMemberForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await runAction(context, () async {
      await ref.read(repositoryProvider).addMember(widget.groupId, _name.text.trim());
      ref.invalidate(groupDetailProvider(widget.groupId));
      ref.invalidate(groupBalancesProvider(widget.groupId));
    }, success: 'Added');
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
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 8),
          Text('People are added by name for now. They do not need an account.', style: TextStyle(color: context.monova.muted, fontSize: 12)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Add')),
        ],
      ),
    );
  }
}

class _SettleForm extends ConsumerStatefulWidget {
  const _SettleForm({required this.groupId, required this.suggestion});

  final String groupId;
  final SuggestedPayment suggestion;

  @override
  ConsumerState<_SettleForm> createState() => _SettleFormState();
}

class _SettleFormState extends ConsumerState<_SettleForm> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.suggestion.amount.toStringAsFixed(2));
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
      await ref.read(repositoryProvider).settle(
            widget.groupId,
            from: widget.suggestion.fromMemberId,
            to: widget.suggestion.toMemberId,
            amount: parseAmount(_amount.text)!,
            accountId: _accountId!,
          );
      ref.invalidate(groupBalancesProvider(widget.groupId));
      ref.invalidate(groupDetailProvider(widget.groupId));
      ref.invalidate(groupsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(dashboardProvider);
    }, success: 'Settlement recorded');
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
          Text('${widget.suggestion.fromName} → ${widget.suggestion.toName}. You can settle part of it now.', style: TextStyle(color: context.monova.muted)),
          const SizedBox(height: 12),
          accounts.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Could not load accounts'),
            data: (list) => DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Account the money moves through'),
              items: [for (final a in list.where((a) => a.isActive)) DropdownMenuItem(value: a.id, child: Text('${a.name} · ${money(a.currentBalance)}'))],
              onChanged: (v) => setState(() => _accountId = v),
              validator: (v) => v == null ? 'Choose an account' : null,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '), validator: validateAmount),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Record settlement')),
        ],
      ),
    );
  }
}

/// Splits a shared bill. Equal divides evenly; Exact, Percent and Shares take one value per person.
class _GroupExpenseForm extends ConsumerStatefulWidget {
  const _GroupExpenseForm({required this.groupId, required this.members});

  final String groupId;
  final List<GroupMemberItem> members;

  @override
  ConsumerState<_GroupExpenseForm> createState() => _GroupExpenseFormState();
}

class _GroupExpenseFormState extends ConsumerState<_GroupExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  late String _payerId = widget.members.firstWhere((m) => m.isSelf, orElse: () => widget.members.first).id;
  String? _accountId;
  String _mode = 'Equal';
  late final Set<String> _included = widget.members.map((m) => m.id).toSet();
  final Map<String, TextEditingController> _values = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final m in widget.members) {
      _values[m.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    for (final c in _values.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _payerIsSelf => widget.members.any((m) => m.id == _payerId && m.isSelf);

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = parseAmount(_amount.text)!;
    final participants = widget.members.where((m) => _included.contains(m.id)).toList();
    if (participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose who shares this expense')));
      return;
    }
    if (_payerIsSelf && _accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose the account you paid from')));
      return;
    }

    final body = <String, dynamic>{
      'description': _description.text.trim(),
      'amount': amount,
      'occurredOn': ymd(DateTime.now()),
      'categoryId': null,
      'splitMode': _mode,
      'paidFromAccountId': _payerIsSelf ? _accountId : null,
      'payers': [
        {'memberId': _payerId, 'amount': amount},
      ],
      'participants': [
        for (final m in participants)
          {
            'memberId': m.id,
            'value': _mode == 'Equal' ? null : double.tryParse(_values[m.id]!.text.trim()),
          },
      ],
    };

    setState(() => _saving = true);
    final ok = await runAction(context, () async {
      await ref.read(repositoryProvider).addGroupExpense(widget.groupId, body);
      ref.invalidate(groupBalancesProvider(widget.groupId));
      ref.invalidate(groupExpensesProvider(widget.groupId));
      ref.invalidate(groupsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(dashboardProvider);
    }, success: 'Expense split');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final accounts = ref.watch(accountsProvider);
    final hint = switch (_mode) {
      'Exact' => 'Enter each person\'s exact share. They must add up to the total.',
      'Percent' => 'Enter each person\'s percentage. They must add up to 100.',
      'Shares' => 'Enter relative shares, e.g. 2 for two adults and 1 for a child.',
      _ => 'Split evenly between the people you select.',
    };

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'What was it for?'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Total amount', prefixText: '₹ '), validator: validateAmount),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _payerId,
            decoration: const InputDecoration(labelText: 'Paid by'),
            items: [for (final m in widget.members) DropdownMenuItem(value: m.id, child: Text(m.isSelf ? 'You' : m.name))],
            onChanged: (v) => setState(() => _payerId = v!),
          ),
          if (_payerIsSelf) ...[
            const SizedBox(height: 12),
            accounts.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Could not load accounts'),
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: const InputDecoration(labelText: 'Paid from account'),
                items: [for (final a in list.where((a) => a.isActive)) DropdownMenuItem(value: a.id, child: Text('${a.name} · ${money(a.currentBalance)}'))],
                onChanged: (v) => setState(() => _accountId = v),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Equal', label: Text('Equal')),
              ButtonSegment(value: 'Exact', label: Text('Exact')),
              ButtonSegment(value: 'Percent', label: Text('%')),
              ButtonSegment(value: 'Shares', label: Text('Shares')),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 8),
          Text(hint, style: TextStyle(color: c.muted, fontSize: 12)),
          const SizedBox(height: 8),
          for (final m in widget.members)
            Row(
              children: [
                Checkbox(
                  value: _included.contains(m.id),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _included.add(m.id);
                    } else {
                      _included.remove(m.id);
                    }
                  }),
                ),
                Expanded(child: Text(m.isSelf ? 'You' : m.name)),
                if (_mode != 'Equal')
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _values[m.id],
                      enabled: _included.contains(m.id),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(isDense: true, labelText: _mode == 'Percent' ? '%' : (_mode == 'Shares' ? 'Shares' : 'Amount')),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Save expense')),
        ],
      ),
    );
  }
}
