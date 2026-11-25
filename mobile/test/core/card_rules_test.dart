import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/backup_codec.dart';
import 'package:monova_app/core/card_rules.dart';
import 'package:monova_app/core/card_store.dart';

void main() {
  test('digits are pulled out of a typed card number and only the last four are kept', () {
    final digits = digitsOnly('4111 1111-1111 1111');
    expect(digits, '4111111111111111');
    expect(lastFour(digits), '1111');
    expect(lastFour('12'), '12');
  });

  test('card numbers must be 12 to 19 digits and pass the Luhn check', () {
    expect(isValidCardNumber('4111111111111111'), isTrue);
    expect(isValidCardNumber('4111111111111112'), isFalse, reason: 'one digit typed wrong');
    expect(isValidCardNumber('41111111111'), isFalse, reason: 'too short');
    expect(isValidCardNumber('41111111111111111111'), isFalse, reason: 'too long');
  });

  test('the network is read from the leading digits', () {
    expect(detectNetwork('4111111111111111'), 'Visa');
    expect(detectNetwork('5500000000000004'), 'Mastercard');
    expect(detectNetwork('2221000000000009'), 'Mastercard');
    expect(detectNetwork('378282246310005'), 'Amex');
    expect(detectNetwork('6080000000000000'), 'RuPay');
    expect(detectNetwork('9999999999999999'), 'Card');
  });

  test('an expired card is refused and a card expiring this month is accepted', () {
    final now = DateTime(2026, 11, 25);
    expect(expiryError(10, 2026, now), 'This card has already expired.');
    expect(expiryError(11, 2026, now), isNull);
    expect(expiryError(12, 2030, now), isNull);
    expect(expiryError(13, 2030, now), isNotNull);
  });

  test('only PNG and JPEG photos up to 1.5 MB are accepted', () {
    expect(photoError('image/png', 200 * 1024), isNull);
    expect(photoError('image/jpeg', 200 * 1024), isNull);
    expect(photoError('image/gif', 1000), isNotNull);
    expect(photoError('image/jpeg', 2 * 1024 * 1024), isNotNull);
  });

  test('a saved card keeps the last four digits and the photo, and the backup form leaves the photo out', () {
    final card = CardRecord(
      id: '1',
      bank: 'HDFC',
      network: 'Visa',
      last4: '1111',
      holder: 'ASHA RAO',
      expiryMonth: 8,
      expiryYear: 2029,
      updatedAt: DateTime.utc(2026, 11, 25),
      photoBase64: 'aGVsbG8=',
      photoType: 'image/png',
    );
    expect(card.masked, '•••• 1111');
    expect(card.expiryLabel, '08/29');

    final restored = CardRecord.fromJson(card.toJson());
    expect(restored.photoBase64, 'aGVsbG8=');

    final noPhoto = CardRecord.fromJson(card.toJsonWithoutPhoto());
    expect(noPhoto.last4, '1111');
    expect(noPhoto.hasPhoto, isFalse);
  });

  test('restoring a backup keeps the photo this device already has for a card', () {
    final t1 = DateTime.utc(2026, 11, 20);
    final t2 = DateTime.utc(2026, 11, 25);
    final onDevice = CardRecord(
      id: 'c', bank: 'ICICI', network: 'Visa', last4: '2222', holder: 'A', expiryMonth: 5, expiryYear: 2030,
      updatedAt: t1, photoBase64: 'cGhvdG8=', photoType: 'image/jpeg',
    );
    final fromBackup = CardRecord(
      id: 'c', bank: 'ICICI (renamed)', network: 'Visa', last4: '2222', holder: 'A', expiryMonth: 5, expiryYear: 2030,
      updatedAt: t2,
    );
    final result = mergeBackups(BackupContents(cards: [onDevice]), BackupContents(cards: [fromBackup]));
    final merged = result.merged.cards.single;
    expect(merged.bank, 'ICICI (renamed)');
    expect(merged.photoBase64, 'cGhvdG8=');
    expect(result.cardsAdded, 0);
  });
}
