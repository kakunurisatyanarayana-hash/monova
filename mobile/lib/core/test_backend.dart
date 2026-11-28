import 'package:dio/dio.dart';

/// Test server connection. Only used in test builds, set at build time:
///   --dart-define=TEST_BACKEND_URL=https://monova.onrender.com
///   --dart-define=TEST_BACKEND_TOKEN=<the test token>
/// Without both values the connection is off, and the app works fully offline.
/// The token is visible inside a test build, so use it for test data only.
const testBackendUrl = String.fromEnvironment('TEST_BACKEND_URL');
const testBackendToken = String.fromEnvironment('TEST_BACKEND_TOKEN');

bool get testBackendEnabled =>
    testBackendUrl.isNotEmpty && testBackendToken.isNotEmpty;

class TestBackend {
  TestBackend._();

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  /// Checks the server answers. Returns a short message for the screen.
  static Future<String> checkConnection() async {
    if (!testBackendEnabled)
      return 'The test server is not set up in this build.';
    try {
      final r = await _dio.get<Map<String, dynamic>>('$testBackendUrl/health');
      final data = r.data ?? const {};
      return data['ok'] == true
          ? 'Connected. Events waiting on the server: ${data['queued']}.'
          : 'The server answered, but not with an OK status.';
    } on DioException catch (e) {
      return 'Could not reach the test server (${e.message ?? e.type.name}). The free server may be waking up. Try again in a minute.';
    }
  }

  /// Sends one event with made-up text only. No customer, phone or money record is included.
  static Future<String> sendTestEvent() async {
    if (!testBackendEnabled)
      return 'The test server is not set up in this build.';
    try {
      await _dio.post<dynamic>(
        '$testBackendUrl/events',
        data: {
          'type': 'app.test',
          'note': 'Test event with made-up text only',
          'sentAt': DateTime.now().toUtc().toIso8601String(),
        },
        options: Options(headers: {'x-test-token': testBackendToken}),
      );
      return 'Test event sent and queued on the server.';
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      return code == 401
          ? 'The test token was refused. Check the build settings.'
          : 'Could not send the test event (${e.message ?? e.type.name}).';
    }
  }
}
