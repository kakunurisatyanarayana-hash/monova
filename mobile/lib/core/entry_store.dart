import 'local_store.dart';

const entriesKey = 'monova.entries';
const purchasesKey = 'monova.purchases';

/// Money in (income) or money out (spending). Amounts are whole paise, so there is no rounding error.
class MoneyEntry {
  const MoneyEntry({
    required this.id,
    required this.income,
    required this.title,
    required this.category,
    required this.cents,
    required this.date,
    this.notes = '',
  });

  final String id;
  final bool income;
  final String title;
  final String category;
  final int cents;
  final DateTime date;
  final String notes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'income': income,
    'title': title,
    'category': category,
    'cents': cents,
    'date': _iso(date),
    'notes': notes,
  };

  factory MoneyEntry.fromJson(Map<String, dynamic> j) => MoneyEntry(
    id: '${j['id']}',
    income: j['income'] == true,
    title: '${j['title'] ?? ''}',
    category: '${j['category'] ?? 'Other'}',
    cents: (j['cents'] as num).toInt(),
    date: DateTime.parse('${j['date']}'),
    notes: '${j['notes'] ?? ''}',
  );
}

/// A purchase with its warranty and return dates, so the user can see what is still covered.
class Purchase {
  const Purchase({
    required this.id,
    required this.name,
    required this.retailer,
    required this.cents,
    required this.date,
    this.warrantyMonths = 0,
    this.returnDays = 0,
    this.recordSpend = true,
    this.remindWarranty = true,
  });

  final String id;
  final String name;
  final String retailer;
  final int cents;
  final DateTime date;
  final int warrantyMonths;
  final int returnDays;

  /// Whether the purchase is also recorded as spending in Monova Finance.
  final bool recordSpend;

  /// Whether a reminder is set 30 days before the warranty ends.
  final bool remindWarranty;

  /// Warranty end date, or null if there is no warranty.
  DateTime? get warrantyUntil => warrantyMonths <= 0
      ? null
      : DateTime(date.year, date.month + warrantyMonths, date.day);

  /// Last day to return the item, or null if no return period was recorded.
  DateTime? get returnBy =>
      returnDays <= 0 ? null : date.add(Duration(days: returnDays));

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'retailer': retailer,
    'cents': cents,
    'date': _iso(date),
    'warrantyMonths': warrantyMonths,
    'returnDays': returnDays,
    'recordSpend': recordSpend,
    'remindWarranty': remindWarranty,
  };

  factory Purchase.fromJson(Map<String, dynamic> j) => Purchase(
    id: '${j['id']}',
    name: '${j['name'] ?? ''}',
    retailer: '${j['retailer'] ?? ''}',
    cents: (j['cents'] as num).toInt(),
    date: DateTime.parse('${j['date']}'),
    warrantyMonths: (j['warrantyMonths'] as num?)?.toInt() ?? 0,
    returnDays: (j['returnDays'] as num?)?.toInt() ?? 0,
    recordSpend: j['recordSpend'] != false,
    remindWarranty: j['remindWarranty'] != false,
  );
}

/// Totals for one calendar month.
class MonthSummary {
  const MonthSummary({required this.income, required this.spent});

  final int income;
  final int spent;

  int get savings => income - spent;
}

MonthSummary monthSummary(List<MoneyEntry> entries, int year, int month) {
  var income = 0;
  var spent = 0;
  for (final e in entries) {
    if (e.date.year != year || e.date.month != month) continue;
    if (e.category == 'Loan received') continue;
    if (e.income && e.category != 'Loan received') {
      income += e.cents;
    } else {
      spent += e.cents;
    }
  }
  return MonthSummary(income: income, spent: spent);
}

/// Spending per category for one month, largest first.
List<MapEntry<String, int>> spendingByCategory(
  List<MoneyEntry> entries,
  int year,
  int month,
) {
  final totals = <String, int>{};
  for (final e in entries) {
    if (e.income || e.date.year != year || e.date.month != month) continue;
    totals[e.category] = (totals[e.category] ?? 0) + e.cents;
  }
  return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

/// Comma-separated text that opens in any spreadsheet. Fields with commas or quotes are wrapped in quotes.
String entriesToCsv(List<MoneyEntry> entries) {
  final b = StringBuffer('date,type,category,title,amount,notes\n');
  final sorted = [...entries]..sort((a, c) => a.date.compareTo(c.date));
  for (final e in sorted) {
    b.write(
      [
        _iso(e.date),
        e.income ? 'income' : 'expense',
        e.category,
        e.title,
        (e.cents / 100).toStringAsFixed(2),
        e.notes,
      ].map(_csvField).join(','),
    );
    b.write('\n');
  }
  return b.toString();
}

String _csvField(String v) {
  if (v.contains(',') || v.contains('"') || v.contains('\n')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

/// Purchases whose warranty or return period is still open on [today], soonest first.
List<Purchase> openWarranties(List<Purchase> purchases, DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  final open = purchases.where((p) {
    final w = p.warrantyUntil;
    return w != null && !w.isBefore(day);
  }).toList();
  open.sort((a, b) => a.warrantyUntil!.compareTo(b.warrantyUntil!));
  return open;
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class EntryStore {
  EntryStore._();

  static Future<List<MoneyEntry>> loadEntries() async {
    final store = await LocalStore.open();
    final list = [
      for (final m in store.readList(entriesKey)) MoneyEntry.fromJson(m),
    ];
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static Future<void> saveEntries(List<MoneyEntry> entries) async {
    final store = await LocalStore.open();
    await store.writeList(entriesKey, [for (final e in entries) e.toJson()]);
  }

  static Future<List<Purchase>> loadPurchases() async {
    final store = await LocalStore.open();
    final list = [
      for (final m in store.readList(purchasesKey)) Purchase.fromJson(m),
    ];
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static Future<void> savePurchases(List<Purchase> purchases) async {
    final store = await LocalStore.open();
    await store.writeList(purchasesKey, [
      for (final p in purchases) p.toJson(),
    ]);
  }
}
