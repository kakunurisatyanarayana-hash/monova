import 'package:flutter/material.dart';

import '../../core/contacts_picker.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Lists the phone's contacts with a search box. The user ticks the people to add to the bill.
class ContactPickerSheet extends StatefulWidget {
  const ContactPickerSheet({super.key, required this.contacts, this.singleSelect = false});

  final List<PickedContact> contacts;

  /// True when only one contact can be chosen (for example, a customer). Choosing another replaces the first.
  final bool singleSelect;

  @override
  State<ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<ContactPickerSheet> {
  final _selected = <int>{};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final q = _query.trim().toLowerCase();
    final visible = [
      for (var i = 0; i < widget.contacts.length; i++)
        if (q.isEmpty || widget.contacts[i].name.toLowerCase().contains(q)) i,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(hintText: 'Search contacts', prefixIcon: Icon(Icons.search_rounded)),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: visible.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No contacts match.', style: TextStyle(color: c.muted), textAlign: TextAlign.center),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final i in visible)
                      CheckboxListTile(
                        value: _selected.contains(i),
                        onChanged: (v) => setState(() {
                          if (widget.singleSelect) _selected.clear();
                          if (v == true) {
                            _selected.add(i);
                          } else {
                            _selected.remove(i);
                          }
                        }),
                        title: Text(widget.contacts[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: widget.contacts[i].phone.isEmpty
                            ? null
                            : Text(widget.contacts[i].phone, style: TextStyle(color: c.muted, fontSize: 12)),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop([for (final i in _selected) widget.contacts[i]]),
          child: Text(widget.singleSelect ? (_selected.isEmpty ? 'Pick a contact' : 'Use this contact') : (_selected.isEmpty ? 'Tick people to add' : 'Add ${_selected.length} to the bill')),
        ),
      ],
    );
  }
}
