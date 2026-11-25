import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/vault_store.dart';
import '../../core/widgets.dart';

/// Passwords and notes kept on this device. Works without an account, like the calculators.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  List<VaultEntry> _entries = [];
  bool _loaded = false;
  String _query = '';
  VaultKind? _filter;

  Object? _loadError;

  @override
  void initState() {
    super.initState();
    VaultStore.load().then((items) {
      if (!mounted) return;
      setState(() {
        _entries = items;
        _loaded = true;
      });
    }).catchError((Object e) {
      debugPrint('Vault load failed: $e');
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loaded = true;
      });
    });
  }

  List<VaultEntry> get _shown => _entries
      .where((e) => (_filter == null || e.kind == _filter) && e.matches(_query))
      .toList();

  Future<void> _persist() => VaultStore.save(_entries);

  Future<void> _add() async {
    final created = await FormSheet.show<VaultEntry>(
      context,
      title: 'New entry',
      child: const _EntryEditor(),
    );
    if (created == null) return;
    setState(() {
      _entries = [created, ..._entries];
      _entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
    await _persist();
  }

  Future<void> _edit(VaultEntry entry) async {
    final updated = await FormSheet.show<VaultEntry>(
      context,
      title: 'Edit entry',
      child: _EntryEditor(initial: entry),
    );
    if (updated == null) return;
    setState(() {
      _entries = [for (final e in _entries) e.id == entry.id ? updated : e];
      _entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
    await _persist();
  }

  Future<void> _delete(VaultEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text('"${entry.title}" will be removed from this device. This cannot be undone.'),
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
    setState(() => _entries = _entries.where((e) => e.id != entry.id).toList());
    await _persist();
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what copied')));
  }

  void _openDetail(VaultEntry entry) {
    FormSheet.show<void>(
      context,
      title: entry.title,
      child: _EntryDetail(
        entry: entry,
        onCopy: _copy,
        onEdit: () => _edit(entry),
        onDelete: () => _delete(entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final shown = _shown;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Passwords and notes'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New entry'),
            ),
          ),
        ],
      ),
      body: !_loaded
          ? const LoadingBox()
          : _loadError != null
              ? EmptyState(
                  icon: Icons.lock_reset_rounded,
                  title: 'Could not open the vault',
                  message: 'This device did not return the saved entries. Your data has not been changed. Close and open the page again.',
                )
              : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                _StorageNotice(encrypted: VaultStore.encrypted),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search by title, username, website or note',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    _FilterChipTile(label: 'All', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                    _FilterChipTile(
                      label: 'Passwords',
                      selected: _filter == VaultKind.password,
                      onTap: () => setState(() => _filter = VaultKind.password),
                    ),
                    _FilterChipTile(
                      label: 'Notes',
                      selected: _filter == VaultKind.note,
                      onTap: () => setState(() => _filter = VaultKind.note),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_entries.isEmpty)
                  EmptyState(
                    icon: Icons.lock_rounded,
                    title: 'Nothing saved yet',
                    message: 'Keep passwords, PINs, account numbers or any note you do not want to lose. Everything stays on this device.',
                    actionLabel: 'Add the first entry',
                    onAction: _add,
                  )
                else if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No entries match your search.', style: TextStyle(color: c.muted))),
                  )
                else
                  for (final entry in shown) ...[
                    _EntryTile(
                      entry: entry,
                      onTap: () => _openDetail(entry),
                      onCopy: entry.kind == VaultKind.password && entry.password.isNotEmpty
                          ? () => _copy(entry.password, 'Password')
                          : null,
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
    );
  }
}

class _StorageNotice extends StatelessWidget {
  const _StorageNotice({required this.encrypted});

