// Pure parsing for AGMARKNET mandi prices, as published on data.gov.in
// ("Current daily price of various commodities from various markets (Mandi)").
// Prices are in rupees per quintal (100 kg). No network or Flutter code here, so it can be tested directly.

const mandiDatasetId = '9ef84268-d588-465a-a308-a864a43d0070';
const mandiBaseUrl = 'https://api.data.gov.in/resource/$mandiDatasetId';
const mandiSourceName =
    'AGMARKNET, Ministry of Agriculture and Farmers Welfare, via data.gov.in';

class MandiRecord {
  const MandiRecord({
    required this.state,
    required this.district,
    required this.market,
    required this.commodity,
    required this.variety,
    required this.date,
    required this.minPrice,
    required this.maxPrice,
    required this.modalPrice,
  });

  final String state;
  final String district;
  final String market;
  final String commodity;
  final String variety;
  final DateTime date;

  /// Rupees per quintal. Null when the source did not publish that figure.
  final double? minPrice;
  final double? maxPrice;
  final double? modalPrice;

  /// One record per market, commodity, variety and day.
  String get key =>
      '$state|$district|$market|$commodity|$variety|${_dayText(date)}';

  Map<String, dynamic> toJson() => {
    'state': state,
    'district': district,
    'market': market,
    'commodity': commodity,
    'variety': variety,
    'date': _dayText(date),
    'min': minPrice,
    'max': maxPrice,
    'modal': modalPrice,
  };

  /// Reads a stored record. Its date is saved as YYYY-MM-DD, not in the source's day/month/year form.
  static MandiRecord? fromJson(Map<String, dynamic> j) {
    final date = _isoDay('${j['date']}');
    if (date == null) return null;
    return MandiRecord(
      state: '${j['state']}',
      district: '${j['district']}',
      market: '${j['market']}',
      commodity: '${j['commodity']}',
      variety: '${j['variety']}',
      date: date,
      minPrice: _num(j['min']),
      maxPrice: _num(j['max']),
      modalPrice: _num(j['modal']),
    );
  }
}

/// Reads one page of the data.gov.in response. Rows without a usable modal price are skipped, because a
/// price with no modal figure cannot be compared with others. Rows that are not valid are dropped, not guessed.
List<MandiRecord> parseMandiPage(Map<String, dynamic> json) {
  final rows = json['records'];
  if (rows is! List) return const [];
  final out = <MandiRecord>[];
  for (final r in rows) {
    if (r is! Map) continue;
    final date = parseIndianDate('${r['arrival_date']}');
    final modal = _num(r['modal_price']);
    if (date == null || modal == null || modal <= 0) continue;
    out.add(
      MandiRecord(
        state: '${r['state']}'.trim(),
        district: '${r['district']}'.trim(),
        market: '${r['market']}'.trim(),
        commodity: '${r['commodity']}'.trim(),
        variety: '${r['variety'] ?? ''}'.trim(),
        date: date,
        minPrice: _positive(_num(r['min_price'])),
        maxPrice: _positive(_num(r['max_price'])),
        modalPrice: modal,
      ),
    );
  }
  return out;
}

/// The AGMARKNET dates are day/month/year, for example 27/11/2026. Null when the text is not that form.
DateTime? parseIndianDate(String text) {
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text.trim());
  if (m == null) return null;
  final d = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final y = int.parse(m.group(3)!);
  final date = DateTime(y, mo, d);
  if (date.month != mo || date.day != d) return null;
  return date;
}

/// Rupees per kilogram from a quintal price.
double perKilogram(double perQuintal) => perQuintal / 100;

/// Merges new records into stored ones. The same market, commodity and day is kept once; the newer fetch wins.
List<MandiRecord> mergeMandi(
  List<MandiRecord> existing,
  List<MandiRecord> incoming,
) {
  final byKey = <String, MandiRecord>{for (final r in existing) r.key: r};
  for (final r in incoming) {
    byKey[r.key] = r;
  }
  return byKey.values.toList()..sort((a, b) => b.date.compareTo(a.date));
}

DateTime? _isoDay(String text) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text.trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final date = DateTime(y, mo, d);
  return (date.month == mo && date.day == d) ? date : null;
}

double? _num(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '').trim());
  return null;
}

double? _positive(double? v) => (v == null || v <= 0) ? null : v;

String _dayText(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
