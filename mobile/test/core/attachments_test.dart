import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/attachments.dart';
import 'package:monova_app/core/entry_store.dart';

void main() {
  final fan = Purchase(id: 'f', name: 'Ceiling fan', retailer: 'Store', cents: 240000, date: DateTime(2026, 11, 1), warrantyMonths: 24);
  final tv = Purchase(id: 't', name: 'TV', retailer: '', cents: 3000000, date: DateTime(2026, 11, 1));

  test('a recorded purchase becomes a spending entry, and is removed when it is no longer recorded', () {
    var entries = mergePurchaseEntries(const [], [fan, tv], {'f', 't'});
    expect(entries.map((e) => e.id), containsAll(['buy-f', 'buy-t']));
    expect(entries.firstWhere((e) => e.id == 'buy-f').income, isFalse);
    expect(entries.firstWhere((e) => e.id == 'buy-f').category, 'Purchases');

    // Taking the TV off the list of recorded purchases removes its entry only.
    entries = mergePurchaseEntries(entries, [fan, tv], {'f'});
    expect(entries.map((e) => e.id), ['buy-f']);
  });

  test('the warranty reminder is set 30 days before the warranty ends, and only once per purchase', () {
    final now = DateTime(2026, 11, 27);
    final r = warrantyReminderFor(fan, now: now)!;
    // Warranty ends 1 November 2028; 30 days before that is 2 October 2028.
    expect(r.dueAt, DateTime(2028, 10, 2, 10));
    expect(r.route, '/purchases');

    final once = syncWarrantyReminder(syncWarrantyReminder(const [], fan, enabled: true, now: now), fan, enabled: true, now: now);
    expect(once.length, 1);
    expect(syncWarrantyReminder(once, fan, enabled: false, now: now), isEmpty);
  });

  test('no warranty means no reminder, and a warranty already nearly over gives none', () {
    final now = DateTime(2026, 11, 27);
    expect(warrantyReminderFor(tv, now: now), isNull);
    final short = Purchase(id: 's', name: 'Lamp', retailer: '', cents: 100, date: DateTime(2026, 9, 1), warrantyMonths: 2);
    expect(warrantyReminderFor(short, now: now), isNull, reason: 'the reminder day has already passed');
  });

  test('attachments are listed for their owner only, newest first', () {
    final all = [
      Attachment(id: '1', ownerId: 'f', kind: 'receipt', name: 'bill.jpg', mimeType: 'image/jpeg', dataBase64: 'aGk=', addedAt: DateTime(2026, 11, 1)),
      Attachment(id: '2', ownerId: 'f', kind: 'receipt', name: 'warranty.jpg', mimeType: 'image/jpeg', dataBase64: 'aGk=', addedAt: DateTime(2026, 11, 5)),
      Attachment(id: '3', ownerId: noOwner, kind: 'document', name: 'insurance.png', mimeType: 'image/png', dataBase64: 'aGk=', addedAt: DateTime(2026, 11, 2)),
    ];
    expect(attachmentsOf(all, 'f').map((a) => a.id), ['2', '1']);
    expect(attachmentsOf(all, noOwner).single.name, 'insurance.png');
    expect(Attachment.fromJson(all.first.toJson()).bytes, [104, 105]);
  });
}
