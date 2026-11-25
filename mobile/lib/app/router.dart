import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/page_width.dart';
import '../features/accounts/accounts_screen.dart';
import '../features/activity/activity_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/backup/backup_screen.dart';
import '../features/cards/saved_cards_screen.dart';
import '../features/groups/group_screens.dart';
import '../features/home/home_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/lending/lending_screens.dart';
import '../features/planning/planning_screen.dart';
import '../features/recurring/recurring_screen.dart';
import '../features/services/services_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/tools/age_and_rent_screens.dart';
import '../features/tools/calculator_screen.dart';
import '../features/tools/loan_calculator_screen.dart';
import '../features/tools/tools_screens.dart';
import '../features/vault/vault_screen.dart';
import '../state/providers.dart';

/// Pages that are forms or calculators read best at a fixed width, centred, on wide screens.
Widget _form(Widget child) => PageWidth(maxWidth: 760, child: child);

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      // Guests and signed-in users both enter the app directly. Only the startup splash is special.
      if (session.status == SessionStatus.unknown) return loc == '/' ? null : '/';
      if (ApiConfig.offline && loc == '/auth') return '/tools';
      if (loc == '/') return '/home';
      if (loc == '/auth' && session.isSignedIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _Splash()),
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      // Everything below sits inside the app frame, so the menu and top bar stay visible on web and desktop.
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/activity', builder: (_, __) => const RequiresAccount(title: 'Activity', child: ActivityScreen())),
          GoRoute(path: '/groups', builder: (_, __) => const GroupsScreen()),
          GoRoute(path: '/groups/:id', builder: (_, s) => RequiresAccount(title: 'Group', child: GroupDetailScreen(id: s.pathParameters['id']!))),
          GoRoute(path: '/insights', builder: (_, __) => const RequiresAccount(title: 'Insights', child: InsightsScreen())),
          GoRoute(path: '/accounts', builder: (_, __) => const RequiresAccount(title: 'Accounts', child: AccountsScreen())),
          GoRoute(path: '/accounts/:id', builder: (_, s) => RequiresAccount(title: 'Account', child: AccountDetailScreen(id: s.pathParameters['id']!))),
          GoRoute(path: '/cards', builder: (_, __) => const RequiresAccount(title: 'Credit cards', child: CardsScreen())),
          GoRoute(path: '/lending', builder: (_, __) => const RequiresAccount(title: 'Lending & borrowing', child: LendingScreen())),
          GoRoute(path: '/loans', builder: (_, __) => const RequiresAccount(title: 'Loans & EMI', child: LoansScreen())),
          GoRoute(path: '/planning', builder: (_, __) => const RequiresAccount(title: 'Budgets & savings', child: PlanningScreen())),
          GoRoute(path: '/recurring', builder: (_, __) => const RequiresAccount(title: 'Recurring', child: RecurringScreen())),
          GoRoute(path: '/saved-cards', builder: (_, __) => const SavedCardsScreen()),
          GoRoute(path: '/backup', builder: (_, __) => _form(const BackupScreen())),
          GoRoute(path: '/vault', builder: (_, __) => const VaultScreen()),
          GoRoute(path: '/services', builder: (_, __) => const ServicesScreen()),
          GoRoute(path: '/tools', builder: (_, __) => const ToolsScreen()),
          GoRoute(path: '/tools/emi', builder: (_, __) => _form(const LoanCalculatorScreen())),
          GoRoute(path: '/tools/interest', builder: (_, __) => _form(const InterestCalculatorScreen())),
          GoRoute(path: '/tools/gst', builder: (_, __) => _form(const GstCalculatorScreen())),
          GoRoute(path: '/tools/calculator', builder: (_, __) => _form(const CalculatorScreen())),
          GoRoute(path: '/tools/split', builder: (_, __) => _form(const SplitCalculatorScreen())),
          GoRoute(path: '/tools/age', builder: (_, __) => _form(const AgeCalculatorScreen())),
          GoRoute(path: '/tools/rent', builder: (_, __) => _form(const RentCalculatorScreen())),
          GoRoute(path: '/settings', builder: (_, __) => _form(const SettingsScreen())),
        ],
      ),
    ],
  );
});

class _Splash extends ConsumerStatefulWidget {
  const _Splash();

  @override
  ConsumerState<_Splash> createState() => _SplashState();
}

class _SplashState extends ConsumerState<_Splash> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(sessionProvider.notifier).restore());
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
