import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/api_client.dart';
import 'package:monova_app/data/finance_repository.dart';

/// Answers every request with a canned JSON body, so the real ApiClient and repository run without a server.
Dio _fakeDio(Map<String, dynamic> Function(RequestOptions) respond, {int status = 200}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    handler.resolve(Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: respond(options),
    ));
  }));
  return dio;
}

void main() {
  test('register parses the session returned by the server', () async {
    final dio = _fakeDio((o) => {
          'accessToken': 'a-token',
          'accessTokenExpiresAtUtc': '2026-11-25T10:00:00Z',
          'refreshToken': 'r-token',
          'refreshTokenExpiresAtUtc': '2026-12-25T10:00:00Z',
          'user': {'id': 'u1', 'email': 'asha@monova.test', 'displayName': 'Asha', 'baseCurrency': 'INR'},
        });
    final repo = FinanceRepository(ApiClient(tokens: MemoryTokenStore(), dio: dio));

    final session = await repo.register('asha@monova.test', 'Asha', 'Passw0rd1');

    expect(session.accessToken, 'a-token');
    expect(session.refreshToken, 'r-token');
    expect(session.user.displayName, 'Asha');
  });

  test('list endpoints return typed items', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: [
          {'id': 'a1', 'name': 'Salary', 'bankName': 'HDFC', 'type': 'Bank', 'openingBalance': 50000, 'currentBalance': 165000, 'isActive': true}
        ],
      ));
    }));
    final repo = FinanceRepository(ApiClient(tokens: MemoryTokenStore(), dio: dio));
    final accounts = await repo.accounts();
    expect(accounts.single.currentBalance, 165000);
  });

  test('a rejected request becomes an ApiException with the server message', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: 401,
          data: {'title': 'Unauthorized', 'detail': 'Invalid email or password.'},
        ),
      ));
    }));
    final client = ApiClient(tokens: MemoryTokenStore(), dio: dio);
    await expectLater(
      client.post('/api/v1/auth/login', body: {}),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Invalid email or password.')),
    );
  });
}
