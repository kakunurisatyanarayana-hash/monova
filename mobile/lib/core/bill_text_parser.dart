/// Finds the date, the final amount and the biller's name in the text read from a bill photo.
///
/// Printed bills vary a lot, so this works from labels first (Total, Net amount, Bill to, M/s, Customer),
/// then falls back to the largest amount and the first date. Every value is shown to the user to confirm
/// before it is saved, so a wrong guess is caught.
class ParsedBill {
  const ParsedBill({this.date, this.amountRupees, this.billerName, this.itemsText = ''});

  final DateTime? date;
  final double? amountRupees;
  final String? billerName;

  /// What was bought, read from the item lines of the bill (for example 'Urea 2 bags, Pesticide 1 L').
  final String itemsText;

  bool get isEmpty => date == null && amountRupees == null && (billerName == null || billerName!.isEmpty) && itemsText.isEmpty;
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

/// Amount labels, most reliable first: the amount to pay is what matters for credit.
const _amountLabels = [
  'grand total', 'net amount', 'net payable', 'amount payable', 'final price', 'total amount', 'amount due', 'total', 'amount',
];

const _nameLabels = ['bill to', 'billed to', 'sold to', 'customer name', 'name of biller', 'biller', 'customer', 'name', 'm/s', 'ms'];

ParsedBill parseBillText(String text) {
  final lines = text.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  return ParsedBill(
    date: _findDate(lines),
    amountRupees: _findAmount(lines),
    billerName: _findName(lines),
    itemsText: _findItems(lines),
  );
}

DateTime? _findDate(List<String> lines) {
  final numeric = RegExp(r'(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})');
  final textual = RegExp(r'(\d{1,2})\s*[- ]?\s*([A-Za-z]{3,})\s*[- ,]?\s*(\d{2,4})');
  for (final line in lines) {
    final n = numeric.firstMatch(line);
    if (n != null) {
      final d = int.parse(n.group(1)!);
      final m = int.parse(n.group(2)!);
      var y = int.parse(n.group(3)!);
      if (y < 100) y += 2000;
      if (_validDate(y, m, d)) return DateTime(y, m, d);
    }
    final t = textual.firstMatch(line);
    if (t != null) {
      final month = _months[t.group(2)!.substring(0, 3).toLowerCase()];
      var y = int.parse(t.group(3)!);
      if (y < 100) y += 2000;
      final d = int.parse(t.group(1)!);
      if (month != null && _validDate(y, month, d)) return DateTime(y, month, d);
    }
  }
  return null;
}

bool _validDate(int y, int m, int d) => y >= 2000 && y <= 2100 && m >= 1 && m <= 12 && d >= 1 && d <= 31;

final _money = RegExp(r'(?:rs\.?|inr|₹)?\s*([0-9]{1,3}(?:,[0-9]{2,3})+(?:\.\d{1,2})?|[0-9]+(?:\.\d{1,2})?)', caseSensitive: false);

double? _numberIn(String text) {
  final m = _money.allMatches(text).toList();
  if (m.isEmpty) return null;
  // The last number on a labelled line is usually the amount ("Total: 2 bags 1,250.00").
  final raw = m.last.group(1)!.replaceAll(',', '');
  return double.tryParse(raw);
}

double? _findAmount(List<String> lines) {
  for (final label in _amountLabels) {
    for (final line in lines) {
      if (line.toLowerCase().contains(label)) {
        final v = _numberIn(line.substring(line.toLowerCase().indexOf(label) + label.length));
        if (v != null && v > 0) return v;
      }
    }
  }
  // Fallback: the largest amount on the bill, skipping things that look like dates or phone numbers.
  double? best;
  for (final line in lines) {
    if (RegExp(r'\d{1,2}[./-]\d{1,2}[./-]\d{2,4}').hasMatch(line)) continue;
    for (final m in _money.allMatches(line)) {
      final v = double.tryParse(m.group(1)!.replaceAll(',', ''));
      if (v != null && v > 0 && v < 10000000 && (best == null || v > best)) best = v;
    }
  }
  return best;
}

String? _findName(List<String> lines) {
  for (final label in _nameLabels) {
    for (final line in lines) {
      final lower = line.toLowerCase();
      final at = lower.indexOf(label);
      if (at < 0) continue;
      // Skip words that merely contain the label, such as "Bill number" for "bill to" or "Username" for "name".
      final before = at == 0 ? ' ' : lower[at - 1];
      if (RegExp(r'[a-z]').hasMatch(before)) continue;
      var rest = line.substring(at + label.length).replaceFirst(RegExp(r'^[\s:.\-]+'), '');
      rest = rest.replaceAll(RegExp(r'\s{2,}.*$'), '').trim();
      if (rest.length >= 3 && RegExp(r'[A-Za-z]').hasMatch(rest) && !RegExp(r'\d{4,}').hasMatch(rest)) {
        return rest;
      }
    }
  }
  return null;
}

const _skipWords = ['total', 'amount', 'gst', 'bill no', 'invoice', 'date', 'name', 'bill to', 'customer', 'phone', 'mobile', 'thank', 'address', 'cgst', 'sgst', 'tax', 'discount', 'balance', 'paid', 'cash', 'gstin', 'm/s'];

/// Item lines: text with letters, then a money amount, and not a total, tax or header line.
String _findItems(List<String> lines) {
  final items = <String>[];
  for (final line in lines) {
    final lower = line.toLowerCase();
    if (_skipWords.any(lower.contains)) continue;
    if (!RegExp(r'[A-Za-z]{3,}').hasMatch(line)) continue;
    if (!RegExp(r'\d').hasMatch(line)) continue;
    // Keep the words before the first number, so "Urea 2 bags  Rs 1,200.00" becomes "Urea 2 bags".
    final name = line.split(RegExp(r'\s{2,}|\s+(?:rs\.?|inr|₹)|\s+\d[\d,.]*\s*$')).first.trim();
    if (name.length >= 3 && RegExp(r'[A-Za-z]{3,}').hasMatch(name) && !items.contains(name)) items.add(name);
    if (items.length == 5) break;
  }
  return items.join(', ');
}