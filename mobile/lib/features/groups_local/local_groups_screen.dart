import 'package:monova_app/core/input_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/contacts_picker.dart';
import '../../core/bill_store.dart';
import '../../core/groups_store.dart';
import '../tools/contact_picker_sheet.dart';
import '../../core/profile_store.dart';
import '../../core/share_text.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Groups kept on this device: people, shared expenses, balances and who pays whom.
/// Used by the offline build, where nothing is stored on a server.
class LocalGroupsScreen extends StatefulWidget {
  const LocalGroupsScreen({super.key});

  @override
  State<LocalGroupsScreen> createState() => _LocalGroupsScreenState();
}

class _LocalGroupsScreenState extends State<LocalGroupsScreen> {
  List<LocalGroup> _groups = [];
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final groups = await GroupStore.load();
      if (mounted) setState(() {
        _groups = groups;
        _loaded = true;
      });
    } catch (e) {
      debugPrint('Group load failed: $e');
      if (mounted) setState(() {
        _error = e;
        _loaded = true;
      });
    }
  }

  Future<void> _create() async {
    final group = await FormSheet.show<LocalGroup>(context, title: 'New group', child: const _GroupForm());
    if (group == null) return;
    final updated = [..._groups, group]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() => _groups = updated);
    await GroupStore.save(updated);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _loaded && _error == null ? _create : null,
              icon: const Icon(Icons.group_add_rounded, size: 18),
              label: const Text('New group'),
            ),
          ),
        ],
      ),
      body: !_loaded
          ? const LoadingBox()
          : _error != null
              ? const EmptyState(
                  icon: Icons.groups_rounded,
                  title: 'Could not open groups',
                  message: 'The saved groups could not be read. Nothing has been changed.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  children: [
                    Text(
                      'Groups and expenses are saved on this device. Split a trip, a flat or a dinner, and see who pays whom.',
                      style: TextStyle(color: c.muted, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    if (_groups.isEmpty)
                      EmptyState(
                        icon: Icons.groups_rounded,
                        title: 'No groups yet',
                        message: 'Create a group, add the people, then record who paid for what.',
                        actionLabel: 'Create a group',
                        onAction: _create,
                      )
                    else
                      for (final g in _groups) ...[
                        _GroupTile(
                          group: g,
                          onTap: () async {
                            await context.push('/groups/${g.id}');
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

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, required this.onTap});

  final LocalGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final payments = group.settlements.length;
    return MonovaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(gradient: c.aurora, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.groups_rounded, color: c.onAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '${group.members.length} people · ${group.expenses.length} expenses · '
                  '${payments == 0 ? 'settled' : '$payments payment${payments == 1 ? '' : 's'} to settle'}',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.muted),
        ],
      ),
    );
  }
}

class _GroupForm extends StatefulWidget {
  const _GroupForm();

  @override
  State<_GroupForm> createState() => _GroupFormState();
}

class _GroupFormState extends State<_GroupForm> {
  final _name = TextEditingController();
  final _people = TextEditingController();
  List<String> _known = [];

  /// Adds a name from an earlier group to the people list, if it is not there yet.
  void _addSuggested(String name) {
    final names = _people.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (!names.contains(name)) names.add(name);
    setState(() => _people.text = names.join(', '));
  }

  /// Adds people picked from the phone's contacts to the list, separated by commas.
  Future<void> _pickFromContacts() async {
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
      title: 'Pick people',
      child: ContactPickerSheet(contacts: contacts),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final names = _people.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    for (final p in picked) {
      if (!names.contains(p.name)) names.add(p.name);
    }
    setState(() => _people.text = names.join(', '));
  }

