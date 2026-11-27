// What each kind of number field may contain. Pure Dart, so the rules can be tested without Flutter.

/// A money amount: digits and thousands commas, then at most one decimal point with two decimal places.
final amountPattern = RegExp(r'^[0-9,]*(\.[0-9]{0,2})?$');

/// A whole number: digits only (days, months, floors, bed counts, PIN codes).
final wholeNumberPattern = RegExp(r'^[0-9]*$');

/// A phone number: digits, plus sign, spaces and hyphens.
final phonePattern = RegExp(r'^[+0-9 -]*$');

/// A signed decimal, for example a latitude or longitude: an optional minus, digits and one decimal point.
final signedDecimalPattern = RegExp(r'^-?[0-9]*(\.[0-9]*)?$');

/// True when [text] is acceptable for the pattern. Empty text is always acceptable while the user is typing.
bool fitsPattern(RegExp pattern, String text) => pattern.hasMatch(text);
