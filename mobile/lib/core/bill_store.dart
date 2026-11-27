import 'groups_store.dart';

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
    this.notes = '',
    this.groupId = '',
  });

  /// The group this bill belongs to, or empty when it is not part of a group.
  final String groupId;

  final String notes;

  SavedBill copyWith({String? title, String? notes, String? groupId}) =>
      SavedBill(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        totalCents: totalCents,
        payer: payer,
        people: people,
        settlements: settlements,
        notes: notes ?? this.notes,
        groupId: groupId ?? this.groupId,
      );

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
    'notes': notes,
    'groupId': groupId,
  };

  factory SavedBill.fromJson(Map<String, dynamic> j) => SavedBill(
    id: '${j['id']}',
    title: '${j['title'] ?? ''}',
    createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
    notes: '${j['notes'] ?? ''}',
    groupId: '${j['groupId'] ?? ''}',
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
    final bills = [
      for (final m in store.readList(billsKey)) SavedBill.fromJson(m),
    ];
    bills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bills;
  }

  static Future<void> save(List<SavedBill> bills) async {
    final store = await LocalStore.open();
    await store.writeList(billsKey, [for (final b in bills) b.toJson()]);
  }
}

/// Each other person's balance with you, from the "who pays whom" settlements of every saved bill and group.
/// Positive means that person owes you; negative means you owe them.
Map<String, int> youBalances({
  required List<SavedBill> bills,
  required List<LocalGroup> groups,
  required String me,
}) {
  final out = <String, int>{};
  void add(String person, int cents) {
    if (person == me || person.isEmpty) return;
    out[person] = (out[person] ?? 0) + cents;
  }

  for (final b in bills) {
    for (final s in b.settlements) {
      if (s.to == me) add(s.from, s.cents);
      if (s.from == me) add(s.to, -s.cents);
    }
  }
  for (final g in groups) {
    final myId = g.myId;
    for (final s in g.settlements) {
      if (s.to == myId) add(g.nameOf(s.from), s.cents);
      if (s.from == myId) add(g.nameOf(s.to), -s.cents);
    }
  }
  out.removeWhere((_, v) => v == 0);
  return out;
}
