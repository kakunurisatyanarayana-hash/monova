import 'package:dio/dio.dart';

import 'event_sanitizer.dart';
import 'local_store.dart';
import 'test_backend.dart';

/// Events from every module, kept on the phone first (offline-first), then sent to the test server when it is connected.
/// Each event is cleaned by [sanitizeEventFields] before it is saved, so personal details are never queued.
const outboxKey = 'monova.outbox';

class AppEvents {
  AppEvents._();

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  /// Saves one event on the phone. Nothing is sent here.
  static Future<void> add(String type, Map<String, Object?> fields) async {
    final store = await LocalStore.open();
    final list = store.readList(outboxKey);
    list.add({
      'type': type,
      'at': DateTime.now().toUtc().toIso8601String(),
      'fields': sanitizeEventFields(fields),
    });
    // Keep the latest 2000 events on the phone, so storage stays small.
    await store.writeList(
      outboxKey,
      list.length > 2000 ? list.sublist(list.length - 2000) : list,
    );
  }

  /// How many events are waiting on the phone.
  static Future<int> pending() async =>
      (await LocalStore.open()).readList(outboxKey).length;

  /// Sends waiting events to the test server, oldest first. Sent events are removed; the rest stay for next time.
  /// Returns a short message for the screen.
  static Future<String> flush() async {
    if (!testBackendEnabled)
      return 'The test server is not set up in this build. Events stay on the phone.';
    final store = await LocalStore.open();
    final waiting = store.readList(outboxKey);
    if (waiting.isEmpty) return 'Nothing waiting to send.';
    var sent = 0;
    final left = <Map<String, dynamic>>[];
    for (final event in waiting) {
      try {
        await _dio.post<dynamic>(
          '$testBackendUrl/events',
          data: event,
          options: Options(headers: {'x-test-token': testBackendToken}),
        );
        sent++;
      } on DioException {
        left.add(event);
      }
    }
    await store.writeList(outboxKey, left);
    return left.isEmpty
        ? 'Sent $sent events to the test server.'
        : 'Sent $sent. ${left.length} waiting for the next connection.';
  }
}