  @override
  void initState() {
    super.initState();
    // Names used in earlier groups can be tapped instead of typed.
    GroupStore.load().then((groups) {
      final names = <String>{for (final g in groups) for (final m in g.members) m.name}.toList()..sort();
      if (mounted) setState(() => _known = names);
    });
    // You are added first, so the group always includes you.
    loadProfile().then((p) {
      if (p != null && mounted && _people.text.trim().isEmpty) _people.text = p.name;
    });
  }
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _people.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final names = _people.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();
    if (name.isEmpty) {
      setState(() => _error = 'Give the group a name, for example "Goa trip" or "Flat 4B".');
      return;
    }
    if (names.length < 2) {
      setState(() => _error = 'Add at least two people, separated by commas.');
      return;
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final members = [for (var i = 0; i < names.length; i++) GroupMember(id: '${stamp}_$i', name: names[i])];
    Navigator.of(context).pop(LocalGroup(id: '$stamp', name: name, members: members, expenses: const []));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(textInputAction: TextInputAction.next, 
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Group name', hintText: 'Goa trip, Flat 4B'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _pickFromContacts, icon: const Icon(Icons.contacts_rounded, size: 18), label: const Text('Pick people from contacts')),
        const SizedBox(height: 8),
        if (_known.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in _known) ActionChip(label: Text(n), avatar: const Icon(Icons.person_outline_rounded, size: 16), onPressed: () => _addSuggested(n)),
            ],
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _people,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'People',
            hintText: 'Asha, Ravi, Meena',
            helperText: 'Separate names with commas. You can record expenses for them right away.',
            alignLabelWithHint: true,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: const Text('Create group')),
      ],
    );
  }
}

class LocalGroupDetailScreen extends StatefulWidget {
  const LocalGroupDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<LocalGroupDetailScreen> createState() => _LocalGroupDetailScreenState();
}

