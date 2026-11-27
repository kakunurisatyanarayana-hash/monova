import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/sip.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../shared/date_inputs.dart';

String _id() => DateTime.now().microsecondsSinceEpoch.toString();

/// SIPs and monthly savings: what is due this month, what is still unpaid, and what has been invested.
class SipScreen extends StatefulWidget {
  const SipScreen({super.key});

  @override
  State<SipScreen> createState() => _SipScreenState();
}

class _SipScreenState extends State<SipScreen> {
  List<SipPlan> _plans = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plans = await SipStore.load();
    if (mounted) setState(() {
      _plans = plans;
      _loaded = true;
    });
  }

  Future<void> _store(List<SipPlan> next) async {
    setState(() => _plans = next);
    await SipStore.save(next);
  }

  Future<void> _edit([SipPlan? existing]) async {
    final result = await FormSheet.show<SipPlan>(
      context,
      title: existing == null ? 'New SIP or monthly saving' : 'Edit SIP',
      child: _SipForm(initial: existing),
    );
    if (result == null) return;
    await _store(existing == null ? [..._plans, result] : [for (final p in _plans) p.id == existing.id ? result : p]);
  }

  Future<void> _togglePaid(SipPlan p, String month, bool paid) async {
    final months = paid ? [...p.paidMonths, month] : [for (final m in p.paidMonths) if (m != month) m];
    await _store([for (final x in _plans) x.id == p.id ? x.copyWith(paidMonths: months) : x]);
  }

  Future<void> _updateValue(SipPlan p) async {
    final cents = await FormSheet.show<int>(context, title: 'Current value of ${p.name}', child: const _ValueForm());
    if (cents == null) return;
    await _store([for (final x in _plans) x.id == p.id ? x.copyWith(currentValueCents: cents) : x]);
  }

  Future<void> _delete(SipPlan p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${p.name}?'),
        content: const Text('The plan, its paid months, its monthly reminder and its entries in Monova Finance are removed.'),
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
    await _store([for (final x in _plans) if (x.id != p.id) x]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final now = DateTime.now();
    final pending = _plans.fold<int>(0, (s, p) => s + pendingCents(p, now));
    final invested = _plans.fold<int>(0, (s, p) => s + p.investedCents);
    final value = _plans.fold<int>(0, (s, p) => s + (p.currentValueCents ?? 0));
    final dueThisMonth = _plans.fold<int>(0, (s, p) => s + (sipStateFor(p, now) == SipState.paid ? 0 : p.monthlyCents));
    return Scaffold(
      appBar: AppBar(title: const Text('SIP and monthly savings')),
      floatingActionButton: _loaded
          ? FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), label: const Text('Add SIP'))
          : null,
      body: !_loaded
          ? const LoadingBox()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                MonovaCard(
                  gradient: c.hero,
                  padding: const EdgeInsets.all(18),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 12,
                    children: [
                      _Figure(label: 'Due this month', value: money(dueThisMonth / 100)),
                      _Figure(label: 'Unpaid so far', value: money(pending / 100)),
                      _Figure(label: 'Total invested', value: money(invested / 100)),
                      _Figure(label: 'Value you noted', value: value == 0 ? '—' : money(value / 100)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_plans.isEmpty)
                  EmptyState(
                    icon: Icons.trending_up_rounded,
                    title: 'No SIP yet',
                    message: 'Add a monthly investment or savings plan. Each month it shows as due, with a reminder on its day.',
                    actionLabel: 'Add the first SIP',
                    onAction: () => _edit(),
                  ),
                for (final p in _plans) ...[
                  _PlanCard(
                    plan: p,
                    now: now,
                    onPaid: (m, v) => _togglePaid(p, m, v),
                    onEdit: () => _edit(p),
                    onValue: () => _updateValue(p),
                    onDelete: () => _delete(p),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.now, required this.onPaid, required this.onEdit, required this.onValue, required this.onDelete});

  final SipPlan plan;
  final DateTime now;
  final void Function(String month, bool paid) onPaid;
  final VoidCallback onEdit;
  final VoidCallback onValue;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final state = sipStateFor(plan, now);
    final key = monthKeyOf(now);
    final missed = missedMonths(plan, now);
    final due = dueDateFor(plan, now.year, now.month);
    final (label, color) = switch (state) {
      SipState.paid => ('Paid this month', c.income),
      SipState.pending => ('Due today, not paid', c.expense),
      SipState.overdue => ('Overdue', c.expense),
      SipState.notYet => ('Due on ${dayLabel(due)}', c.muted),
    };
    return MonovaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              IconButton(tooltip: 'Edit', icon: Icon(Icons.edit_outlined, color: c.accentStart), onPressed: onEdit),
              IconButton(tooltip: 'Delete', icon: Icon(Icons.delete_outline_rounded, color: c.muted), onPressed: onDelete),
            ],
          ),
          Text('${money(plan.monthlyCents / 100)} every month, on day ${plan.dayOfMonth}', style: TextStyle(color: c.muted, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
              if (state != SipState.notYet)
                FilledButton.tonal(
                  onPressed: () => onPaid(key, state != SipState.paid),
                  child: Text(state == SipState.paid ? 'Undo' : 'Mark paid'),
                ),
            ],
          ),
          if (missed.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Unpaid from earlier: ${missed.join(', ')} · ${money((missed.length * plan.monthlyCents) / 100)} to catch up',
              style: TextStyle(color: c.expense, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in missed)
                  OutlinedButton(onPressed: () => onPaid(m, true), child: Text('Paid $m')),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Invested ${money(plan.investedCents / 100)} in ${plan.paidMonths.length} month${plan.paidMonths.length == 1 ? '' : 's'}'
                  '${plan.currentValueCents == null ? '' : ' · value ${money(plan.currentValueCents! / 100)}'}',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ),
              TextButton(onPressed: onValue, child: const Text('Note value')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SipForm extends StatefulWidget {
  const _SipForm({this.initial});

  final SipPlan? initial;

  @override
  State<_SipForm> createState() => _SipFormState();
}

class _SipFormState extends State<_SipForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _amount = TextEditingController(
    text: widget.initial == null ? '' : (widget.initial!.monthlyCents / 100).toStringAsFixed(0),
  );
  late int _day = widget.initial?.dayOfMonth ?? DateTime.now().day.clamp(1, 28);
  late DateTime _start = widget.initial?.startDate ?? DateTime.now();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final rupees = double.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0;
    if (name.isEmpty) {
      setState(() => _error = 'Name the plan, for example "Index fund SIP".');
      return;
    }
    if (rupees <= 0) {
      setState(() => _error = 'Enter the amount paid each month.');
      return;
    }
    final base = widget.initial;
    Navigator.of(context).pop(SipPlan(
      id: base?.id ?? _id(),
      name: name,
      monthlyCents: (rupees * 100).round(),
      dayOfMonth: _day,
      startDate: DateTime(_start.year, _start.month, _start.day),
      paidMonths: base?.paidMonths ?? const [],
      currentValueCents: base?.currentValueCents,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _name, autofocus: widget.initial == null, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Name *')),
        const SizedBox(height: 12),
        TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount each month *', prefixText: '₹ ')),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _day,
          decoration: const InputDecoration(labelText: 'Due on day of the month'),
          items: [for (var d = 1; d <= 28; d++) DropdownMenuItem(value: d, child: Text('$d'))],
          onChanged: (v) => setState(() => _day = v ?? _day),
        ),
        const SizedBox(height: 12),
        DateSelector(label: 'Started on', value: _start, firstYear: DateTime.now().year - 30, lastYear: DateTime.now().year, onChanged: (d) => setState(() => _start = d)),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: Text(widget.initial == null ? 'Save SIP' : 'Save changes')),
      ],
    );
  }
}

class _ValueForm extends StatefulWidget {
  const _ValueForm();

  @override
  State<_ValueForm> createState() => _ValueFormState();
}

class _ValueFormState extends State<_ValueForm> {
  final _value = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _save() {
    final rupees = double.tryParse(_value.text.replaceAll(',', '').trim());
    if (rupees == null || rupees < 0) {
      setState(() => _error = 'Enter the value shown by your fund or bank.');
      return;
    }
    Navigator.of(context).pop((rupees * 100).round());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _value, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Current value', prefixText: '₹ ')),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Type the value your fund app or bank shows. MONOVA does not fetch market prices.', style: TextStyle(color: c.muted, fontSize: 12)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: const Text('Save value')),
      ],
    );
  }
}
