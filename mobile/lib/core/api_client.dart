import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Base URL of the local API. 10.0.2.2 reaches the PC from the Android emulator; override with --dart-define=MONOVA_API=...
class ApiConfig {
  /// Matches the "http" launch profile of Monova.API (http://localhost:5199).
  static const baseUrl = String.fromEnvironment(
    'MONOVA_API',
    defaultValue: 'http://10.0.2.2:5199',
  );

  /// Offline build (--dart-define=MONOVA_OFFLINE=true): tools only. No sign-in, no server calls, no database.
  static const offline = bool.fromEnvironment('MONOVA_OFFLINE');
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message, {this.errors});

  final int statusCode;
  final String message;
  final Map<String, dynamic>? errors;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Stores the JWT pair. Secure storage on devices; memory in tests.
abstract class TokenStore {
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> save({required String access, required String refresh});
  Future<void> clear();
}

class MemoryTokenStore implements TokenStore {
  String? _access;
  String? _refresh;

  @override
  Future<String?> readAccess() async => _access;

  @override
  Future<String?> readRefresh() async => _refresh;

  @override
  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccess() => _storage.read(key: 'monova.access');

  @override
  Future<String?> readRefresh() => _storage.read(key: 'monova.refresh');

  @override
  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: 'monova.access', value: access);
    await _storage.write(key: 'monova.refresh', value: refresh);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: 'monova.access');
    await _storage.delete(key: 'monova.refresh');
  }
}

/// Thin Dio wrapper. Adds the bearer token, refreshes once on 401 (single-flight) and maps ProblemDetails to ApiException.
class ApiClient {
  ApiClient({required TokenStore tokens, String? baseUrl, Dio? dio})
    : _tokens = tokens,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              contentType: 'application/json',
            ),
          );

  final TokenStore _tokens;
  final Dio _dio;
  Future<bool>? _refreshing;
  void Function()? onSessionExpired;

  // Object? (not dynamic) so the .asMap / .asList helpers below resolve statically.
  Future<Object?> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<Object?> post(String path, {Object? body}) =>
      _send(() => _dio.post(path, data: body));

  Future<Object?> put(String path, {Object? body}) =>
      _send(() => _dio.put(path, data: body));

  Future<void> delete(String path) async {
    await _send(() => _dio.delete(path));
  }

  Future<Object?> _send(
    Future<Response<dynamic>> Function() call, {
    bool retried = false,
  }) async {
    final token = await _tokens.readAccess();
    try {
      final response = await _withAuth(call, token);
      return response.data;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 401 && !retried && await _refreshOnce()) {
        return _send(call, retried: true);
      }
      if (status == 401) {
        await _tokens.clear();
        onSessionExpired?.call();
      }
      throw _toApiException(e);
    }
  }

  /// Sets the bearer header for this call. Requests are sequential per screen, so one shared header is sufficient for the MVP.
  Future<Response<dynamic>> _withAuth(
    Future<Response<dynamic>> Function() call,
    String? token,
  ) async {
    if (token == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
    return call();
  }

  /// Exchanges the refresh token for a new pair. Concurrent 401s share one refresh call.
  Future<bool> _refreshOnce() {
    return _refreshing ??= () async {
      try {
        final refresh = await _tokens.readRefresh();
        if (refresh == null) return false;
        final response = await _dio.post(
          '/api/v1/auth/refresh',
          data: {'refreshToken': refresh},
        );
        final data = response.data as Map<String, dynamic>;
        await _tokens.save(
          access: data['accessToken'] as String,
          refresh: data['refreshToken'] as String,
        );
        return true;
      } catch (_) {
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }

  ApiException _toApiException(DioException e) {
    final status = e.response?.statusCode ?? 0;
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final detail =
          data['detail'] as String? ??
          data['title'] as String? ??
          'Request failed.';
      final errors = data['errors'] as Map<String, dynamic>?;
      return ApiException(status, detail, errors: errors);
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const ApiException(
        0,
        'Cannot reach the MONOVA server. Check that the API is running and the address is correct.',
      );
    }
    return ApiException(status, 'Something went wrong. Please try again.');
  }
}

extension DynamicMap on Object? {
  Map<String, dynamic> get asMap => this as Map<String, dynamic>;
  List<dynamic> get asList => (this as List<dynamic>?) ?? const [];
}
