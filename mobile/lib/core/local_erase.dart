import '../features/tools/calculator_screen.dart' show calcHistoryKey;
import '../features/tools/saved_loan_scenarios.dart' show loanScenariosKey;
import 'bill_store.dart';
import 'card_store.dart';
import 'credit_ledger.dart';
import 'groups_store.dart';
import 'local_store.dart';
import 'entry_store.dart';
import 'property_money.dart';
import 'property_store.dart';
import 'notify.dart';
import 'reminders.dart';
import 'vault_store.dart';

/// Deletes everything this app keeps on the device: passwords and notes, cards, saved bills,
/// saved loan scenarios and calculator history. Used by "Erase data" on the lock screen.
Future<void> eraseLocalData() async {
  await VaultStore.save([]);
  await CardStore.save([]);
  await BillStore.save([]);
  await GroupStore.save([]);
  await CreditLedgerStore.save([]);
  final store = await LocalStore.open();
  await store.writeList(loanScenariosKey, []);
  await store.writeList(calcHistoryKey, []);
  await store.writeList(propertiesKey, []);
  await store.writeList(roomsKey, []);
  await store.writeList(tenanciesKey, []);
  await store.writeList(personsKey, []);
  await store.writeList(paymentsKey, []);
  final reminders = await ReminderStore.load();
  for (final r in reminders) {
    await cancelReminderAlert(r);
  }
  await ReminderStore.save([]);
  final entries = await EntryStore.loadEntries();
  await EntryStore.saveEntries([
    for (final e in entries)
      if (!e.id.startsWith('prop-')) e,
  ]);
}
