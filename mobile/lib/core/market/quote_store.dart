import '../local_store.dart';
import 'jeweller_quotes.dart';

/// Saves the jeweller quotes on this phone. Nothing is sent anywhere.
class QuoteStore {
  QuoteStore._();

  static const _key = 'monova.market.quotes';

  static Future<List<JewellerQuote>> load() async {
    final store = await LocalStore.open();
    return [for (final m in store.readList(_key)) ?JewellerQuote.fromJson(m)];
  }

  static Future<void> save(List<JewellerQuote> quotes) async {
    final store = await LocalStore.open();
    await store.writeList(_key, [for (final q in quotes) q.toJson()]);
  }
}
