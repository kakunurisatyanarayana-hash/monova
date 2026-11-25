import '../core/api_client.dart';
import 'models.dart';

String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Every backend call the app makes. Screens depend on this class, so tests can replace it with a fake.
class FinanceRepository {
  FinanceRepository(this._api);

  final ApiClient _api;

  // ----- auth -----
  Future<AuthSession> login(String email, String password) async =>
      AuthSession.fromJson((await _api.post('/api/v1/auth/login', body: {'email': email, 'password': password})).asMap);

  Future<AuthSession> register(String email, String displayName, String password) async => AuthSession.fromJson(
      (await _api.post('/api/v1/auth/register', body: {'email': email, 'displayName': displayName, 'password': password})).asMap);

  Future<OtpChallengeResult> requestOtp(String phoneNumber) async => OtpChallengeResult.fromJson(
      (await _api.post('/api/v1/auth/otp/request', body: {'phoneNumber': phoneNumber})).asMap);

  /// New mobile numbers need a name to create the account; existing numbers sign in with the code alone.
  Future<AuthSession> verifyOtp(String phoneNumber, String code, {String? displayName}) async => AuthSession.fromJson(
      (await _api.post('/api/v1/auth/otp/verify', body: {
        'phoneNumber': phoneNumber,
        'code': code,
        'displayName': displayName,
      })).asMap);

  Future<void> logout(String refreshToken) => _api.post('/api/v1/auth/logout', body: {'refreshToken': refreshToken});

  Future<UserProfile> me() async => UserProfile.fromJson((await _api.get('/api/v1/auth/me')).asMap);

  // ----- dashboard and reports -----
  Future<Dashboard> dashboard() async => Dashboard.fromJson((await _api.get('/api/v1/dashboard')).asMap);

  Future<MonthlyReport> monthlyReport(int year, int month) async =>
      MonthlyReport.fromJson((await _api.get('/api/v1/reports/monthly', query: {'year': year, 'month': month})).asMap);

  Future<List<NetWorthPoint>> netWorthHistory({int months = 12}) async =>
      (await _api.get('/api/v1/reports/net-worth/history', query: {'months': months})).asList
          .map((e) => NetWorthPoint.fromJson(e as Map<String, dynamic>))
          .toList();