class _LocalGroupDetailScreenState extends State<LocalGroupDetailScreen> {
  LocalGroup? _group;
  /// Split bills that belong to this group.
  List<SavedBill> _bills = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    GroupStore.load().then((groups) {
      if (!mounted) return;
      setState(() {
        final matches = groups.where((g) => g.id == widget.id).toList();
        _group = matches.isEmpty ? null : matches.first;
        BillStore.load().then((all) {
          if (mounted) setState(() => _bills = all.where((b) => b.groupId == widget.id).toList());
        });
        _loaded = true;
      });
    });
  }

  Future<void> _saveGroup(LocalGroup updated) async {
    setState(() => _group = updated);
    final all = await GroupStore.load();
    await GroupStore.save([for (final g in all) g.id == updated.id ? updated : g]);
  }

  Future<void> _addExpense() async {
    final group = _group;
    if (group == null) return;
    final expense = await FormSheet.show<GroupExpense>(
      context,
      title: 'Add an expense',
      child: _ExpenseForm(members: group.members),
    );
    if (expense == null) return;
    await _saveGroup(group.copyWith(expenses: [expense, ...group.expenses]));
  }

  Future<void> _deleteExpense(GroupExpense e) async {
    final group = _group;
    if (group == null) return;
    await _saveGroup(group.copyWith(expenses: group.expenses.where((x) => x.id != e.id).toList()));
  }

  Future<void> _editExpense(GroupExpense e) async {
    final group = _group;
    if (group == null) return;
    final updated = await FormSheet.show<GroupExpense>(
      context,
      title: 'Edit expense',
      child: _ExpenseForm(members: group.members, initial: e),
    );
    if (updated == null) return;
    await _saveGroup(group.copyWith(expenses: [for (final x in group.expenses) x.id == e.id ? updated : x]));
  }

  /// Records that [from] has paid [to] the amount shown, which moves the balances towards zero.
  Future<void> _recordSettlement(({String from, String to, int cents}) s) async {
    final group = _group;
    if (group == null) return;
    final payment = GroupPayment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      from: s.from,
      to: s.to,
      cents: s.cents,
      createdAt: DateTime.now(),
    );
    await _saveGroup(group.copyWith(payments: [...group.payments, payment]));
  }

  /// Records every payment still needed, so the group is fully settled.
  Future<void> _settleAll() async {
    final group = _group;
    if (group == null || group.settlements.isEmpty) return;
    final now = DateTime.now().microsecondsSinceEpoch;
    final added = [
      for (var i = 0; i < group.settlements.length; i++)
        GroupPayment(
          id: '${now}_$i',
          from: group.settlements[i].from,
          to: group.settlements[i].to,
          cents: group.settlements[i].cents,
          createdAt: DateTime.now(),
        ),
    ];
    await _saveGroup(group.copyWith(payments: [...group.payments, ...added]));
  }

  Future<void> _shareGroup() async {
    final group = _group;
    if (group == null) return;
    final total = group.expenses.fold<int>(0, (sum, e) => sum + e.cents);
    final lines = <String>[
      group.name,
      'Total spent: ${money(total / 100)}',
      for (final m in group.members) '${m.name}: ${_balanceText(group.netByMember[m.id] ?? 0)}',
      group.settlements.isEmpty ? 'Everyone is settled.' : 'Who pays whom:',
      for (final s in group.settlements) '${group.nameOf(s.from)} pays ${group.nameOf(s.to)} ${money(s.cents / 100)}',
    ];
    await shareText(lines.join('\n'), subject: group.name);
  }
  /// Adds one person to the group. Existing expenses keep their shares; the new person starts with a clean balance.
  Future<void> _addMember() async {
    final group = _group;
    if (group == null) return;
    final name = await FormSheet.show<String>(context, title: 'Add a person', child: const _PersonNameForm());
    if (name == null || name.isEmpty) return;
    final id = '${DateTime.now().microsecondsSinceEpoch}_m';
    await _saveGroup(group.copyWith(members: [...group.members, GroupMember(id: id, name: name)]));
  }

  Future<void> _deleteGroup() async {
    final group = _group;
    if (group == null) return;
    final unsettled = group.settlements.isNotEmpty;
    // 'settle' records every payment first, then deletes; 'delete' deletes as it is.
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this group?'),
        content: Text(
          unsettled
              ? '"${group.name}" still has ${group.settlements.length} payment${group.settlements.length == 1 ? '' : 's'} to settle. '
                  'Settle everything now and delete the group? Its expenses and payment history will be removed from this device.'
              : '"${group.name}", its expenses and its payment history will be removed from this device. Everyone is settled.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.monova.expense),
            onPressed: () => Navigator.pop(ctx, unsettled ? 'settle' : 'delete'),
            child: Text(unsettled ? 'Settle and delete' : 'Delete'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    if (choice == 'settle') {
      await _settleAll();
    }
    final ok = true;
    final all = await GroupStore.load();
    await GroupStore.save(all.where((g) => g.id != group.id).toList());
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final group = _group;
    return Scaffold(
      appBar: AppBar(
        title: Text(group?.name ?? 'Group'),
        actions: [
          if (group != null)
            IconButton(tooltip: 'Share balances', icon: const Icon(Icons.share_rounded), onPressed: _shareGroup),
            IconButton(tooltip: 'Delete group', icon: Icon(Icons.delete_outline_rounded, color: c.expense), onPressed: _deleteGroup),
        ],
      ),
      floatingActionButton: group == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addExpense,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add expense'),
            ),
      body: !_loaded
          ? const LoadingBox()
          : group == null
              ? const EmptyState(icon: Icons.groups_rounded, title: 'Group not found', message: 'It may have been deleted.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    MonovaCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Balances', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            'Total spent: ${money((group.expenses.fold<int>(0, (sum, e) => sum + e.cents) + _bills.fold<int>(0, (sum, b) => sum + b.totalCents)) / 100)}',
                            style: TextStyle(color: c.ink, fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(height: 10),
                          if (group.expenses.isEmpty)
                            Text('Add an expense to see who is owed and who owes.', style: TextStyle(color: c.muted)),
                          for (final m in group.members)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  Expanded(child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  Text(
                                    _balanceText(group.netByMember[m.id] ?? 0),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: (group.netByMember[m.id] ?? 0) >= 0 ? c.income : c.expense,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _addMember,
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                              label: const Text('Add a person'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    MonovaCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Who pays whom', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          if (group.settlements.isEmpty)
                            Text(group.expenses.isEmpty ? 'Nothing to settle yet.' : 'Everyone is settled.', style: TextStyle(color: c.muted))
                          else ...[
                            for (final s in group.settlements)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Expanded(child: Text('${group.nameOf(s.from)} pays ${group.nameOf(s.to)} ${money(s.cents / 100)}')),
                                    TextButton(onPressed: () => _recordSettlement(s), child: const Text('Mark paid')),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 6),
                            FilledButton.icon(
                              onPressed: _settleAll,
                              icon: const Icon(Icons.done_all_rounded, size: 18),
                              label: const Text('Settle everything'),
                            ),
                          ],
                          if (group.payments.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text('Payments recorded', style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                            for (final p in group.payments)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Text(
                                  '${dayShort(p.createdAt)} · ${group.nameOf(p.from)} paid ${group.nameOf(p.to)} ${money(p.cents / 100)}',
                                  style: TextStyle(color: c.muted, fontSize: 12),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Split bills in this group', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (_bills.isEmpty)
                      Text('Save a split bill and choose this group to see it here.', style: TextStyle(color: c.muted))
                    else
                      for (final b in _bills) ...[
                        MonovaCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.title.isEmpty ? 'Split bill' : b.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text('Paid by ${b.payer} · ${b.people.length} people', style: TextStyle(color: c.muted, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Text(money(b.totalCents / 100), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    const SizedBox(height: 16),
                    Text('Expenses', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (group.expenses.isEmpty)
                      Text('No expenses yet.', style: TextStyle(color: c.muted))
                    else
                      for (final e in group.expenses) ...[
                        MonovaCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${money(e.cents / 100)} paid by ${group.nameOf(e.paidBy)} · split ${e.shares.length} ways',
                                      style: TextStyle(color: c.muted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit expense',
                                icon: Icon(Icons.edit_outlined, color: c.accentStart),
                                onPressed: () => _editExpense(e),
                              ),
                              IconButton(
                                tooltip: 'Delete expense',
                                icon: Icon(Icons.delete_outline_rounded, color: c.expense),
                                onPressed: () => _deleteExpense(e),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _deleteGroup,
                      icon: Icon(Icons.delete_outline_rounded, color: c.expense),
                      label: Text('Delete this group', style: TextStyle(color: c.expense)),
                    ),
                  ],
                ),
    );
  }

  String _balanceText(int cents) {
    if (cents == 0) return 'settled';
    return cents > 0 ? 'is owed ${money(cents / 100)}' : 'owes ${money(-cents / 100)}';
  }
}

/// Asks for one person's name.
class _PersonNameForm extends StatefulWidget {
  const _PersonNameForm();

  @override
  State<_PersonNameForm> createState() => _PersonNameFormState();
}

class _PersonNameFormState extends State<_PersonNameForm> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(textInputAction: TextInputAction.next, 
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (_) => Navigator.of(context).pop(_name.text.trim()),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_name.text.trim()),
          child: const Text('Add to the group'),
        ),
      ],
    );
  }
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({required this.members, this.initial});

  final List<GroupMember> members;

  /// The expense being edited, if any. Its id and date are kept.
  final GroupExpense? initial;

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _amount = TextEditingController(
    text: widget.initial == null ? '' : (widget.initial!.cents / 100).toStringAsFixed(2),
  );
  late String _paidBy = widget.initial?.paidBy ?? widget.members.first.id;
  late final Set<String> _among = widget.initial == null
      ? {for (final m in widget.members) m.id}
      : {for (final m in widget.members) if (widget.initial!.shares.containsKey(m.id)) m.id};
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (title.isEmpty) {
      setState(() => _error = 'Describe the expense, for example "Dinner" or "Petrol".');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    if (_among.isEmpty) {
      setState(() => _error = 'Tick at least one person to share it with.');
      return;
    }
    final cents = (amount * 100).round();
    final ids = [for (final m in widget.members) if (_among.contains(m.id)) m.id];
    Navigator.of(context).pop(GroupExpense(
      id: widget.initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      cents: cents,
      paidBy: _paidBy,
      shares: equalShares(cents, ids),
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(textInputAction: TextInputAction.next, 
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'What was it for?'),
        ),
        const SizedBox(height: 12),
        TextField(textInputAction: TextInputAction.next, 
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: amountFormatters,
          decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _paidBy,
          decoration: const InputDecoration(labelText: 'Who paid?'),
          menuMaxHeight: 260,
          items: [for (final m in widget.members) DropdownMenuItem(value: m.id, child: Text(m.name))],
          onChanged: (v) => setState(() => _paidBy = v ?? _paidBy),
        ),
        const SizedBox(height: 8),
        Text('Shared with', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
        for (final m in widget.members)
          CheckboxListTile(
            value: _among.contains(m.id),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(m.name),
            onChanged: (v) => setState(() => v == true ? _among.add(m.id) : _among.remove(m.id)),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: const Text('Save expense')),
        const SizedBox(height: 6),
        Text('Each person shares the cost equally. Change the people ticked to leave someone out.',
            textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12)),
      ],
    );
  }
}
