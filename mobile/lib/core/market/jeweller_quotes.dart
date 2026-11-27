// Jeweller quotes: the rate a shop actually quotes in a city, entered by the person who received it.
// Pure Dart, so it can be tested. Storage is in quote_store.dart.

import 'bullion_feed.dart';
import 'jewellery_estimate.dart';

class JewellerQuote {
  const JewellerQuote({
    required this.id,
    required this.shop,
    required this.city,
    required this.productId,
    required this.perGram,
    required this.makingPercent,
    required this.otherCharges,
    required this.quotedOn,
    this.note = '',
  });

  final String id;

  /// The shop or jeweller that gave the quote.
  final String shop;
  final String city;

  /// The product from bullionProducts: gold_24k, gold_22k, gold_18k or silver.
  final String productId;

  /// Rupees per gram, as the shop quoted it. Before making, GST and other charges.
  final double perGram;

  /// Making charge, as a percentage of the gold value.
  final double makingPercent;

  /// Other charges the shop adds for this purchase, such as hallmarking, in rupees.
  final double otherCharges;

  /// The day the quote was given (no time of day).
  final DateTime quotedOn;
  final String note;

  /// The full final cost for [grams], with GST at 3% on gold and making.
  JewelleryEstimate costFor(double grams) => estimateJewellery(
    perGram: perGram,
    grams: grams,
    makingPercent: makingPercent,
    otherCharges: otherCharges,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'shop': shop,
    'city': city,
    'product': productId,
    'perGram': perGram,
    'making': makingPercent,
    'other': otherCharges,
    'quotedOn': _dayText(quotedOn),
    'note': note,
  };

  /// Null for a damaged entry, which is then ignored rather than shown.
  static JewellerQuote? fromJson(Map<String, dynamic> j) {
    final day = parseDay('${j['quotedOn']}');
    final rate = j['perGram'];
    final making = j['making'];
    final other = j['other'];
    if (day == null || rate is! num || making is! num || other is! num)
      return null;
    return JewellerQuote(
      id: '${j['id']}',
      shop: '${j['shop']}',
      city: '${j['city']}',
      productId: '${j['product']}',
      perGram: rate.toDouble(),
      makingPercent: making.toDouble(),
      otherCharges: other.toDouble(),
      quotedOn: day,
      note: '${j['note'] ?? ''}',
    );
  }
}

/// The quotes for one city and product, newest first.
List<JewellerQuote> quotesFor(
  List<JewellerQuote> all,
  String city,
  String productId,
) {
  final out = [
    for (final q in all)
      if (q.city == city && q.productId == productId) q,
  ];
  out.sort((a, b) => b.quotedOn.compareTo(a.quotedOn));
  return out;
}

/// The change in rate per gram from this shop's previous quote for the same product. Null when there is none.
double? changeFromPreviousQuote(List<JewellerQuote> all, JewellerQuote q) {
  JewellerQuote? previous;
  for (final other in all) {
    if (other.shop != q.shop ||
        other.city != q.city ||
        other.productId != q.productId)
      continue;
    if (!other.quotedOn.isBefore(q.quotedOn) || other.id == q.id) continue;
    if (previous == null || other.quotedOn.isAfter(previous.quotedOn))
      previous = other;
  }
  return previous == null ? null : q.perGram - previous.perGram;
}

/// The national benchmark per gram on the day of a quote, for comparing the shop with the benchmark. Null when not stored.
double? nationalOn(List<StoredPrice> prices, String productId, DateTime day) {
  final product = bullionProducts.firstWhere((p) => p.id == productId);
  for (final p in prices) {
    if (p.productId == productId &&
        p.date.year == day.year &&
        p.date.month == day.month &&
        p.date.day == day.day) {
      return perGram(p.value, product.unit);
    }
  }
  return null;
}

String _dayText(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