  // ----- accounts and transfers -----
  Future<List<AccountItem>> accounts({bool includeInactive = false}) async =>
      (await _api.get('/api/v1/accounts', query: {'includeInactive': includeInactive})).asList
          .map((e) => AccountItem.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<AccountItem> createAccount({
    required String name,
    required String bankName,
    required String type,
    required double openingBalance,
  }) async =>
      AccountItem.fromJson((await _api.post('/api/v1/accounts', body: {
        'name': name,
        'bankName': bankName,
        'type': type,
        'openingBalance': openingBalance,
      })).asMap);

  Future<PagedResult<AccountMovement>> accountHistory(String id, {int page = 1}) async => PagedResult.parse(
      await _api.get('/api/v1/accounts/$id/history', query: {'page': page, 'pageSize': 50}), AccountMovement.fromJson);

  Future<void> transfer({required String from, required String to, required double amount, required DateTime on, String? note}) =>
      _api.post('/api/v1/transfers', body: {
        'fromAccountId': from,
        'toAccountId': to,
        'amount': amount,
        'occurredOn': ymd(on),
        'note': note,
      });

  // ----- transactions and categories -----
  Future<PagedResult<TransactionItem>> transactions({int page = 1, String? search, String? type, String? accountId}) async =>
      PagedResult.parse(
        await _api.get('/api/v1/transactions', query: {
          'page': page,
          'pageSize': 30,
          if (search != null && search.isNotEmpty) 'search': search,
          if (type != null) 'type': type,
          if (accountId != null) 'accountId': accountId,
        }),
        TransactionItem.fromJson,
      );

  Future<TransactionItem> addTransaction({
    required String type,
    required double amount,
    required DateTime on,
    required String title,
    String? note,
    String? categoryId,
    String? accountId,
    String? cardId,
  }) async =>
      TransactionItem.fromJson((await _api.post('/api/v1/transactions', body: {
        'type': type,
        'amount': amount,
        'occurredOn': ymd(on),
        'title': title,
        'note': note,
        'categoryId': categoryId,
        'accountId': accountId,
        'creditCardId': cardId,
      })).asMap);

  Future<void> deleteTransaction(String id) => _api.delete('/api/v1/transactions/$id');

  Future<TransactionItem> refund(String originalId, double amount, {DateTime? on, String? note}) async =>
      TransactionItem.fromJson((await _api.post('/api/v1/transactions/refunds', body: {
        'originalTransactionId': originalId,
        'amount': amount,
        'occurredOn': ymd(on ?? DateTime.now()),
        'note': note,
      })).asMap);

  // ----- recurring entries -----
  Future<List<RecurringItem>> recurring() async =>
      (await _api.get('/api/v1/recurring')).asList.map((e) => RecurringItem.fromJson(e as Map<String, dynamic>)).toList();

  Future<void> addRecurring({
    required String type,
    required double amount,
    required String title,
    required String frequency,
    required DateTime startOn,
    required String accountId,
  }) =>
      _api.post('/api/v1/recurring', body: {
        'type': type,
        'amount': amount,
        'title': title,
        'categoryId': null,
        'accountId': accountId,
        'creditCardId': null,
        'frequency': frequency,
        'startOn': ymd(startOn),
      });

  Future<void> setRecurringActive(String id, {required bool active}) =>
      _api.post('/api/v1/recurring/$id/${active ? 'activate' : 'deactivate'}');

  /// Creates every entry that is due today or earlier. Safe to press more than once.
  Future<int> runDueRecurring() async {
    final body = (await _api.post('/api/v1/recurring/run-due')).asMap;
    return (body['created'] as num?)?.toInt() ?? 0;
  }

  Future<List<CategoryItem>> categories({String? kind}) async =>
      (await _api.get('/api/v1/categories', query: {if (kind != null) 'kind': kind})).asList
          .map((e) => CategoryItem.fromJson(e as Map<String, dynamic>))
          .toList();

  // ----- credit cards -----
  Future<List<CardItem>> cards() async =>
      (await _api.get('/api/v1/credit-cards')).asList.map((e) => CardItem.fromJson(e as Map<String, dynamic>)).toList();

  Future<CardItem> addCard({
    required String issuer,
    required String name,
    required String last4,
    required double limit,
    required int statementDay,
    required int dueDay,
  }) async =>
      CardItem.fromJson((await _api.post('/api/v1/credit-cards', body: {
        'issuer': issuer,
        'name': name,
        'last4': last4,
        'creditLimit': limit,
        'statementDay': statementDay,
        'dueDay': dueDay,
      })).asMap);

  Future<void> payCard(String cardId, {required String fromAccountId, required double amount, DateTime? on, String? note}) =>
      _api.post('/api/v1/credit-cards/$cardId/payments', body: {
        'fromAccountId': fromAccountId,
        'amount': amount,
        'paidOn': ymd(on ?? DateTime.now()),
        'note': note,
      });

  // ----- lending and borrowing -----
  Future<List<DebtItem>> debts() async =>
      (await _api.get('/api/v1/debts')).asList.map((e) => DebtItem.fromJson(e as Map<String, dynamic>)).toList();

  Future<DebtItem> addDebt({
    required String counterparty,
    required double principal,
    required double annualRate,
    required DateTime borrowedOn,
    required String accountId,
    DateTime? dueOn,
    String? note,
  }) async =>
      DebtItem.fromJson((await _api.post('/api/v1/debts', body: {
        'counterparty': counterparty,
        'principal': principal,
        'annualInterestRatePercent': annualRate,
        'borrowedOn': ymd(borrowedOn),
        'dueOn': dueOn == null ? null : ymd(dueOn),
        'accountId': accountId,
        'note': note,
      })).asMap);

  Future<void> repayDebt(String id, {required double amount, required String accountId, DateTime? on}) =>
      _api.post('/api/v1/debts/$id/repayments', body: {
        'amount': amount,
        'paidOn': ymd(on ?? DateTime.now()),
        'accountId': accountId,
      });

  Future<List<ReceivableItem>> receivables() async =>
      (await _api.get('/api/v1/receivables')).asList.map((e) => ReceivableItem.fromJson(e as Map<String, dynamic>)).toList();

  Future<ReceivableItem> addReceivable({
    required String counterparty,
    required double principal,
    required DateTime lentOn,
    required String accountId,
    DateTime? expectedOn,
    String? note,
  }) async =>
      ReceivableItem.fromJson((await _api.post('/api/v1/receivables', body: {
        'counterparty': counterparty,
        'principal': principal,
        'lentOn': ymd(lentOn),
        'expectedOn': expectedOn == null ? null : ymd(expectedOn),
        'accountId': accountId,
        'note': note,
      })).asMap);

  Future<void> collect(String id, {required double amount, required String accountId, DateTime? on}) =>
      _api.post('/api/v1/receivables/$id/collections', body: {
        'amount': amount,
        'receivedOn': ymd(on ?? DateTime.now()),
        'accountId': accountId,
      });

  // ----- loans and EMI -----
  Future<List<LoanItem>> loans() async =>
      (await _api.get('/api/v1/loans')).asList.map((e) => LoanItem.fromJson(e as Map<String, dynamic>)).toList();

  Future<LoanItem> addLoan({
    required String name,
    required String lender,
    required double principal,
    required double annualRate,
    required int termMonths,
    required DateTime startOn,
    required String accountId,
  }) async =>
      LoanItem.fromJson((await _api.post('/api/v1/loans', body: {
        'name': name,
        'lender': lender,
        'principal': principal,
        'annualInterestRatePercent': annualRate,
        'termMonths': termMonths,
        'startOn': ymd(startOn),
        'accountId': accountId,
      })).asMap);

  Future<LoanItem> payInstallment(String loanId, int number, {required String accountId, DateTime? on}) async =>
      LoanItem.fromJson((await _api.post('/api/v1/loans/$loanId/installments/$number/pay', body: {
        'accountId': accountId,
        'paidOn': ymd(on ?? DateTime.now()),
      })).asMap);

  // ----- budgets and savings -----
  Future<BudgetSummary> budget(int year, int month) async =>
      BudgetSummary.fromJson((await _api.get('/api/v1/budgets', query: {'year': year, 'month': month})).asMap);

  Future<BudgetSummary> setBudget(int year, int month, double amount, {String? categoryId}) async =>
      BudgetSummary.fromJson((await _api.put('/api/v1/budgets', body: {
        'year': year,
        'month': month,
        'categoryId': categoryId,
        'amount': amount,
      })).asMap);

  Future<List<GoalItem>> goals() async =>
      (await _api.get('/api/v1/savings-goals')).asList.map((e) => GoalItem.fromJson(e as Map<String, dynamic>)).toList();

  Future<GoalItem> addGoal({required String name, required double target, DateTime? targetDate}) async =>
      GoalItem.fromJson((await _api.post('/api/v1/savings-goals', body: {
        'name': name,
        'targetAmount': target,
        'targetDate': targetDate == null ? null : ymd(targetDate),
      })).asMap);

  Future<GoalItem> contribute(String goalId, {required String accountId, required double amount, DateTime? on}) async =>
      GoalItem.fromJson((await _api.post('/api/v1/savings-goals/$goalId/contributions', body: {
        'accountId': accountId,
        'amount': amount,
        'occurredOn': ymd(on ?? DateTime.now()),
      })).asMap);

  // ----- groups -----
  Future<List<GroupSummary>> groups() async =>
      (await _api.get('/api/v1/groups')).asList.map((e) => GroupSummary.fromJson(e as Map<String, dynamic>)).toList();

  Future<GroupDetail> createGroup(String name, {String? emoji}) async =>
      GroupDetail.fromJson((await _api.post('/api/v1/groups', body: {'name': name, 'emoji': emoji})).asMap);

  Future<GroupDetail> group(String id) async => GroupDetail.fromJson((await _api.get('/api/v1/groups/$id')).asMap);

  Future<void> addMember(String groupId, String name) => _api.post('/api/v1/groups/$groupId/members', body: {'displayName': name});

  Future<PagedResult<GroupExpenseItem>> groupExpenses(String groupId) async => PagedResult.parse(
      await _api.get('/api/v1/groups/$groupId/expenses', query: {'pageSize': 50}), GroupExpenseItem.fromJson);

  Future<void> addGroupExpense(String groupId, Map<String, dynamic> body) => _api.post('/api/v1/groups/$groupId/expenses', body: body);

  Future<void> deleteGroupExpense(String groupId, String expenseId) => _api.delete('/api/v1/groups/$groupId/expenses/$expenseId');

  Future<GroupBalances> groupBalances(String groupId) async =>
      GroupBalances.fromJson((await _api.get('/api/v1/groups/$groupId/balances')).asMap);

  Future<void> settle(String groupId, {required String from, required String to, required double amount, required String accountId, String? note}) =>
      _api.post('/api/v1/groups/$groupId/settlements', body: {
        'fromMemberId': from,
        'toMemberId': to,
        'amount': amount,
        'settledOn': ymd(DateTime.now()),
        'accountId': accountId,
        'note': note,
      });
}
