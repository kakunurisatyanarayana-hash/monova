import 'package:dio/dio.dart';

import '../local_store.dart';
import 'bullion_feed.dart';

/// What one refresh did, for the screen to report.
class RefreshReport {
  const RefreshReport({
    required this.updatedDatasets,
    required this.failedDatasets,
    required this.newPrices,
  });

  final List<String> updatedDatasets;
  final Map<String, String> failedDatasets;
  final int newPrices;

  bool get allOk => failedDatasets.isEmpty;
}

/// Fetches gold and silver benchmarks from snapdata.dev, keeps them on this phone, and serves them offline.
/// Only runs when the person opens Live Market and presses refresh. Nothing runs in the background.
class BullionRepository {
  BullionRepository({Dio? dio, DateTime Function()? now})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: snapdataBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'Accept': 'application/json',
                'User-Agent': 'MONOVA-app/1.0',
              },
            ),
          ),
      _now = now ?? DateTime.now;

  static const _pricesKey = 'monova.market.bullion';
  static const _syncKey = 'monova.market.sync';
  static const _attemptedKey = 'monova.market.attempted';

  /// Single-day downloads per dataset on each refresh. Two requests per day, so this keeps a refresh short.
  static const _backfillDaysPerRefresh = 30;

  final Dio _dio;
  final DateTime Function() _now;

  /// Every stored price, oldest first.
  Future<List<StoredPrice>> load() async {
    final store = await LocalStore.open();
    return [
      for (final m in store.readList(_pricesKey)) ?StoredPrice.fromJson(m),
    ];
  }

  /// When each dataset last refreshed successfully, and the last error if it failed.
  Future<Map<String, SyncState>> syncStates() async {
    final store = await LocalStore.open();
    final out = <String, SyncState>{};
    for (final m in store.readList(_syncKey)) {
      final dataset = '${m['dataset']}';
      out[dataset] = SyncState(
        lastSuccess: DateTime.tryParse('${m['lastSuccess']}'),
        lastError: m['lastError'] == null ? null : '${m['lastError']}',
      );
    }
    return out;
  }

  /// Fetches the latest day and the last 30 days for gold and silver. A failed dataset keeps its stored prices.
  Future<RefreshReport> refresh() async {
    final store = await LocalStore.open();
    final stored = [
      for (final m in store.readList(_pricesKey)) ?StoredPrice.fromJson(m),
    ];
    final syncs = await syncStates();
    final updated = <String>[];
    final failed = <String, String>{};
    final incoming = <StoredPrice>[];
    final now = _now();

    for (final dataset in const ['gold', 'silver']) {
      try {
        final latest = await _getFeed('/$dataset/in/latest.json');
        final series = await _getFeed('/$dataset/in/series/30d.json');
        final prices = [
          ...storedPricesFrom(latest, retrievedAt: now),
          ...storedPricesFrom(series, retrievedAt: now),
        ];
        incoming.addAll(prices);
        updated.add(dataset);
        syncs[dataset] = SyncState(lastSuccess: now, lastError: null);
      } on DioException catch (e) {
        final reason = _describe(e);
        failed[dataset] = reason;
        syncs[dataset] = SyncState(
          lastSuccess: syncs[dataset]?.lastSuccess,
          lastError: reason,
        );
      } on FormatException catch (e) {
        failed[dataset] =
            'The feed did not match the expected format (${e.message}).';
        syncs[dataset] = SyncState(
          lastSuccess: syncs[dataset]?.lastSuccess,
          lastError: failed[dataset],
        );
      }
    }

    // Older days, a few at a time, so previous months fill in over successive refreshes.
    final attempted = {
      for (final m in store.readList(_attemptedKey)) '${m['k']}',
    };
    final today = DateTime(now.year, now.month, now.day);
    final newlyAttempted = <String>[];
    for (final dataset in const ['gold', 'silver']) {
      if (failed.containsKey(dataset)) continue;
      final days = datesToBackfill(
        dataset: dataset,
        today: today.subtract(const Duration(days: 1)),
        attempted: attempted,
        limit: _backfillDaysPerRefresh,
      );
      for (final day in days) {
        try {
          final feed = await _getFeed('/$dataset/in/${dayKey(day)}.json');
          incoming.addAll(storedPricesFrom(feed, retrievedAt: now));
          newlyAttempted.add('$dataset|${dayKey(day)}');
        } on DioException {
          // A dropped connection or a server error stops the catch-up now; the days not tried stay for next time.
          break;
        } on FormatException {
          // A day the feed does not answer in the expected form is recorded as tried, not retried forever.
          newlyAttempted.add('$dataset|${dayKey(day)}');
        }
      }
    }
    final merged = mergeStoredPrices(stored, incoming);
    await store.writeList(_attemptedKey, [
      for (final k in {...attempted, ...newlyAttempted}) {'k': k},
    ]);
    await store.writeList(_pricesKey, [for (final p in merged) p.toJson()]);
    await store.writeList(_syncKey, [
      for (final e in syncs.entries)
        {
          'dataset': e.key,
          'lastSuccess': e.value.lastSuccess?.toUtc().toIso8601String(),
          'lastError': e.value.lastError,
        },
    ]);
    return RefreshReport(
      updatedDatasets: updated,
      failedDatasets: failed,
      newPrices: incoming.length,
    );
  }

  /// True while older days still have to be downloaded for gold or silver.
  Future<bool> historyPending() async {
    final store = await LocalStore.open();
    final attempted = {
      for (final m in store.readList(_attemptedKey)) '${m['k']}',
    };
    final now = _now();
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    for (final dataset in const ['gold', 'silver']) {
      if (datesToBackfill(
        dataset: dataset,
        today: yesterday,
        attempted: attempted,
        limit: 1,
      ).isNotEmpty)
        return true;
    }
    return false;
  }

  /// One request, with a single retry after a short pause for a dropped connection.
  Future<BullionFeed> _getFeed(String path) async {
    Object? last;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final r = await _dio.get<dynamic>(path);
        final data = r.data;
        if (data is! Map<String, dynamic>)
          throw const FormatException('not a JSON object');
        return parseBullionFeed(data);
      } on DioException catch (e) {
        last = e;
        // Retry only when the connection itself failed, not for an error the server returned on purpose.
        final retryable =
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;
        if (!retryable || attempt == 1) rethrow;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    throw last ?? const FormatException('no response');
  }

  String _describe(DioException e) {
    final code = e.response?.statusCode;
    if (code != null)
      return 'The source answered with status $code. Try again later.';
    return switch (e.type) {
      DioExceptionType.connectionTimeout || DioExceptionType.receiveTimeout => 'The source took too long to answer. Check the connection and try again.',
      DioExceptionType.connectionError =>
        'No internet connection, or the source could not be reached.',
      _ => 'The source could not be read. Try again later.',
    };
  }
}

class SyncState {
  const SyncState({required this.lastSuccess, required this.lastError});

  /// The last time this dataset refreshed successfully, in UTC.
  final DateTime? lastSuccess;
  final String? lastError;
}
