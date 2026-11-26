import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

final recurringProvider = FutureProvider.autoDispose<List<RecurringItem>>((ref) => ref.watch(repositoryProvider).recurring());

/// Repeating entries such as rent, subscriptions or salary. Turn them on or off, add new ones, or create the due entries now.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recurringProvider);
    final c = context.monova;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring'),
        actions: [
          TextButton(
            onPressed: () async {
              final count = await ref.read(repositoryProvider).runDueRecurring();
              ref.invalidate(recurringProvider);
              ref.invalidate(dashboardProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(count == 0 ? 'Nothing is due right now' : '$count entries created'),
                ));
              }
            },
            child: Text('Run due', style: TextStyle(color: c.accentStart, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accentStart,
        foregroundColor: c.onAccent,
        onPressed: () => FormSheet.show<void>(context, title: 'New recurring entry', child: const _RecurringForm()),
        icon: const Icon(Icons.repeat_rounded),
        label: const Text('Add'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(recurringProvider.future),
        child: items.when(
          loading: () => const LoadingBox(),
          error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(recurringProvider)),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (list.isEmpty)
                const EmptyState(
                  icon: Icons.repeat_rounded,
                  title: 'No repeating entries',
                  message: 'Add rent, subscriptions or a monthly salary once, and MONOVA will record them when they fall due.',
                ),
              for (final r in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MonovaCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: c.border,
                          child: Icon(r.type == 'Income' ? Icons.south_west_rounded : Icons.north_east_rounded,
                              color: r.type == 'Income' ? c.income : c.warning, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                '${r.frequency} · next ${dayLabel(r.nextRunOn)}',
                                style: TextStyle(color: c.muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        AmountText(money(r.amount), size: 14),
                        Switch(
                          value: r.isActive,
                          onChanged: (v) async {
                            await ref.read(repositoryProvider).setRecurringActive(r.id, active: v);
                            ref.invalidate(recurringProvider);
                          },
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

class _RecurringForm extends ConsumerStatefulWidget {
  const _RecurringForm();

  @override
  ConsumerState<_RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends ConsumerState<_RecurringForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  String _type = 'Expense';
  String _frequency = 'Monthly';
  String? _accountId;
  DateTime _startOn = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _accountId == null) return;
    setState(() => _saving = true);
    final ok = await runAction(context, () async {
      await ref.read(repositoryProvider).addRecurring(
            type: _type,
            amount: parseAmount(_amount.text)!,
            title: _title.text.trim(),
            frequency: _frequency,
            startOn: _startOn,
            accountId: _accountId!,
          );
      ref.invalidate(recurringProvider);
    }, success: 'Recurring entry added');
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
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'Expense', label: Text('Expense')), ButtonSegment(value: 'Income', label: Text('Income'))],
            selected: {_type},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Name (for example, Rent or Salary)'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
            validator: validateAmount,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _frequency,
            decoration: const InputDecoration(labelText: 'How often'),
            items: const [
              DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
              DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
            ],
            onChanged: (v) => setState(() => _frequency = v ?? 'Monthly'),
          ),
          const SizedBox(height: 12),
          accounts.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Could not load accounts'),
            data: (list) => DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: InputDecoration(labelText: _type == 'Income' ? 'Received into' : 'Paid from'),
              menuMaxHeight: 260,
              items: [for (final a in list.where((a) => a.isActive)) DropdownMenuItem(value: a.id, child: Text(a.name))],
              onChanged: (v) => setState(() => _accountId = v),
              validator: (v) => v == null ? 'Choose an account' : null,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startOn,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 366)),
              );
              if (picked != null) setState(() => _startOn = picked);
            },
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: Text('Starts ${dayLabel(_startOn)}'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
