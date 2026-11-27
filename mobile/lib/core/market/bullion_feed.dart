// Pure parsing and merging for the snapdata.dev bullion feed (gold and silver benchmarks, from IBJA).
// No Flutter or network code in this file, so it can be tested directly against saved responses.

/// Gold and silver are daily benchmark prices, not live exchange quotes.
const snapdataBaseUrl = 'https://snapdata.dev/api/v1';

/// Products shown in Live Market. Gold is quoted per gram; silver per kilogram and converted to per gram for comparison.
class BullionProduct {
  const BullionProduct({required this.id, required this.label, required this.instrument, required this.dataset, required this.unit});

  final String id;
  final String label;

  /// The instrument code in the feed, for example XAU.24K.
  final String instrument;

  /// The feed dataset that carries it: "gold" or "silver".
  final String dataset;

  /// "gram" or "kilogram", as the feed states it.
  final String unit;
}

const bullionProducts = [
  BullionProduct(id: 'gold_24k', label: 'Gold 24K', instrument: 'XAU.24K', dataset: 'gold', unit: 'gram'),
  BullionProduct(id: 'gold_22k', label: 'Gold 22K', instrument: 'XAU.22K', dataset: 'gold', unit: 'gram'),
  BullionProduct(id: 'gold_18k', label: 'Gold 18K', instrument: 'XAU.18K', dataset: 'gold', unit: 'gram'),
  BullionProduct(id: 'silver', label: 'Silver', instrument: 'XAG', dataset: 'silver', unit: 'kilogram'),
];

BullionProduct? productForInstrument(String instrument) {
  for (final p in bullionProducts) {
    if (p.instrument == instrument) return p;
  }
  return null;
}

class SnapdataSource {
  const SnapdataSource({required this.id, required this.name, required this.url, required this.licence});

  final String id;
  final String name;
  final String url;
  final String licence;
}

class BullionObservation {
  const BullionObservation({required this.date, required this.instrument, required this.value, required this.status, required this.sourceId});

  /// The trading date only, with no time of day.
  final DateTime date;
  final String instrument;

  /// Null when the feed reports the day as missing. Missing days are never filled in.
  final double? value;

  /// "final", "provisional" or "missing", as the feed reports it.
  final String status;
  final String sourceId;
}

class BullionFeed {
  const BullionFeed({required this.dataset, required this.generatedAt, required this.sources, required this.observations});

  final String dataset;
  final DateTime? generatedAt;
  final Map<String, SnapdataSource> sources;
  final List<BullionObservation> observations;
}

/// A price the app has stored: one product on one day, from one source.
class StoredPrice {
  const StoredPrice({
    required this.productId,
    required this.date,
    required this.value,
    required this.status,
    required this.sourceId,
    required this.sourceName,
    required this.licence,
    required this.retrievedAt,
  });

  final String productId;
  final DateTime date;
  final double value;
  final String status;
  final String sourceId;
  final String sourceName;
  final String licence;
  final DateTime retrievedAt;

  /// One record per product and day, so repeated fetches do not duplicate history.
  String get key => '$productId|${_dayText(date)}';

  Map<String, dynamic> toJson() => {
        'product': productId,
        'date': _dayText(date),
        'value': value,
        'status': status,
        'source': sourceId,
        'sourceName': sourceName,
        'licence': licence,
        'retrievedAt': retrievedAt.toUtc().toIso8601String(),
      };

  /// Null for a damaged entry, which is then ignored rather than shown.
  static StoredPrice? fromJson(Map<String, dynamic> j) {
    final date = parseDay('${j['date']}');
    final value = j['value'];
    final retrieved = DateTime.tryParse('${j['retrievedAt']}');
    if (date == null || value is! num || retrieved == null) return null;
    return StoredPrice(
      productId: '${j['product']}',
      date: date,
      value: value.toDouble(),
      status: '${j['status']}',
      sourceId: '${j['source']}',
      sourceName: '${j['sourceName']}',
      licence: '${j['licence']}',
      retrievedAt: retrieved,
    );
  }
}

/// Reads a feed response. Unknown instruments and malformed rows are skipped.
BullionFeed parseBullionFeed(Map<String, dynamic> json) {
  final sources = <String, SnapdataSource>{};
  for (final s in (json['sources'] as List<dynamic>? ?? const [])) {
    if (s is! Map) continue;
    final id = '${s['id']}';
    sources[id] = SnapdataSource(id: id, name: '${s['name']}', url: '${s['url']}', licence: '${s['licence']}');
  }
  final observations = <BullionObservation>[];
  for (final o in (json['observations'] as List<dynamic>? ?? const [])) {
    if (o is! Map) continue;
    final date = parseDay('${o['date']}');
    if (date == null) continue;
    final instrument = '${o['instrument']}';
    if (productForInstrument(instrument) == null) continue;
    final raw = o['value'];
    double? value;
    if (raw is num) {
      value = raw.toDouble();
      // A zero or negative price is an error in the feed, not a price.
      if (!value.isFinite || value <= 0) value = null;
    }
    final status = value == null ? 'missing' : '${o['status'] ?? 'provisional'}';
    observations.add(BullionObservation(date: date, instrument: instrument, value: value, status: status, sourceId: '${o['source'] ?? ''}'));
  }
  return BullionFeed(
    dataset: '${json['dataset'] ?? ''}',
    generatedAt: DateTime.tryParse('${json['generated_at']}'),
    sources: sources,
    observations: observations,
  );
}

