import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/notify.dart';
import '../../core/reminders.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../shared/date_inputs.dart';

/// Where a reminder can take the user, shown in the form as a plain choice.
const _links = <(String, String)>[
  ('', 'No link'),
  ('/purchases', 'Purchase or warranty'),
  ('/property', 'Property rent or expenses'),
  ('/ledger', 'Credit book'),
  ('/tools/split', 'Split bill or group'),
  ('/saved-cards', 'Saved card'),
  ('/vault', 'Password or note'),
];

String _linkLabel(String route) {
  for (final l in _links) {
    if (l.$1 == route) return l.$2;
  }
  return route.isEmpty ? '' : 'Linked record';
}

String _repeatLabel(String repeat) => switch (repeat) {
      'monthly' => 'Every month',
      'yearly' => 'Every year',
      _ => 'Once',
    };

String _when(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${dayLabel(d)} · $hh:$mm';
}

/// Every reminder: what is due first, then what is coming, then what is done.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Reminder> _all = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ReminderStore.load();
    if (mounted) setState(() {
      _all = list;
      _loaded = true;
    });
  }

  /// Saves the list and updates the phone alert for [changed].
  Future<void> _store(List<Reminder> next, {Reminder? changed, bool removed = false}) async {
    setState(() => _all = next);
    await ReminderStore.save(next);
    if (changed != null && reminderAlertsSupported) {
      if (removed) {
        await cancelReminderAlert(changed);
      } else {
        await scheduleReminderAlert(changed);
      }
    }
  }

  Future<void> _add() async {
    final r = await FormSheet.show<Reminder>(context, title: 'New reminder', child: const _ReminderForm());
    if (r == null) return;
    if (reminderAlertsSupported && _all.isEmpty) {
      final granted = await requestReminderAlertPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Notifications are off. The reminder still shows here. Turn notifications on in phone settings to get alerts.'),
        ));
      }
    }
    await _store([..._all, r], changed: r);
  }

  Future<void> _edit(Reminder r) async {
    final updated = await FormSheet.show<Reminder>(context, title: 'Edit reminder', child: _ReminderForm(initial: r));
    if (updated == null) return;
    await _store([for (final x in _all) x.id == r.id ? updated : x], changed: updated);
  }

  Future<void> _markDone(Reminder r) async {
    if (r.repeats) {
      final next = r.advanced();
      await _store([for (final x in _all) x.id == r.id ? next : x], changed: next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Done. Next: ${_when(next.dueAt)}')));
      }
    } else {
      final done = r.copyWith(done: true);
      await _store([for (final x in _all) x.id == r.id ? done : x], changed: done);
    }
  }

  Future<void> _undo(Reminder r) async {
    final open = r.copyWith(done: false);
    await _store([for (final x in _all) x.id == r.id ? open : x], changed: open);
  }

  Future<void> _delete(Reminder r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this reminder?'),
        content: Text('"${r.title}" will be removed. Its alert will not ring.'),
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
    await _store([for (final x in _all) if (x.id != r.id) x], changed: r, removed: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final now = DateTime.now();
    final open = [for (final r in _all) if (!r.done) r]..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final due = [for (final r in open) if (r.isDueToday(now)) r];
    final coming = [for (final r in open) if (!r.isDueToday(now)) r];
    final done = [for (final r in _all) if (r.done) r]..sort((a, b) => b.dueAt.compareTo(a.dueAt));
    return Scaffold(
      appBar: AppBar(title: Text(tr('reminders_title'))),
      floatingActionButton: _loaded
          ? FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add_alarm_rounded), label: Text(tr('add_reminder')))
          : null,
      body: !_loaded
          ? const LoadingBox()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                if (!reminderAlertsSupported)
                  MonovaCard(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Reminders are listed here. Phone alerts work in the Android app, not in the web version.',
                      style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
                    ),
                  ),
                if (_all.isEmpty)
                  EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'No reminders yet',
                    message: 'Add a bill date, a warranty end, rent day or a renewal. It will show here and ring on your phone.',
                    actionLabel: 'Add the first reminder',
                    onAction: _add,
                  ),
                if (due.isNotEmpty) ...[
                  const SectionTitle('Due today or overdue'),
                  const SizedBox(height: 8),
                  for (final r in due) _ReminderTile(r, now: now, onDone: () => _markDone(r), onEdit: () => _edit(r), onDelete: () => _delete(r), onUndo: null),
                  const SizedBox(height: 16),
                ],
                if (coming.isNotEmpty) ...[
                  const SectionTitle('Coming up'),
                  const SizedBox(height: 8),
                  for (final r in coming) _ReminderTile(r, now: now, onDone: () => _markDone(r), onEdit: () => _edit(r), onDelete: () => _delete(r), onUndo: null),
                  const SizedBox(height: 16),
                ],
                if (done.isNotEmpty) ...[
                  const SectionTitle('Done'),
                  const SizedBox(height: 8),
                  for (final r in done) _ReminderTile(r, now: now, onDone: null, onEdit: () => _edit(r), onDelete: () => _delete(r), onUndo: () => _undo(r)),
                ],
              ],
            ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile(this.r, {required this.now, required this.onDone, required this.onEdit, required this.onDelete, required this.onUndo});

  final Reminder r;
  final DateTime now;
  final VoidCallback? onDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final overdue = r.isOverdue(now);
    final link = _linkLabel(r.route);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MonovaCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        onTap: onEdit,
        child: Row(
          children: [
            Icon(r.done ? Icons.check_circle_rounded : Icons.notifications_active_outlined, color: overdue ? c.expense : c.accentStart),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    style: TextStyle(fontWeight: FontWeight.w700, decoration: r.done ? TextDecoration.lineThrough : null),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${overdue ? 'Overdue · ' : ''}${_when(r.dueAt)} · ${_repeatLabel(r.repeat)}${link.isEmpty ? '' : ' · $link'}',
                    style: TextStyle(color: overdue ? c.expense : c.muted, fontSize: 12),
                  ),
                  if (r.notes.isNotEmpty) Text(r.notes, style: TextStyle(color: c.muted, fontSize: 12)),
                ],
              ),
            ),
            if (onDone != null)
              IconButton(
                tooltip: r.repeats ? 'Done, move to next time' : 'Mark done',
                icon: Icon(Icons.check_rounded, color: c.income),
                onPressed: onDone,
              ),
            if (onUndo != null)
              IconButton(tooltip: 'Mark not done', icon: Icon(Icons.undo_rounded, color: c.muted), onPressed: onUndo),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) {
                if (v == 'open') context.push(r.route);
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                if (r.route.isNotEmpty) const PopupMenuItem(value: 'open', child: Text('Open linked record')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Adds or edits a reminder: what, when, how often, and the record it is about.
class _ReminderForm extends StatefulWidget {
  const _ReminderForm({this.initial});

  final Reminder? initial;

  @override
  State<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<_ReminderForm> {
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');
  late DateTime _date = _dayOf(widget.initial?.dueAt ?? DateTime.now().add(const Duration(days: 1)));
  late TimeOfDay _time = TimeOfDay.fromDateTime(widget.initial?.dueAt ?? DateTime(2000, 1, 1, 9));
  late String _repeat = widget.initial?.repeat ?? 'none';
  late String _route = widget.initial?.route ?? '';
  String? _error;

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null && mounted) setState(() => _time = t);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Say what the reminder is for, for example "Electricity bill".');
      return;
    }
    final due = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final base = widget.initial;
    Navigator.of(context).pop(Reminder(
      id: base?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      notes: _notes.text.trim(),
      dueAt: due,
      repeat: _repeat,
      route: _route,
      done: false,
      createdAt: base?.createdAt ?? DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _title, autofocus: widget.initial == null, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'What is it for? *')),
        const SizedBox(height: 12),
        DateSelector(label: 'Date', value: _date, firstYear: DateTime.now().year - 1, lastYear: DateTime.now().year + 10, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickTime,
          icon: const Icon(Icons.schedule_rounded, size: 18),
          label: Text('Time: ${_time.format(context)}'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _repeat,
          decoration: const InputDecoration(labelText: 'How often'),
          items: const [
            DropdownMenuItem(value: 'none', child: Text('Once')),
            DropdownMenuItem(value: 'monthly', child: Text('Every month')),
            DropdownMenuItem(value: 'yearly', child: Text('Every year')),
          ],
          onChanged: (v) => setState(() => _repeat = v ?? _repeat),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _route,
          decoration: const InputDecoration(labelText: 'Open this record'),
          items: [for (final l in _links) DropdownMenuItem(value: l.$1, child: Text(l.$2))],
          onChanged: (v) => setState(() => _route = v ?? ''),
        ),
        const SizedBox(height: 12),
        TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Note (optional)')),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: Text(widget.initial == null ? 'Save reminder' : 'Save changes')),
      ],
    );
  }
}
