import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VaultKind { password, note }

extension VaultKindLabel on VaultKind {
  String get label => switch (this) {
        VaultKind.password => 'Password',
        VaultKind.note => 'Note',
      };
}

/// One saved item: a login (username, password, website) or a free note.
class VaultEntry {
  const VaultEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.updatedAt,
    this.username = '',
    this.password = '',
    this.url = '',
    this.notes = '',
  });

  final String id;
  final VaultKind kind;
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;
  final DateTime updatedAt;

  VaultEntry copyWith({
    VaultKind? kind,
    String? title,
    String? username,
    String? password,
    String? url,
    String? notes,
    DateTime? updatedAt,
  }) {
    return VaultEntry(
      id: id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Text shown under the title in the list: the username for logins, the start of the note otherwise.
  String get preview {
    if (kind == VaultKind.password && username.isNotEmpty) return username;
    final firstLine = notes.trim().split('\n').first;
    return firstLine.isEmpty ? (url.isEmpty ? 'No details' : url) : firstLine;
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [title, username, url, notes].any((field) => field.toLowerCase().contains(q));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'username': username,
        'password': password,
        'url': url,
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory VaultEntry.fromJson(Map<String, dynamic> j) {
    final kindName = j['kind'] as String?;
    return VaultEntry(
      id: '${j['id']}',
      kind: VaultKind.values.firstWhere((k) => k.name == kindName, orElse: () => VaultKind.note),
      title: '${j['title'] ?? ''}',
      username: '${j['username'] ?? ''}',
      password: '${j['password'] ?? ''}',
      url: '${j['url'] ?? ''}',
      notes: '${j['notes'] ?? ''}',
      updatedAt: DateTime.tryParse('${j['updatedAt']}') ?? DateTime.now(),
    );
  }
}

/// Keeps the vault on this device only. On phones the JSON sits in the platform secure storage
/// (Android Keystore / iOS Keychain). Web browsers have no equivalent, so the web build stores it
/// in plain browser storage and the screen says so.
class VaultStore {
  VaultStore._();

  static const _key = 'monova.vault';
  static const _secure = FlutterSecureStorage();

  /// True when the data is protected by the device's secure storage.
  static bool get encrypted => !kIsWeb;

  static Future<List<VaultEntry>> load() async {
    final raw = kIsWeb
        ? (await SharedPreferences.getInstance()).getString(_key)
        : await _secure.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final entries = list.map((e) => VaultEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return entries;
    } catch (_) {
      // A damaged vault is treated as empty rather than crashing the app.
      return [];
    }
  }

  static Future<void> save(List<VaultEntry> entries) async {
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    if (kIsWeb) {
      await (await SharedPreferences.getInstance()).setString(_key, raw);
    } else {
      await _secure.write(key: _key, value: raw);
    }
  }
}
