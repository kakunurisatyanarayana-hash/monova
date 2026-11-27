import 'dart:convert';

import 'entry_store.dart';
import 'local_store.dart';
import 'reminders.dart';

const attachmentsKey = 'monova.attachments';

/// Owner id for documents that belong to no purchase (an invoice, an insurance paper, a bill).
const noOwner = '';

/// A receipt photo or a document picture kept on this phone. Only the picture is kept; nothing is uploaded.
class Attachment {
  const Attachment({
    required this.id,
    required this.ownerId,
    required this.kind,
    required this.name,
    required this.mimeType,
    required this.dataBase64,
    required this.addedAt,
  });

  final String id;

  /// The purchase this belongs to, or [noOwner] for a standalone document.
  final String ownerId;

  /// 'receipt' or 'document'.
  final String kind;
  final String name;
  final String mimeType;
  final String dataBase64;
  final DateTime addedAt;

  List<int> get bytes => base64Decode(dataBase64);

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'kind': kind,
        'name': name,
        'mimeType': mimeType,
        'dataBase64': dataBase64,
        'addedAt': addedAt.toIso8601String(),
      };

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        id: '${j['id']}',
        ownerId: '${j['ownerId'] ?? ''}',
        kind: '${j['kind'] ?? 'document'}',
        name: '${j['name'] ?? ''}',
        mimeType: '${j['mimeType'] ?? 'image/jpeg'}',
        dataBase64: '${j['dataBase64'] ?? ''}',
        addedAt: DateTime.tryParse('${j['addedAt']}') ?? DateTime.now(),
      );
}

/// The attachments for one purchase (or the standalone documents for [noOwner]), newest first.
List<Attachment> attachmentsOf(List<Attachment> all, String ownerId) {
  final list = [for (final a in all) if (a.ownerId == ownerId) a];
  list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
  return list;
}

/// Purchase spending entries start with this prefix, so they can be kept in step with the purchases.
const purchaseEntryPrefix = 'buy-';

/// The reminder that warns before a warranty ends has this prefix and the purchase id.
const warrantyReminderPrefix = 'war-';

/// The finance entry for a purchase that is recorded as spending.
MoneyEntry purchaseEntry(Purchase p) => MoneyEntry(
      id: '$purchaseEntryPrefix${p.id}',
      income: false,
      title: 'Bought: ${p.name}',
      category: 'Purchases',
      cents: p.cents,
      date: p.date,
      notes: p.retailer,
    );

/// Brings the purchase entries in [entries] in line with [purchases] for the purchases that are recorded as spending.
/// [recorded] holds the ids of the purchases to keep in Monova Finance. Other entries are left alone.
List<MoneyEntry> mergePurchaseEntries(List<MoneyEntry> entries, List<Purchase> purchases, Set<String> recorded) {
  final wanted = {for (final p in purchases) if (recorded.contains(p.id)) purchaseEntry(p).id: purchaseEntry(p)};
  final kept = <MoneyEntry>[
    for (final e in entries)
      if (!e.id.startsWith(purchaseEntryPrefix)) e else if (wanted.containsKey(e.id)) wanted[e.id]!,
  ];
  final existing = {for (final e in entries) e.id};
  return [...kept, for (final e in wanted.values) if (!existing.contains(e.id)) e];
}

/// The warranty reminder for a purchase: 30 days before the warranty ends, at 10 in the morning.
/// Null when the purchase has no warranty or the date has passed.
Reminder? warrantyReminderFor(Purchase p, {DateTime? now, int daysBefore = 30}) {
  final ends = p.warrantyUntil;
  if (ends == null) return null;
  final due = DateTime(ends.year, ends.month, ends.day - daysBefore, 10);
  if (due.isBefore(now ?? DateTime.now())) return null;
  return Reminder(
    id: '$warrantyReminderPrefix${p.id}',
    title: 'Warranty on ${p.name} ends ${ends.day}/${ends.month}/${ends.year}',
    notes: 'Check the warranty before it runs out.',
    dueAt: due,
    createdAt: now ?? DateTime.now(),
    route: '/purchases',
  );
}

/// Adds, updates or removes the warranty reminder for a purchase, keeping one per purchase.
List<Reminder> syncWarrantyReminder(List<Reminder> reminders, Purchase p, {required bool enabled, DateTime? now}) {
  final id = '$warrantyReminderPrefix${p.id}';
  final others = [for (final r in reminders) if (r.id != id) r];
  if (!enabled) return others;
  final r = warrantyReminderFor(p, now: now);
  return r == null ? others : [...others, r];
}

class AttachmentStore {
  AttachmentStore._();

  static Future<List<Attachment>> load() async {
    final store = await LocalStore.open();
    return [for (final m in store.readList(attachmentsKey)) Attachment.fromJson(m)];
  }

  static Future<void> save(List<Attachment> list) async {
    final store = await LocalStore.open();
    await store.writeList(attachmentsKey, [for (final a in list) a.toJson()]);
  }
}
