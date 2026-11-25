import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../data/finance_repository.dart';
import '../data/models.dart';

/// Secure storage on phones (Keystore). Browsers have no keystore plugin support here, so web keeps the session in memory until reload.
final tokenStoreProvider = Provider<TokenStore>((ref) => kIsWeb ? MemoryTokenStore() : SecureTokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(tokens: ref.watch(tokenStoreProvider));
  client.onSessionExpired = () => ref.read(sessionProvider.notifier).expire();
  return client;
});

final repositoryProvider = Provider<FinanceRepository>((ref) => FinanceRepository(ref.watch(apiClientProvider)));

/// unknown: still restoring. guest: the app works with offline tools; server features ask to sign in. authenticated: full access.
enum SessionStatus { unknown, guest, authenticated }

class SessionState {
  const SessionState({required this.status, this.user});

  final SessionStatus status;
  final UserProfile? user;

  bool get isSignedIn => status == SessionStatus.authenticated;

  SessionState copyWith({SessionStatus? status, UserProfile? user}) =>
      SessionState(status: status ?? this.status, user: user ?? this.user);
}

/// Owns login state. Login is optional: guests can use every offline tool.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    // Restored once, when the app starts, whichever page was opened first. Calling it twice could rotate the refresh token twice.
    Future.microtask(restore);
    return const SessionState(status: SessionStatus.unknown);
  }

  Future<void> restore() async {
    if (ApiConfig.offline) {
      // Offline build: never touch the server or stored tokens.
      state = const SessionState(status: SessionStatus.guest);
      return;
    }
    final tokens = ref.read(tokenStoreProvider);
    final access = await tokens.readAccess();
    if (access == null) {
      state = const SessionState(status: SessionStatus.guest);
      return;
    }
    try {
      final me = await ref.read(repositoryProvider).me();
      state = SessionState(status: SessionStatus.authenticated, user: me);
    } catch (_) {
      await tokens.clear();
      state = const SessionState(status: SessionStatus.guest);
    }
  }

  Future<void> login(String email, String password) async {
    final session = await ref.read(repositoryProvider).login(email, password);
    await _store(session);
  }

  Future<void> verifyOtp(String phoneNumber, String code, {String? displayName}) async {
    final session = await ref.read(repositoryProvider).verifyOtp(phoneNumber, code, displayName: displayName);
    await _store(session);
  }

  Future<void> register(String email, String displayName, String password) async {
    final session = await ref.read(repositoryProvider).register(email, displayName, password);
    await _store(session);
  }

  Future<void> logout() async {
    final tokens = ref.read(tokenStoreProvider);
    final refresh = await tokens.readRefresh();
    if (refresh != null) {
      try {
        await ref.read(repositoryProvider).logout(refresh);
      } catch (_) {
        // Signing out locally must work even when the server is unreachable.
      }
    }
    await tokens.clear();
    _clearCaches();
    state = const SessionState(status: SessionStatus.guest);
  }

  /// Called when the server rejects the session. The user drops back to guest mode, not to a login wall.
  void expire() {
    _clearCaches();
    state = const SessionState(status: SessionStatus.guest);
  }

  Future<void> _store(AuthSession session) async {
    await ref.read(tokenStoreProvider).save(access: session.accessToken, refresh: session.refreshToken);
    _clearCaches();
    state = SessionState(status: SessionStatus.authenticated, user: session.user);
  }

  void _clearCaches() {
    ref.invalidate(dashboardProvider);
    ref.invalidate(accountsProvider);
    ref.invalidate(cardsProvider);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

final dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) => ref.watch(repositoryProvider).dashboard());
final accountsProvider = FutureProvider.autoDispose<List<AccountItem>>((ref) => ref.watch(repositoryProvider).accounts());
final cardsProvider = FutureProvider.autoDispose<List<CardItem>>((ref) => ref.watch(repositoryProvider).cards());
final expenseCategoriesProvider = FutureProvider.autoDispose<List<CategoryItem>>((ref) => ref.watch(repositoryProvider).categories(kind: 'Expense'));
final incomeCategoriesProvider = FutureProvider.autoDispose<List<CategoryItem>>((ref) => ref.watch(repositoryProvider).categories(kind: 'Income'));
final debtsProvider = FutureProvider.autoDispose<List<DebtItem>>((ref) => ref.watch(repositoryProvider).debts());
final receivablesProvider = FutureProvider.autoDispose<List<ReceivableItem>>((ref) => ref.watch(repositoryProvider).receivables());
final loansProvider = FutureProvider.autoDispose<List<LoanItem>>((ref) => ref.watch(repositoryProvider).loans());
final goalsProvider = FutureProvider.autoDispose<List<GoalItem>>((ref) => ref.watch(repositoryProvider).goals());
final groupsProvider = FutureProvider.autoDispose<List<GroupSummary>>((ref) => ref.watch(repositoryProvider).groups());
final netWorthHistoryProvider = FutureProvider.autoDispose<List<NetWorthPoint>>((ref) => ref.watch(repositoryProvider).netWorthHistory(months: 12));

final budgetProvider = FutureProvider.autoDispose.family<BudgetSummary, ({int year, int month})>(
    (ref, p) => ref.watch(repositoryProvider).budget(p.year, p.month));

final monthlyReportProvider = FutureProvider.autoDispose.family<MonthlyReport, ({int year, int month})>(
    (ref, p) => ref.watch(repositoryProvider).monthlyReport(p.year, p.month));

final groupDetailProvider = FutureProvider.autoDispose.family<GroupDetail, String>(
    (ref, id) => ref.watch(repositoryProvider).group(id));

final groupBalancesProvider = FutureProvider.autoDispose.family<GroupBalances, String>(
    (ref, id) => ref.watch(repositoryProvider).groupBalances(id));

final groupExpensesProvider = FutureProvider.autoDispose.family<PagedResult<GroupExpenseItem>, String>(
    (ref, id) => ref.watch(repositoryProvider).groupExpenses(id));

final accountHistoryProvider = FutureProvider.autoDispose.family<PagedResult<AccountMovement>, String>(
    (ref, id) => ref.watch(repositoryProvider).accountHistory(id));
