import 'card_rules.dart';

/// What could be read from the text of a card photo. Every field is optional; the user checks them before saving.
class ParsedCard {
  const ParsedCard({this.digits, this.expiryMonth, this.expiryYear, this.holder, this.bank});

  /// The full card number as printed (digits only). Only its last four digits are ever kept.
  final String? digits;
  final int? expiryMonth;
  final int? expiryYear;
  final String? holder;
  final String? bank;

  bool get isEmpty => digits == null && expiryMonth == null && holder == null && bank == null;
}

/// Words that are printed on cards but are not the cardholder's name.
const _notNames = [
  'BANK', 'VISA', 'MASTER', 'MASTERCARD', 'RUPAY', 'AMEX', 'DEBIT', 'CREDIT', 'PLATINUM', 'GOLD', 'SIGNATURE',
  'VALID', 'THRU', 'FROM', 'MONTH', 'YEAR', 'CARD', 'MEMBER', 'AUTHORISED', 'AUTHORIZED', 'CONTACTLESS', 'INTERNATIONAL',
  'WORLD', 'CLASSIC', 'ELECTRONIC', 'USE', 'ONLY', 'NETWORK', 'CUSTOMER', 'CARDHOLDER', 'SAVINGS',
];

ParsedCard parseCardText(String text) {
  final lines = text.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  return ParsedCard(
    digits: _findNumber(text),
    expiryMonth: _findExpiry(text)?.$1,
    expiryYear: _findExpiry(text)?.$2,
    holder: _findHolder(lines),
    bank: _findBank(lines),
  );
}

/// A run of 12 to 19 digits, allowing spaces or dashes between groups. A number that passes the check digit test is preferred.
String? _findNumber(String text) {
  // The number is often printed in four groups over several lines, so a run of digit groups may cross line breaks.
  // Whole runs are tried first. Then every 12 to 19 digit window inside a run is tried, so a phone number or CVV
  // printed next to the card number does not hide it.
  // Buckets in the order they are tried: whole runs; windows that start and end on a printed group
  // (16 digits first, then other lengths); windows that start on a group; any other window.
  final buckets = List.generate(7, (_) => <String>[]);
  for (final m in RegExp(r'\d+(?:[ \-\t\r\n]+\d+)*').allMatches(text)) {
    final run = m.group(0)!;
    final digits = StringBuffer();
    final startsGroup = <bool>[];
    final endsGroup = <bool>[];
    var prevDigit = false;
    for (var i = 0; i < run.length; i++) {
      final code = run.codeUnitAt(i);
      if (code >= 48 && code <= 57) {
        digits.writeCharCode(code);
        startsGroup.add(!prevDigit);
        endsGroup.add(false);
        prevDigit = true;
      } else {
        if (prevDigit) endsGroup[endsGroup.length - 1] = true;
        prevDigit = false;
      }
    }
    if (endsGroup.isNotEmpty) endsGroup[endsGroup.length - 1] = true;
    final d = digits.toString();
    if (d.length < 12) continue;
    if (d.length <= 19) buckets[0].add(d);
    for (var s = 0; s + 12 <= d.length; s++) {
      for (final len in const [16, 15, 19, 18, 17, 14, 13, 12]) {
        final e = s + len;
        if (e > d.length) continue;
        final w = d.substring(s, e);
        final is16 = len == 16;
        if (startsGroup[s] && endsGroup[e - 1]) {
          buckets[is16 ? 1 : 2].add(w);
        } else if (startsGroup[s]) {
          buckets[is16 ? 3 : 4].add(w);
        } else {
          buckets[is16 ? 5 : 6].add(w);
        }
      }
    }
  }
  final all = [for (final b in buckets) ...b];
  for (final d in all) {
    if (isValidCardNumber(d)) return d;
  }
  for (final d in all) {
    if (d.length == 16) return d;
  }
  return all.isEmpty ? null : all.first;
}

/// An expiry written as MM/YY or MM/YYYY (also with a dash). Returns (month, year).
(int, int)? _findExpiry(String text) {
  final m = RegExp(r'(?<!\d)(0[1-9]|1[0-2])\s*[/\-]\s*(\d{2}|20\d{2})(?!\d)').firstMatch(text);
  if (m == null) return null;
  final month = int.parse(m.group(1)!);
  var year = int.parse(m.group(2)!);
  if (year < 100) year += 2000;
  return (month, year);
}

/// The cardholder's name: a line of two to four words in capital letters, with no digits and no card words.
String? _findHolder(List<String> lines) {
  for (final line in lines) {
    if (RegExp(r'\d').hasMatch(line)) continue;
    if (!RegExp(r"^[A-Z][A-Z.' ]{4,40}$").hasMatch(line)) continue;
    final words = line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < 2 || words.length > 4) continue;
    if (words.any(_notNames.contains)) continue;
    return line;
  }
  return null;
}

/// The bank name: a line with the word "bank", for example "HDFC BANK".
String? _findBank(List<String> lines) {
  for (final line in lines) {
    if (RegExp(r'\bbank\b', caseSensitive: false).hasMatch(line) && !RegExp(r'\d').hasMatch(line)) {
      return line.length > 40 ? line.substring(0, 40) : line;
    }
  }
  return null;
}
