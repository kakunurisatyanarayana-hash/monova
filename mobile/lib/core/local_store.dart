import 'data_revision.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Keeps small lists of records on the device (saved loan scenarios, calculator history).
/// Nothing is sent to a server. Data stays on this phone until the app data is cleared or the app is uninstalled.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  List<Map<String, dynamic>> readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      // A damaged entry is ignored rather than crashing the calculator.
      return [];
    }
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> items) async {
    await _prefs.setString(key, jsonEncode(items));
    markDataChanged();
  }
}
