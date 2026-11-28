import 'local_store.dart';
import 'profile_store.dart';

/// Every change to customers, bills and payments: who did it, when, what, and the reason given.
/// Kept on this phone. Deleted entries are kept here too, so the record stays complete.
const ledgerActivityKey = 'monova.ledger.activity';

class LedgerActivity {
  const LedgerActivity({
    required this.at,
    required this.who,
    required this.action,
    required this.kind,
    required this.customer,
    required this.label,
    required this.reason,
  });

  final DateTime at;

  /// The owner's name from the profile, or "This phone" when no name is set.
  final String who;

  /// added, edited, deleted or settled.
  final String action;

  /// customer, bill or payment.
  final String kind;

  /// The customer this entry belongs to.
  final String customer;

  /// A short description of the bill or payment, for example "Urea 2 bags · ₹1,200.00".
  final String label;

  /// The reason given for an edit, delete or settlement. Empty for plain additions.
  final String reason;

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'who': who,
    'action': action,
    'kind': kind,
    'customer': customer,
    'label': label,
    'reason': reason,
  };

  factory LedgerActivity.fromJson(Map<String, dynamic> j) => LedgerActivity(
    at: DateTime.parse('${j['at']}'),
    who: '${j['who'] ?? ''}',
    action: '${j['action'] ?? ''}',
    kind: '${j['kind'] ?? ''}',
    customer: '${j['customer'] ?? ''}',
    label: '${j['label'] ?? ''}',
    reason: '${j['reason'] ?? ''}',
  );
}

class LedgerActivityStore {
  LedgerActivityStore._();

  /// Newest first.
  static Future<List<LedgerActivity>> load() async {
    final store = await LocalStore.open();
    final list = [for (final m in store.readList(ledgerActivityKey)) LedgerActivity.fromJson(m)];
    list.sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  static Future<void> add(LedgerActivity entry) async {
    final store = await LocalStore.open();
    final existing = store.readList(ledgerActivityKey);
    final next = [entry.toJson(), ...existing];
    // Keep the most recent 5000 entries, so the phone storage stays small.
    await store.writeList(ledgerActivityKey, next.length > 5000 ? next.sublist(0, 5000) : next);
  }

  /// The owner's name for the record, or "This phone" when the profile has no name.
  static Future<String> whoNow() async {
    final profile = await loadProfile();
    final name = profile?.name.trim() ?? '';
    return name.isEmpty ? 'This phone' : name;
  }
}
