import 'package:flutter_contacts/flutter_contacts.dart';

import 'contacts_picker.dart';

/// Asks for read-only access and returns the contacts that have a name, sorted by name.
Future<List<PickedContact>> loadContacts() async {
  final granted = await FlutterContacts.requestPermission(readonly: true);
  if (!granted) {
    throw const ContactsException('Contacts access is off for MONOVA. Turn it on in phone Settings, then Apps, then MONOVA, then Permissions, then Contacts. Then try again.');
  }
  final contacts = await FlutterContacts.getContacts(withProperties: true, withPhoto: false);
  final picked = [
    for (final c in contacts)
      if ((c.displayName ?? '').trim().isNotEmpty)
        PickedContact(
          name: c.displayName!.trim(),
          phone: c.phones.isEmpty ? '' : c.phones.first.number,
        ),
  ];
  picked.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return picked;
}
