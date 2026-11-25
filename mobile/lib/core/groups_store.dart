import 'finance_calc.dart';
import 'local_store.dart';

const groupsKey = 'monova.groups';

class GroupMember {
  const GroupMember({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(id: '${j['id']}', name: '${j['name'] ?? ''}');
}

/// One shared expense. [shares] is what each member owes for it, in cents. The shares add up to [cents].
class GroupExpense {
  const GroupExpense({
    required this.id,
    required this.title,
    required this.cents,
    required this.paidBy,
    required this.shares,
    required this.createdAt,
  });

  final String id;
  final String title;
  final int cents;
  final String paidBy;
  final Map<String, int> shares;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cents': cents,
        'paidBy': paidBy,
        'shares': shares,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GroupExpense.fromJson(Map<String, dynamic> j) => GroupExpense(
        id: '${j['id']}',
        title: '${j['title'] ?? ''}',
        cents: (j['cents'] as num).toInt(),
        paidBy: '${j['paidBy']}',
        shares: {for (final e in (j['shares'] as Map<String, dynamic>).entries) e.key: (e.value as num).toInt()},
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
      );
}

class LocalGroup {
  const LocalGroup({required this.id, required this.name, required this.members, required this.expenses});

  final String id;
  final String name;
  final List<GroupMember> members;
  final List<GroupExpense> expenses;

  LocalGroup copyWith({String? name, List<GroupMember>? members, List<GroupExpense>? expenses}) => LocalGroup(
        id: id,
        name: name ?? this.name,
        members: members ?? this.members,
        expenses: expenses ?? this.expenses,
      );

  String nameOf(String memberId) {
    for (final m in members) {
      if (m.id == memberId) return m.name;
    }
    return 'Someone';
  }

  /// Net position per member in cents: positive means they are owed money, negative means they owe.
  Map<String, int> get netByMember {
    final net = <String, int>{for (final m in members) m.id: 0};
    for (final e in expenses) {
      net[e.paidBy] = (net[e.paidBy] ?? 0) + e.cents;
      for (final s in e.shares.entries) {
        net[s.key] = (net[s.key] ?? 0) - s.value;
      }
    }
    return net;
  }

  /// Who pays whom to settle the group, using the fewest payments the greedy method finds.
  List<({String from, String to, int cents})> get settlements => FinanceCalc.settle(netByMember);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members.map((m) => m.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
      };

  factory LocalGroup.fromJson(Map<String, dynamic> j) => LocalGroup(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        members: [for (final m in (j['members'] as List<dynamic>? ?? const [])) GroupMember.fromJson(Map<String, dynamic>.from(m as Map))],
        expenses: [for (final e in (j['expenses'] as List<dynamic>? ?? const [])) GroupExpense.fromJson(Map<String, dynamic>.from(e as Map))],
      );
}

/// Shares an amount equally among [memberIds]. Any leftover paisa go to the first members, so the total is exact.
Map<String, int> equalShares(int cents, List<String> memberIds) {
  final parts = FinanceCalc.splitCents(totalCents: cents, mode: 'equal', values: List<double?>.filled(memberIds.length, null));
  return {for (var i = 0; i < memberIds.length; i++) memberIds[i]: parts[i]};
}

class GroupStore {
  GroupStore._();

  static Future<List<LocalGroup>> load() async {
    final store = await LocalStore.open();
    final groups = [for (final m in store.readList(groupsKey)) LocalGroup.fromJson(m)];
    groups.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return groups;
  }

  static Future<void> save(List<LocalGroup> groups) async {
    final store = await LocalStore.open();
    await store.writeList(groupsKey, [for (final g in groups) g.toJson()]);
  }
}
