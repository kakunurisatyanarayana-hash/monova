/// Rules for saved cards. Pure functions, so they can be tested without a device.
library;

/// Keeps digits only, so "4111 1111 1111 1111" and "4111111111111111" are the same.
String digitsOnly(String text) => text.replaceAll(RegExp(r'\D'), '');

/// The only part of a card number that is ever stored.
String lastFour(String digits) =>
    digits.length <= 4 ? digits : digits.substring(digits.length - 4);

/// Length 12 to 19 digits and a passing Luhn check. Catches most typing mistakes before saving.
bool isValidCardNumber(String digits) {
  if (digits.length < 12 || digits.length > 19) return false;
  var sum = 0;
  var double = false;
  for (var i = digits.length - 1; i >= 0; i--) {
    var n = digits.codeUnitAt(i) - 48;
    if (double) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    double = !double;
  }
  return sum % 10 == 0;
}

/// Null when the number is acceptable; otherwise says which check failed, so the user knows what to fix.
String? cardNumberError(String digits) {
  if (digits.length < 12 || digits.length > 19) {
    return 'Card numbers have 12 to 19 digits. You entered ${digits.length}.';
  }
  if (!isValidCardNumber(digits)) {
    return 'This number fails the card check digit test, so one digit is probably mistyped. Compare it with the card.';
  }
  return null;
}

/// Card network from the leading digits. Only used as a label, so unknown ones say "Card".
String detectNetwork(String digits) {
  if (digits.startsWith('4')) return 'Visa';
  if (digits.startsWith('34') || digits.startsWith('37')) return 'Amex';
  if (digits.length >= 2) {
    final two = int.tryParse(digits.substring(0, 2)) ?? 0;
    if (two >= 51 && two <= 55) return 'Mastercard';
    if (digits.length >= 4) {
      final four = int.tryParse(digits.substring(0, 4)) ?? 0;
      if (four >= 2221 && four <= 2720) return 'Mastercard';
    }
    if (two == 60 ||
        two == 65 ||
        two == 81 ||
        two == 82 ||
        digits.startsWith('508'))
      return 'RuPay';
  }
  return 'Card';
}

/// Null when the expiry is fine; otherwise the reason to show the user.
String? expiryError(int month, int year, DateTime now) {
  if (month < 1 || month > 12) return 'Pick the month shown on the card.';
  if (year < now.year) return 'This card has already expired.';
  if (year == now.year && month < now.month)
    return 'This card has already expired.';
  return null;
}

/// Null when the photo is acceptable: PNG or JPEG, and at most 1.5 MB after resizing.
String? photoError(String mimeType, int byteCount) {
  if (mimeType != 'image/png' && mimeType != 'image/jpeg')
    return 'Only PNG or JPEG pictures can be saved.';
  if (byteCount > 1500 * 1024)
    return 'This picture is over 1.5 MB, which is too big to store. Choose a smaller picture, or take the photo again with a lower camera resolution.';
  return null;
}