  final bool encrypted;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final color = encrypted ? c.income : c.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(encrypted ? Icons.verified_user_rounded : Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              encrypted
                  ? 'Stored in this phone\'s secure storage (Keystore or Keychain). Nothing is sent to a server.'
                  : 'This browser keeps entries in plain browser storage, which is not encrypted. Use the phone app to store real passwords.',
              style: TextStyle(color: c.ink, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipTile extends StatelessWidget {
  const _FilterChipTile({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: c.accentStart.withValues(alpha: 0.18),
      labelStyle: TextStyle(color: selected ? c.accentStart : c.ink, fontWeight: FontWeight.w600),
      side: BorderSide(color: selected ? c.accentStart : c.border),
      shape: const StadiumBorder(),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onTap, this.onCopy});

  final VaultEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final isPassword = entry.kind == VaultKind.password;
    return MonovaCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(gradient: c.aurora, borderRadius: BorderRadius.circular(14)),
            child: Icon(isPassword ? Icons.key_rounded : Icons.sticky_note_2_rounded, color: c.onAccent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 3),
                Text(entry.preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: c.border.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(99)),
            child: Text(entry.kind.label, style: TextStyle(color: c.muted, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          if (onCopy != null)
            IconButton(
              tooltip: 'Copy password',
              icon: Icon(Icons.copy_rounded, color: c.accentStart),
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }
}

class _EntryDetail extends StatefulWidget {
  const _EntryDetail({required this.entry, required this.onCopy, required this.onEdit, required this.onDelete});

  final VaultEntry entry;
  final Future<void> Function(String text, String what) onCopy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_EntryDetail> createState() => _EntryDetailState();
}

class _EntryDetailState extends State<_EntryDetail> {
  bool _reveal = false;

  /// Closes this sheet first, then runs the action on the screen behind it.
  void _closeThen(VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final e = widget.entry;
    final isPassword = e.kind == VaultKind.password;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isPassword && e.username.isNotEmpty)
          _DetailRow(label: 'Username', value: e.username, onCopy: () => widget.onCopy(e.username, 'Username')),
        if (isPassword && e.password.isNotEmpty)
          _DetailRow(
            label: 'Password',
            value: _reveal ? e.password : '•' * 10,
            onCopy: () => widget.onCopy(e.password, 'Password'),
            trailing: IconButton(
              tooltip: _reveal ? 'Hide' : 'Show',
              icon: Icon(_reveal ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: c.muted),
              onPressed: () => setState(() => _reveal = !_reveal),
            ),
          ),
        if (isPassword && e.url.isNotEmpty)
          _DetailRow(label: 'Website', value: e.url, onCopy: () => widget.onCopy(e.url, 'Website')),
        if (e.notes.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.base,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: SelectableText(e.notes, style: TextStyle(color: c.ink, height: 1.45)),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _closeThen(widget.onDelete),
                icon: Icon(Icons.delete_outline_rounded, color: c.expense),
                label: Text('Delete', style: TextStyle(color: c.expense)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _closeThen(widget.onEdit),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, required this.onCopy, this.trailing});

  final String label;
  final String value;
  final VoidCallback onCopy;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: c.base,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                SelectableText(value, style: TextStyle(color: c.ink, fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          ?trailing,
          IconButton(tooltip: 'Copy', icon: Icon(Icons.copy_rounded, color: c.accentStart), onPressed: onCopy),
        ],
      ),
    );
  }
}

/// Add or edit form. Passwords get username, password (hidden by default) and website. Notes get only the text.
class _EntryEditor extends StatefulWidget {
  const _EntryEditor({this.initial});

  final VaultEntry? initial;

  @override
  State<_EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<_EntryEditor> {
  late VaultKind _kind = widget.initial?.kind ?? VaultKind.password;
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _username = TextEditingController(text: widget.initial?.username ?? '');
  late final _password = TextEditingController(text: widget.initial?.password ?? '');
  late final _url = TextEditingController(text: widget.initial?.url ?? '');
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');
  bool _obscure = true;
  String? _titleError;

  @override
  void dispose() {
    _title.dispose();
    _username.dispose();
    _password.dispose();
    _url.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Give this entry a name, for example "Bank login" or "Wi-Fi at home".');
      return;
    }
    final now = DateTime.now();
    final initial = widget.initial;
    final entry = VaultEntry(
      id: initial?.id ?? now.microsecondsSinceEpoch.toString(),
      kind: _kind,
      title: title,
      username: _kind == VaultKind.password ? _username.text.trim() : '',
      password: _kind == VaultKind.password ? _password.text : '',
      url: _kind == VaultKind.password ? _url.text.trim() : '',
      notes: _notes.text.trimRight(),
      updatedAt: now,
    );
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final isPassword = _kind == VaultKind.password;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<VaultKind>(
          segments: const [
            ButtonSegment(value: VaultKind.password, label: Text('Password'), icon: Icon(Icons.key_rounded)),
            ButtonSegment(value: VaultKind.note, label: Text('Note'), icon: Icon(Icons.sticky_note_2_rounded)),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() => _kind = s.first),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _title,
          autofocus: widget.initial == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Name',
            hintText: isPassword ? 'Bank login, Email, Wi-Fi' : 'Locker number, PIN reminder, Gift ideas',
            errorText: _titleError,
          ),
          onChanged: (_) {
            if (_titleError != null) setState(() => _titleError = null);
          },
        ),
        if (isPassword) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Username or email', prefixIcon: Icon(Icons.person_outline_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show' : 'Hide',
                icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Website (optional)', prefixIcon: Icon(Icons.language_rounded)),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: isPassword ? 'Extra details (optional)' : 'Note',
            alignLabelWithHint: true,
            hintText: isPassword ? 'Security questions, recovery codes, anything else' : 'Write anything you want to remember',
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: Text(widget.initial == null ? 'Save entry' : 'Save changes')),
        const SizedBox(height: 8),
        Text(
          'Stored on this device only.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 12),
        ),
      ],
    );
  }
}
