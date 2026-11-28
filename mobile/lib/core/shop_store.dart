import 'local_store.dart';

/// Daily shop bills for a kirana, fertilizer, hotel or similar shop: sales, expenses and supplier bills.
/// Separate from customer credit (the khata with interest) and from the owner's own money.
const shopEntriesKey = 'monova.shop.entries';

enum ShopKind { sale, expense, bill }

String shopKindLabel(ShopKind k) => switch (k) {
      ShopKind.sale => 'Sale',
      ShopKind.expense => 'Expense',
      ShopKind.bill => 'Supplier bill',
    };

class ShopEntry {
  const ShopEntry({
    required this.id,
    required this.day,
    required this.kind,
    required this.party,
    required this.description,
    required this.amountCents,
    this.paid = true,
  });

  final String id;
  final DateTime day;
  final ShopKind kind;

  /// Customer for a sale, supplier for a bill, or empty for an expense.
  final String party;
  final String description;
  final int amountCents;

  /// A sale not yet paid is on credit. A bill not yet paid is still to pay. Expenses are always paid.
  final bool paid;

  ShopEntry copyWith({
    DateTime? day,
    ShopKind? kind,
    String? party,
    String? description,
    int? amountCents,
    bool? paid,
  }) =>
      ShopEntry(
        id: id,
        day: day ?? this.day,
        kind: kind ?? this.kind,
        party: party ?? this.party,
        description: description ?? this.description,
        amountCents: amountCents ?? this.amountCents,
        paid: paid ?? this.paid,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'day': DateTime(day.year, day.month, day.day).toIso8601String(),
        'kind': kind.name,
        'party': party,
        'description': description,
        'amountCents': amountCents,
        'paid': paid,
      };

  factory ShopEntry.fromJson(Map<String, dynamic> j) => ShopEntry(
        id: '${j['id']}',
        day: DateTime.parse('${j['day']}'),
        kind: ShopKind.values.byName('${j['kind']}'),
        party: '${j['party'] ?? ''}',
        description: '${j['description'] ?? ''}',
        amountCents: (j['amountCents'] as num).toInt(),
        paid: j['paid'] != false,
      );
}

class ShopStore {
  ShopStore._();

  static Future<List<ShopEntry>> load() async {
    final store = await LocalStore.open();
    return [for (final m in store.readList(shopEntriesKey)) ShopEntry.fromJson(m)];
  }

  static Future<void> save(List<ShopEntry> entries) async {
    final store = await LocalStore.open();
    await store.writeList(shopEntriesKey, [for (final e in entries) e.toJson()]);
  }
}

/// Totals for one day, in paise.
class ShopDayTotals {
  const ShopDayTotals({required this.cashIn, required this.cashOut, required this.onCredit, required this.toPay});

  /// Sales received in cash or online.
  final int cashIn;

  /// Expenses plus supplier bills already paid.
  final int cashOut;

  /// Sales not yet paid by the customer.
  final int onCredit;

  /// Supplier bills not yet paid.
  final int toPay;

  int get net => cashIn - cashOut;
}

ShopDayTotals shopTotalsFor(List<ShopEntry> all, DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  var cashIn = 0;
  var cashOut = 0;
  var onCredit = 0;
  var toPay = 0;
  for (final e in all) {
    if (e.day != d) continue;
    switch (e.kind) {
      case ShopKind.sale:
        if (e.paid) {
          cashIn += e.amountCents;
        } else {
          onCredit += e.amountCents;
        }
      case ShopKind.expense:
        cashOut += e.amountCents;
      case ShopKind.bill:
        if (e.paid) {
          cashOut += e.amountCents;
        } else {
          toPay += e.amountCents;
        }
    }
  }
  return ShopDayTotals(cashIn: cashIn, cashOut: cashOut, onCredit: onCredit, toPay: toPay);
}
