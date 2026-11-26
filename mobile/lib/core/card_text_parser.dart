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
  final candidates = <String>[];
  for (final m in RegExp(r'\d(?:[ \-]?\d){11,18}').allMatches(text)) {
    final digits = digitsOnly(m.group(0)!);
    if (digits.length >= 12 && digits.length <= 19) candidates.add(digits);
  }
  for (final d in candidates) {
    if (isValidCardNumber(d)) return d;
  }
  return candidates.isEmpty ? null : candidates.first;
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
