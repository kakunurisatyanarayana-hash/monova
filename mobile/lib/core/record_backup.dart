import 'bill_store.dart';
import 'credit_ledger.dart';
import 'entry_store.dart';
import 'groups_store.dart';
import 'local_store.dart';
import 'property_store.dart';
import 'qr_store.dart';
import 'reminders.dart';

/// Every record kept in plain local storage that a backup must include: finance, purchases, groups, split bills,
/// the credit book, the property module, payments and reminders. Passwords and cards are backed up separately.
const recordKeys = <String>[
  entriesKey,
  purchasesKey,
  groupsKey,
  billsKey,
  ledgerKey,
  propertiesKey,
  roomsKey,
  tenanciesKey,
  personsKey,
  paymentsKey,
  remindersKey,
  invitationsKey,
  guestsKey,
];

/// A record's identity: its id when it has one, otherwise its full content.
String recordIdentity(Map<String, dynamic> r) => r['id'] != null ? '${r['id']}' : r.toString();

/// Reads every record list from this device, keyed by storage key.
Future<Map<String, List<Map<String, dynamic>>>> readRecords() async {
  final store = await LocalStore.open();
  return {for (final key in recordKeys) key: store.readList(key)};
}

/// Writes record lists back to this device, keyed by storage key. Keys not in [recordKeys] are ignored.
Future<void> writeRecords(Map<String, List<Map<String, dynamic>>> records) async {
  final store = await LocalStore.open();
  for (final key in recordKeys) {
    final list = records[key];
    if (list != null) await store.writeList(key, list);
  }
}

/// Adds the records in [incoming] that this device does not have yet. Nothing on this device is changed or removed.
/// Returns the combined lists and how many records were added.
(Map<String, List<Map<String, dynamic>>>, int) mergeRecordLists(
  Map<String, List<Map<String, dynamic>>> current,
  Map<String, List<Map<String, dynamic>>> incoming,
) {
  final out = <String, List<Map<String, dynamic>>>{};
  var added = 0;
  for (final key in {...current.keys, ...incoming.keys}) {
    final base = current[key] ?? const <Map<String, dynamic>>[];
    final extra = incoming[key] ?? const <Map<String, dynamic>>[];
    final seen = {for (final r in base) recordIdentity(r)};
    final list = [...base];
    for (final r in extra) {
      if (seen.add(recordIdentity(r))) {
        list.add(r);
        added++;
      }
    }
    out[key] = list;
  }
  return (out, added);
}

