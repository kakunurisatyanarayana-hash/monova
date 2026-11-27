import 'record_backup.dart';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'card_store.dart';
import 'vault_store.dart';

const _backupPrefix = 'MONOVA-BACKUP-1:';

class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Everything a backup carries. Only data that lives on the device is included.
class BackupContents {
  const BackupContents({
    this.vault = const [],
    this.loanScenarios = const [],
    this.calcHistory = const [],
    this.cards = const [],
    this.records = const {},
  });

  final List<VaultEntry> vault;
  final List<Map<String, dynamic>> loanScenarios;
  final List<Map<String, dynamic>> calcHistory;

  /// Card details only. Card photos are left out so the backup text stays small enough to copy.
  final List<CardRecord> cards;

  /// Records kept as plain lists on this device (finance, purchases, groups, bills, credit book, property, reminders), keyed by storage key.
  final Map<String, List<Map<String, dynamic>>> records;

  Map<String, dynamic> toJson() => {
        'format': 'monova-backup',
        'version': 3,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'vault': vault.map((e) => e.toJson()).toList(),
        'loanScenarios': loanScenarios,
        'calcHistory': calcHistory,
        'cards': cards.map((c) => c.toJsonWithoutPhoto()).toList(),
        'records': records,
      };

  factory BackupContents.fromJson(Map<String, dynamic> j) {
    if (j['format'] != 'monova-backup') throw const BackupException('This is not a MONOVA backup.');
    List<Map<String, dynamic>> maps(String key) => ((j[key] as List<dynamic>?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return BackupContents(
      vault: maps('vault').map(VaultEntry.fromJson).toList(),
      loanScenarios: maps('loanScenarios'),
      calcHistory: maps('calcHistory'),
      cards: maps('cards').map(CardRecord.fromJson).toList(),
      records: {
        for (final e in ((j['records'] as Map?) ?? const {}).entries)
          '${e.key}': [for (final m in (e.value as List<dynamic>)) Map<String, dynamic>.from(m as Map)],
      },
    );
  }
}

class MergeResult {
  const MergeResult({
    required this.merged,
    required this.vaultAdded,
    required this.scenariosAdded,
    required this.historyAdded,
    required this.cardsAdded,
    this.recordsAdded = 0,
  });

  final BackupContents merged;
  final int vaultAdded;
  final int scenariosAdded;
  final int historyAdded;
  final int cardsAdded;
  final int recordsAdded;
}

/// Adds what the backup has and this device lacks. Nothing on this device is removed.
/// Vault entries match by id; when both copies exist the newer one wins. Lists match by exact content.
MergeResult mergeBackups(BackupContents current, BackupContents incoming) {
  final byId = {for (final e in current.vault) e.id: e};
  var vaultAdded = 0;
  for (final e in incoming.vault) {
    final existing = byId[e.id];
    if (existing == null) {
      byId[e.id] = e;
      vaultAdded++;
    } else if (e.updatedAt.isAfter(existing.updatedAt)) {
      byId[e.id] = e;
    }
  }

  List<Map<String, dynamic>> addMissing(List<Map<String, dynamic>> base, List<Map<String, dynamic>> extra, List<int> counter, int slot) {
    final keys = base.map(jsonEncode).toSet();
    final out = [...base];
    for (final item in extra) {
      if (keys.add(jsonEncode(item))) {
        out.add(item);
        counter[slot]++;
      }
    }
    return out;
  }

  final counts = [0, 0];
  final scenarios = addMissing(current.loanScenarios, incoming.loanScenarios, counts, 0);
  final history = addMissing(current.calcHistory, incoming.calcHistory, counts, 1);

  // Cards: same rule as the vault. A newer backup copy replaces the device copy, but keeps the device's photo,
  // because backups do not carry photos.
  final cardById = {for (final c in current.cards) c.id: c};
  var cardsAdded = 0;
  for (final c in incoming.cards) {
    final existing = cardById[c.id];
    if (existing == null) {
      cardById[c.id] = c;
      cardsAdded++;
    } else if (c.updatedAt.isAfter(existing.updatedAt)) {
      cardById[c.id] = c.hasPhoto ? c : c.copyWith(photoBase64: existing.photoBase64, photoType: existing.photoType);
    }
  }
  final cards = cardById.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  final (records, recordsAdded) = mergeRecordLists(current.records, incoming.records);
  final vault = byId.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return MergeResult(
    merged: BackupContents(vault: vault, loanScenarios: scenarios, calcHistory: history, cards: cards, records: records),
    vaultAdded: vaultAdded,
    scenariosAdded: counts[0],
    historyAdded: counts[1],
    cardsAdded: cardsAdded,
    recordsAdded: recordsAdded,
  );
}

/// Encrypts a backup with a passphrase (PBKDF2-SHA256 key, AES-256-GCM). The result is plain text that can be
/// copied and pasted. Without the passphrase the content cannot be read.
class BackupCodec {
  static const _iterations = 120000;
  static final _random = Random.secure();

  static List<int> _bytes(int n) => List<int>.generate(n, (_) => _random.nextInt(256));

  static Future<SecretKey> _deriveKey(String passphrase, List<int> salt, int iterations) {
    return Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256)
        .deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  static Future<String> encrypt(BackupContents contents, String passphrase) async {
    final salt = _bytes(16);
    final nonce = _bytes(12);
    final key = await _deriveKey(passphrase, salt, _iterations);
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(contents.toJson())),
      secretKey: key,
      nonce: nonce,
    );
    final envelope = {
      'iterations': _iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'data': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
    return '$_backupPrefix${base64Encode(utf8.encode(jsonEncode(envelope)))}';
  }

  static Future<BackupContents> decrypt(String text, String passphrase) async {
    final trimmed = text.trim();
    if (!trimmed.startsWith(_backupPrefix)) throw const BackupException('This is not a MONOVA backup. Copy the whole text from the backup screen.');
    try {
      final env = jsonDecode(utf8.decode(base64Decode(trimmed.substring(_backupPrefix.length)))) as Map<String, dynamic>;
      final key = await _deriveKey(passphrase, base64Decode(env['salt'] as String), env['iterations'] as int);
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(
          base64Decode(env['data'] as String),
          nonce: base64Decode(env['nonce'] as String),
          mac: Mac(base64Decode(env['mac'] as String)),
        ),
        secretKey: key,
      );
      return BackupContents.fromJson(jsonDecode(utf8.decode(clear)) as Map<String, dynamic>);
    } on BackupException {
      rethrow;
    } catch (_) {
      // Wrong passphrase and damaged text look the same from outside, so the message covers both.
      throw const BackupException('Wrong passphrase, or the backup text was changed or cut short.');
    }
  }
}
