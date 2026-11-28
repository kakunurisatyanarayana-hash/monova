import 'credit_ledger.dart';
import 'local_store.dart';

/// The personal Credit manager: money I lent and money I borrowed, recorded by hand. Stored on this phone only.
/// Kept separate from the customer book, and never copied with server balances.
const personalCreditKey = 'monova.personal.credit';

class PersonalCreditStore {
  PersonalCreditStore._();

  static Future<List<CreditAccount>> load() async {
    final store = await LocalStore.open();
    return [
      for (final m in store.readList(personalCreditKey))
        CreditAccount.fromJson(m),
    ];
  }

  static Future<void> save(List<CreditAccount> items) async {
    final store = await LocalStore.open();
    await store.writeList(personalCreditKey, [
      for (final a in items) a.toJson(),
    ]);
  }
}

/// Totals for the Credit manager, in paise: what is owed to me, what I owe, and the net.
class PersonalCreditTotals {
  const PersonalCreditTotals({required this.toReceive, required this.toPay});

  final int toReceive;
  final int toPay;
  int get net => toReceive - toPay;
}

PersonalCreditTotals personalCreditTotals(
  List<CreditAccount> items,
  DateTime today,
) {
  var receive = 0;
  var pay = 0;
  for (final a in items) {
    final t = accountTotalCents(a, today);
    if (a.iOwe) {
      pay += t;
    } else {
      receive += t;
    }
  }
  return PersonalCreditTotals(toReceive: receive, toPay: pay);
}
