import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../local_store.dart';
import 'mandi_feed.dart';

/// Mandi prices from data.gov.in. The free API key is typed in by the person and kept in this phone's
/// secure storage. It is never written into the app, so it does not ship in the APK.
class MandiRepository {
  MandiRepository({Dio? dio, FlutterSecureStorage? secure})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: mandiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Accept': 'application/json', 'User-Agent': 'MONOVA-app/1.0'},
            )),
        _secure = secure ?? const FlutterSecureStorage();

  static const _keyName = 'monova.market.datagovKey';
  static const _recordsKey = 'monova.market.mandi';
  static const _fetchedKey = 'monova.market.mandiFetched';
  static const _pageSize = 100;
  static const _maxPages = 3;

  final Dio _dio;
  final FlutterSecureStorage _secure;

  Future<bool> hasKey() async => (await _secure.read(key: _keyName))?.isNotEmpty == true;

  Future<void> saveKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await _secure.delete(key: _keyName);
    } else {
      await _secure.write(key: _keyName, value: trimmed);
    }
  }

  Future<void> removeKey() => _secure.delete(key: _keyName);

  /// When mandi prices were last fetched successfully, in UTC. Null when never.
  Future<DateTime?> lastFetched() async {
    final store = await LocalStore.open();
    final list = store.readList(_fetchedKey);
    if (list.isEmpty) return null;
    return DateTime.tryParse('${list.first['at']}');
  }

  /// Records already stored, newest first, optionally limited to one state or commodity.
  Future<List<MandiRecord>> load({String? state, String? commodity}) async {
    final store = await LocalStore.open();
    final all = [for (final m in store.readList(_recordsKey)) ?MandiRecord.fromJson(m)];
    return all.where((r) {
      if (state != null && state.isNotEmpty && r.state.toLowerCase() != state.toLowerCase()) return false;
      if (commodity != null && commodity.isNotEmpty && !r.commodity.toLowerCase().contains(commodity.toLowerCase())) return false;
      return true;
    }).toList();
  }

  /// Fetches up to three pages for a state and commodity, then stores them. Returns how many rows were read.
  /// Throws a [MandiException] with a message the screen can show.
  Future<int> fetch({required String state, required String commodity}) async {
    // data.gov.in does not allow browser pages to read its answers, so the web build cannot fetch mandi prices.
    if (kIsWeb) {
      throw const MandiException('Mandi prices work in the Android app. Browsers are not allowed to read data.gov.in, so the web version cannot fetch them.');
    }
    final key = await _secure.read(key: _keyName);
    if (key == null || key.isEmpty) {
      throw const MandiException('Add your free data.gov.in API key first. It stays on this phone.');
    }
    final fetched = <MandiRecord>[];
    for (var page = 0; page < _maxPages; page++) {
      final rows = await _page(key, state: state, commodity: commodity, offset: page * _pageSize);
      fetched.addAll(rows);
      if (rows.length < _pageSize) break;
    }
    final store = await LocalStore.open();
    final stored = [for (final m in store.readList(_recordsKey)) ?MandiRecord.fromJson(m)];
    final merged = mergeMandi(stored, fetched);
    await store.writeList(_recordsKey, [for (final r in merged) r.toJson()]);
    await store.writeList(_fetchedKey, [
      {'at': DateTime.now().toUtc().toIso8601String()},
    ]);
    return fetched.length;
  }

  Future<List<MandiRecord>> _page(String key, {required String state, required String commodity, required int offset}) async {
    try {
      final r = await _dio.get<dynamic>('', queryParameters: {
        'api-key': key,
        'format': 'json',
        'limit': _pageSize,
        'offset': offset,
        if (state.isNotEmpty) 'filters[state]': state,
        if (commodity.isNotEmpty) 'filters[commodity]': commodity,
      });
      final data = r.data;
      if (data is! Map<String, dynamic>) throw const MandiException('The source sent an unexpected answer.');
      return parseMandiPage(data);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 403 || code == 401) {
        throw const MandiException('The data.gov.in key was not accepted. Check it in your data.gov.in account.');
      }
      if (code == 429) {
        throw const MandiException('The data.gov.in limit was reached for today. Try again later.');
      }
      throw const MandiException('The mandi prices could not be fetched. Check the connection and try again.');
    }
  }
}

class MandiException implements Exception {
  const MandiException(this.message);

  final String message;

  @override
  String toString() => message;
}
