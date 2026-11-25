import 'local_store.dart';

const billsKey = 'monova.bills';

/// One payment that settles a bill: [from] pays [to].
class Settlement {
  const Settlement({required this.from, required this.to, required this.cents});

  final String from;
  final String to;
  final int cents;

  Map<String, dynamic> toJson() => {'from': from, 'to': to, 'cents': cents};

  factory Settlement.fromJson(Map<String, dynamic> j) => Settlement(
        from: '${j['from']}',
        to: '${j['to']}',
        cents: (j['cents'] as num).toInt(),
      );
}

/// A bill that was split and saved on this device, with who paid and who pays whom.
class SavedBill {
  const SavedBill({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.totalCents,
    required this.payer,
    required this.people,
    required this.settlements,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final int totalCents;
  final String payer;
  final List<String> people;
  final List<Settlement> settlements;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'totalCents': totalCents,
        'payer': payer,
        'people': people,
        'settlements': settlements.map((s) => s.toJson()).toList(),
      };

  factory SavedBill.fromJson(Map<String, dynamic> j) => SavedBill(
        id: '${j['id']}',
        title: '${j['title'] ?? ''}',
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        totalCents: (j['totalCents'] as num?)?.toInt() ?? 0,
        payer: '${j['payer'] ?? ''}',
        people: [for (final p in (j['people'] as List<dynamic>? ?? const [])) '$p'],
        settlements: [
          for (final s in (j['settlements'] as List<dynamic>? ?? const []))
            Settlement.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
      );
}

/// Net position per person across all bills, in cents.
/// Positive means the person is owed money overall; negative means they owe money overall.
Map<String, int> netBalances(List<SavedBill> bills) {
  final net = <String, int>{};
  for (final bill in bills) {
    for (final s in bill.settlements) {
      net[s.to] = (net[s.to] ?? 0) + s.cents;
      net[s.from] = (net[s.from] ?? 0) - s.cents;
    }
  }
  net.removeWhere((_, v) => v == 0);
  return net;
}

/// Saved bills on this device, newest first.
class BillStore {
  BillStore._();

  static Future<List<SavedBill>> load() async {
    final store = await LocalStore.open();
    final bills = [for (final m in store.readList(billsKey)) SavedBill.fromJson(m)];
    bills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bills;
  }

  static Future<void> save(List<SavedBill> bills) async {
    final store = await LocalStore.open();
    await store.writeList(billsKey, [for (final b in bills) b.toJson()]);
  }
}
