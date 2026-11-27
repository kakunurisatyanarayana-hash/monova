import 'entry_store.dart';
import 'property_store.dart';

/// Payments are written to Monova Finance with ids that start with this prefix, so the sync can find its own entries.
const _financePrefix = 'prop-';

String financeEntryId(Payment p) => '$_financePrefix${p.id}';

/// The Monova Finance entry for a payment, or null for deposits and refunds (they are kept in the property, not in income or spending).
MoneyEntry? financeEntryFor(Payment p, PropertyBook book) {
  if (p.kind == 'deposit' || p.kind == 'refund') return null;
  final property = book.propertyById(p.propertyId);
  final propertyName = property?.name ?? 'Property';
  if (p.isExpense) {
    final category = p.category.isEmpty ? 'Property expense' : p.category;
    return MoneyEntry(
      id: financeEntryId(p),
      income: false,
      title: '$category · $propertyName',
      category: category,
      cents: p.amountCents,
      date: p.date,
      notes: p.note,
    );
  }
  final personName = book.personById(p.personId)?.name ?? '';
  final roomNumber = book.roomById(p.roomId)?.number;
  final what = p.kind == 'advance' ? 'Advance' : 'Rent';
  final who = personName.isEmpty ? propertyName : personName;
  final notes = [if (p.periodLabel.isNotEmpty) p.periodLabel, if (p.note.isNotEmpty) p.note].join(' · ');
  return MoneyEntry(
    id: financeEntryId(p),
    income: true,
    title: '$what · $who${roomNumber == null ? '' : ' · Room $roomNumber'}',
    category: (property?.retainsGuestData ?? false) ? 'Hotel income' : 'Rental income',
    cents: p.amountCents,
    date: p.date,
    notes: notes,
  );
}

/// Brings the property entries in [entries] in line with the book's payments.
/// Adds entries that are missing, updates changed ones, and removes entries whose payment was deleted.
/// Entries that were not made by the property module are left alone, so nothing is counted twice.
List<MoneyEntry> mergeFinanceEntries(List<MoneyEntry> entries, PropertyBook book) {
  final wanted = <String, MoneyEntry>{
    for (final p in book.payments)
      if (financeEntryFor(p, book) case final e?) e.id: e,
  };
  final kept = <MoneyEntry>[
    for (final e in entries)
      if (!e.id.startsWith(_financePrefix)) e else if (wanted.containsKey(e.id)) wanted[e.id]!,
  ];
  final existing = {for (final e in entries) e.id};
  final added = [for (final e in wanted.values) if (!existing.contains(e.id)) e];
  return [...kept, ...added];
}

/// Saves the property payments into Monova Finance. Call after any change to payments or to the people or property they refer to.
Future<void> syncFinance(PropertyBook book) async {
  final entries = await EntryStore.loadEntries();
  final merged = mergeFinanceEntries(entries, book);
  await EntryStore.saveEntries(merged);
}

/// Money for one property in one month, and the deposits it holds.
class MonthMoney {
  const MonthMoney({required this.rentCents, required this.expenseCents, required this.depositsHeldCents});

  final int rentCents;
  final int expenseCents;
  final int depositsHeldCents;

  int get netCents => rentCents - expenseCents;
}

/// Totals for [year]-[month]. Pass a null [propertyId] to total every property.
MonthMoney monthMoney(PropertyBook book, {String? propertyId, required int year, required int month}) {
  bool inProperty(Payment p) => propertyId == null || p.propertyId == propertyId;
  var rent = 0;
  var expense = 0;
  var deposits = 0;
  for (final p in book.payments) {
    if (!inProperty(p)) continue;
    if (p.kind == 'deposit') deposits += p.amountCents;
    if (p.kind == 'refund') deposits -= p.amountCents;
    if (p.date.year != year || p.date.month != month) continue;
    if (p.isIncome) rent += p.amountCents;
    if (p.isExpense) expense += p.amountCents;
  }
  return MonthMoney(rentCents: rent, expenseCents: expense, depositsHeldCents: deposits);
}

/// Payments of one property, newest first.
List<Payment> paymentsOf(PropertyBook book, String propertyId) {
  final list = [for (final p in book.payments) if (p.propertyId == propertyId) p];
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
}

/// Payments of one person, newest first.
List<Payment> paymentsOfPerson(PropertyBook book, String personId) {
  final list = [for (final p in book.payments) if (p.personId == personId) p];
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
}
