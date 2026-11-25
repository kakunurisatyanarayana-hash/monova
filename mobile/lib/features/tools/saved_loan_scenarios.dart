import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/local_store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

const loanScenariosKey = 'monova.loanScenarios';

/// Lists and saves loan scenarios on this device. Tapping a scenario reloads its inputs into the calculator.
class SavedLoanScenarios extends StatefulWidget {
  const SavedLoanScenarios({super.key, required this.snapshot, required this.onLoad});

  /// Returns the calculator's current inputs as a map.
  final Map<String, dynamic> Function() snapshot;

  /// Puts a saved scenario's inputs back into the calculator.
  final void Function(Map<String, dynamic> scenario) onLoad;

  @override
  State<SavedLoanScenarios> createState() => _SavedLoanScenariosState();
}

class _SavedLoanScenariosState extends State<SavedLoanScenarios> {
  LocalStore? _store;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    LocalStore.open().then((store) {
      if (!mounted) return;
      setState(() {
        _store = store;
        _items = store.readList(loanScenariosKey);
      });
    });
  }

  Future<void> _save() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Save this scenario'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name (for example, "Flat in Pune")'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || _store == null) return;

    final entry = <String, dynamic>{
      ...widget.snapshot(),
      'name': name,
      'savedAt': DateTime.now().toIso8601String(),
    };
    setState(() => _items = [entry, ..._items]);
    await _store!.writeList(loanScenariosKey, _items);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scenario saved on this device')));
  }

  Future<void> _delete(int index) async {
    setState(() => _items.removeAt(index));
    await _store?.writeList(loanScenariosKey, _items);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Saved scenarios', style: Theme.of(context).textTheme.titleMedium)),
            TextButton.icon(
              onPressed: _store == null ? null : _save,
              icon: const Icon(Icons.bookmark_add_rounded),
              label: const Text('Save current'),
            ),
          ],
        ),
        if (_items.isEmpty)
          Text('Nothing saved yet. Calculate a loan, then tap "Save current".', style: TextStyle(color: c.muted, fontSize: 12))
        else
          MonovaCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < _items.length; i++)
                  ListTile(
                    onTap: () => widget.onLoad(_items[i]),
                    title: Text('${_items[i]['name'] ?? 'Scenario'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      'Loan ${money(double.tryParse('${_items[i]['amount']}'.replaceAll(',', '')) ?? 0)} · ${_items[i]['rate']}% · ${_items[i]['tenure']} months',
                      style: TextStyle(color: c.muted, fontSize: 12),
                    ),
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: Icon(Icons.delete_outline_rounded, color: c.expense),
                      onPressed: () => _delete(i),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
