import 'package:flutter/services.dart';

import 'input_patterns.dart';

/// Keeps a field to the characters its pattern allows. Anything else typed or pasted is refused, and the field keeps its previous text.
class _PatternFormatter extends TextInputFormatter {
  const _PatternFormatter(this.pattern);

  final RegExp pattern;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return fitsPattern(pattern, newValue.text) ? newValue : oldValue;
  }
}

/// Money amounts: 1,20,000.50 is fine; letters and a second decimal point are refused.
final List<TextInputFormatter> amountFormatters = [_PatternFormatter(amountPattern)];

/// Counts such as days, months, floors and beds, and PIN codes.
final List<TextInputFormatter> wholeNumberFormatters = [_PatternFormatter(wholeNumberPattern)];

/// Phone numbers.
final List<TextInputFormatter> phoneFormatters = [_PatternFormatter(phonePattern)];

/// Latitude and longitude, which may be negative.
final List<TextInputFormatter> signedDecimalFormatters = [_PatternFormatter(signedDecimalPattern)];
