import 'package:intl/intl.dart';

/// Indian-rupee formatting. Display only: values come from the server.
final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _moneyCompact = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _day = DateFormat('d MMM yyyy');
final _dayShort = DateFormat('d MMM');
final _month = DateFormat('MMM yyyy');

String money(double value) => _money.format(value);

String moneyCompact(double value) => _moneyCompact.format(value);

String moneySigned(double value) => '${value < 0 ? '−' : '+'}${_money.format(value.abs())}';

String dayLabel(DateTime d) => _day.format(d);

String dayShort(DateTime d) => _dayShort.format(d);

String monthLabel(int year, int month) => _month.format(DateTime(year, month));

/// Rounds a user-entered amount to two decimals and rejects anything that is not a positive amount.
double? parseAmount(String text) {
  final value = double.tryParse(text.replaceAll(',', '').trim());
  if (value == null || value <= 0) return null;
  return double.parse(value.toStringAsFixed(2));
}

String? validateAmount(String? text) {
  if (text == null || text.trim().isEmpty) return 'Enter an amount';
  final value = parseAmount(text);
  if (value == null) return 'Enter a positive amount with at most two decimals';
  return null;
}

/// Friendly date for lists: "Today", "Yesterday", or the full date.
String relativeDay(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return dayLabel(d);
}