/// Turns a feed into stored prices. Missing days are dropped here, so only real values are kept.
List<StoredPrice> storedPricesFrom(BullionFeed feed, {required DateTime retrievedAt}) {
  final out = <StoredPrice>[];
  for (final o in feed.observations) {
    final product = productForInstrument(o.instrument);
    final value = o.value;
    if (product == null || value == null) continue;
    final source = feed.sources[o.sourceId];
    out.add(StoredPrice(
      productId: product.id,
      date: o.date,
      value: value,
      status: o.status,
      sourceId: o.sourceId,
      sourceName: source?.name ?? o.sourceId,
      licence: source?.licence ?? '',
      retrievedAt: retrievedAt,
    ));
  }
  return out;
}

/// Adds new prices to the stored ones. For a day already stored, the newer fetch wins, so a provisional value
/// is replaced by its final one once the feed publishes it.
List<StoredPrice> mergeStoredPrices(List<StoredPrice> existing, List<StoredPrice> incoming) {
  final byKey = <String, StoredPrice>{for (final p in existing) p.key: p};
  for (final p in incoming) {
    final old = byKey[p.key];
    if (old == null || !p.retrievedAt.isBefore(old.retrievedAt)) byKey[p.key] = p;
  }
  final merged = byKey.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  return merged;
}

/// The first day the IBJA benchmarks are published in the feed.
final bullionHistoryStart = DateTime(2026, 6, 29);

/// Days still to download for one dataset, oldest first. A day already tried is not asked for again.
List<DateTime> datesToBackfill({required String dataset, required DateTime today, required Set<String> attempted, int limit = 30}) {
  final out = <DateTime>[];
  var day = bullionHistoryStart;
  final last = DateTime(today.year, today.month, today.day);
  while (!day.isAfter(last) && out.length < limit) {
    if (!attempted.contains('$dataset|${_dayText(day)}')) out.add(day);
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return out;
}

/// The average of the stored values for each month, with the number of days that had a value.
class MonthSummary {
  const MonthSummary({required this.year, required this.month, required this.average, required this.days});

  final int year;
  final int month;
  final double average;
  final int days;
}

/// Monthly averages for one product, oldest first. Each value is converted with [unit] first, so silver is per gram.
List<MonthSummary> monthlyAverages(List<StoredPrice> prices, String productId, String unit) {
  final sums = <int, double>{};
  final counts = <int, int>{};
  for (final p in prices) {
    if (p.productId != productId) continue;
    final key = p.date.year * 100 + p.date.month;
    sums[key] = (sums[key] ?? 0) + perGram(p.value, unit);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final keys = sums.keys.toList()..sort();
  return [
    for (final k in keys)
      MonthSummary(year: k ~/ 100, month: k % 100, average: sums[k]! / counts[k]!, days: counts[k]!),
  ];
}

/// The latest stored price for a product and the one before it, for showing the change from the previous day.
({StoredPrice? latest, StoredPrice? previous}) latestAndPrevious(List<StoredPrice> prices, String productId) {
  final mine = [for (final p in prices) if (p.productId == productId) p]..sort((a, b) => a.date.compareTo(b.date));
  if (mine.isEmpty) return (latest: null, previous: null);
  return (latest: mine.last, previous: mine.length >= 2 ? mine[mine.length - 2] : null);
}

enum Freshness { today, recent, old }

/// Today for a price dated today (or later), recent within three days, old after that.
Freshness freshnessOf(DateTime observed, DateTime today) {
  final days = DateTime(today.year, today.month, today.day).difference(DateTime(observed.year, observed.month, observed.day)).inDays;
  if (days <= 0) return Freshness.today;
  if (days <= 3) return Freshness.recent;
  return Freshness.old;
}

/// The value per gram, so gold and silver can be compared. Silver is quoted per kilogram.
double perGram(double value, String unit) => unit == 'kilogram' ? value / 1000 : value;

/// Reads a date written as YYYY-MM-DD. Null when it is not in that form.
DateTime? parseDay(String text) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text.trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final date = DateTime(y, mo, d);
  // Reject dates like 2026-02-31, which DateTime would silently roll over.
  if (date.month != mo || date.day != d) return null;
  return date;
}

/// The day as YYYY-MM-DD, the form the feed uses in its file names.
String dayKey(DateTime d) => _dayText(d);

String _dayText(DateTime d) =>'${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
