import 'data_revision.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A saved card, with the details needed to pay online: the full number, expiry and name.
/// The CVV is never stored. The number is shown masked (•••• 1234) except when the owner asks to see it.
class CardRecord {
  const CardRecord({
    required this.id,
    required this.bank,
    required this.network,
    required this.last4,
    required this.holder,
    required this.expiryMonth,
    required this.expiryYear,
    required this.updatedAt,
    this.number = '',
    this.nickname = '',
    this.photoBase64 = '',
    this.photoType = '',
  });

  final String id;
  final String nickname;
  final String bank;
  final String network;

  /// The full card number, digits only. Empty for cards saved before full numbers were kept, and on the web build.
  final String number;
  final String last4;
  final String holder;
  final int expiryMonth;
  final int expiryYear;
  final DateTime updatedAt;

  /// The card photo, base64 encoded, with its MIME type. Empty when no photo was saved.
  final String photoBase64;
  final String photoType;

  bool get hasPhoto => photoBase64.isNotEmpty;

  String get masked => '•••• $last4';

  bool get hasFullNumber => number.isNotEmpty;

  /// The full number in groups of four, for reading it off the card: 4111 1111 1111 1111.
  String get groupedNumber {
    final buffer = StringBuffer();
    for (var i = 0; i < number.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(number[i]);
    }
    return buffer.toString();
  }

  String get expiryLabel => '${expiryMonth.toString().padLeft(2, '0')}/${(expiryYear % 100).toString().padLeft(2, '0')}';

  String get title => nickname.isNotEmpty ? nickname : (bank.isNotEmpty ? bank : network);

  CardRecord copyWith({
    String? nickname,
    String? bank,
    String? network,
    String? last4,
    String? number,
    String? holder,
    int? expiryMonth,
    int? expiryYear,
    DateTime? updatedAt,
    String? photoBase64,
    String? photoType,
  }) {
    return CardRecord(
      id: id,
      nickname: nickname ?? this.nickname,
      bank: bank ?? this.bank,
      network: network ?? this.network,
      last4: last4 ?? this.last4,
      number: number ?? this.number,
      holder: holder ?? this.holder,
      expiryMonth: expiryMonth ?? this.expiryMonth,
      expiryYear: expiryYear ?? this.expiryYear,
      updatedAt: updatedAt ?? this.updatedAt,
      photoBase64: photoBase64 ?? this.photoBase64,
      photoType: photoType ?? this.photoType,
    );
  }

  Map<String, dynamic> toJson() => {
        ...toJsonWithoutPhoto(),
        'photoBase64': photoBase64,
        'photoType': photoType,
      };

  /// Same details without the photo. Used for backups, where a photo would make the text too large to copy.
  /// Backups are encrypted with a passphrase, so the full number can go in them.
  Map<String, dynamic> toJsonWithoutPhoto() => {
        'id': id,
        'nickname': nickname,
        'bank': bank,
        'network': network,
        'number': number,
        'last4': last4,
        'holder': holder,
        'expiryMonth': expiryMonth,
        'expiryYear': expiryYear,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CardRecord.fromJson(Map<String, dynamic> j) {
    return CardRecord(
      id: '${j['id']}',
      nickname: '${j['nickname'] ?? ''}',
      bank: '${j['bank'] ?? ''}',
      network: '${j['network'] ?? 'Card'}',
      number: '${j['number'] ?? ''}',
      last4: '${j['last4'] ?? ''}',
      holder: '${j['holder'] ?? ''}',
      expiryMonth: (j['expiryMonth'] as num?)?.toInt() ?? 1,
      expiryYear: (j['expiryYear'] as num?)?.toInt() ?? DateTime.now().year,
      updatedAt: DateTime.tryParse('${j['updatedAt']}') ?? DateTime.now(),
      photoBase64: '${j['photoBase64'] ?? ''}',
      photoType: '${j['photoType'] ?? ''}',
    );
  }
}

/// Keeps saved cards on this device. On phones the list is in the platform secure storage
/// (Android Keystore or iOS Keychain). Web browsers have no equivalent, so the web build uses plain browser storage.
class CardStore {
  CardStore._();

  static const _key = 'monova.cards';
  static const _secure = FlutterSecureStorage();

  static bool get encrypted => !kIsWeb;

  /// Phones keep the full number in secure storage. The web build has no secure storage, so it keeps only the last four digits.
  static bool get keepsFullNumber => !kIsWeb;

  static Future<List<CardRecord>> load() async {
    final raw = kIsWeb
        ? (await SharedPreferences.getInstance()).getString(_key)
        : await _secure.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    // Damaged data throws here; the screen reports it instead of silently overwriting the saved cards.
    final list = jsonDecode(raw) as List<dynamic>;
    final cards = list.map((e) => CardRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    cards.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return cards;
  }

  static Future<void> save(List<CardRecord> cards) async {
    await _saveRaw(cards);
    markDataChanged();
  }

  static Future<void> _saveRaw(List<CardRecord> cards) async {
    // The web build never writes the full number to browser storage.
    final raw = jsonEncode([
      for (final c in cards) (keepsFullNumber ? c : c.copyWith(number: '')).toJson(),
    ]);
    if (kIsWeb) {
      await (await SharedPreferences.getInstance()).setString(_key, raw);
    } else {
      await _secure.write(key: _key, value: raw);
    }
  }
}
