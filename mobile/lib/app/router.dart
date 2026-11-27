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
import '../features/entries/entries_screens.dart';
import '../features/entries/purchases_screen.dart';
import '../features/property/property_person.dart';
import '../features/property/property_screens.dart';
import '../features/ledger/ledger_screens.dart';
import '../features/groups/group_screens.dart';
import '../features/groups_local/local_groups_screen.dart';
import '../features/home/home_screen.dart';
import '../features/money/money_hub.dart';
import '../features/documents/documents_screen.dart';
import '../features/loans/loans_screen.dart';
import '../features/plans/sip_screen.dart';
import '../features/qr/guest_screens.dart';
import '../features/qr/invitation_screens.dart';
import '../features/qr/qr_tools.dart';
import '../features/plans/plans_screen.dart';
import '../features/report/report_screen.dart';
import '../features/reminders/reminders_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/lending/lending_screens.dart';
import '../features/planning/planning_screen.dart';
import '../features/recurring/recurring_screen.dart';
import '../features/services/services_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/tools/age_and_rent_screens.dart';
import '../features/tools/calculator_screen.dart';
import '../features/market/live_market_screen.dart';
import '../features/property/hostel_screens.dart';
import '../features/notifications/notification_screen.dart';
import '../features/cloud/owner_account_screen.dart';
import '../features/public/public_complaint_screens.dart';
import '../core/public_complaints.dart';
import '../features/tools/income_tax_screen.dart';
import '../features/tools/loan_calculator_screen.dart';
import '../features/tools/tools_screens.dart';
import '../features/vault/vault_screen.dart';
import '../features/vault/vault_hub.dart';
import '../core/profile_store.dart';
import '../features/setup/setup_screens.dart';
import '../state/providers.dart';

/// Pages that are forms or calculators read best at a fixed width, centred, on wide screens.
Widget _form(Widget child) => PageWidth(maxWidth: 760, child: child);

final routerProvider = Provider<GoRouter>((ref) {
  // Read, not watch: watching would rebuild the whole router on every session change and send people back to the start.
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      // Public pages opened from a QR code or a status link: no app setup, no sign-in.
      if (loc == complaintFormRoute || loc == trackRoute) return null;
      // Deep links (for example a reload on /groups in the browser) keep their page while the session restores.
      if (ApiConfig.offline && loc == '/auth') return '/tools';
      // First open with no profile yet: ask for the name before anything else.
      final profile = ref.read(profileProvider);
      if (ApiConfig.offline && profile.loaded && profile.profile == null && loc != '/setup' && loc != '/') return '/setup';
      if (loc == '/auth' && session.isSignedIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _Splash()),
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      GoRoute(path: '/setup', builder: (_, __) => const SetupScreen()),
      GoRoute(
        path: complaintFormRoute,
        builder: (_, s) {
          final q = readFormQuery(s.uri.queryParameters);
          if (q == null) {
            return const Scaffold(body: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('This QR code link is incomplete. Please ask the hostel for a new code.'))));
          }
          return ComplaintFormPage(code: q.code, room: q.room, floor: q.floor, phone: q.phone, hostelName: q.hostelName);
        },
      ),
      GoRoute(
        path: trackRoute,
        builder: (_, s) => ComplaintStatusPage(token: s.uri.queryParameters['t'] ?? ''),
      ),
      // Everything below sits inside the app frame, so the menu and top bar stay visible on web and desktop.
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/activity', builder: (_, __) => const RequiresAccount(title: 'Activity', child: ActivityScreen())),
          // The offline build keeps groups on the device; the online build uses the server.
          GoRoute(path: '/groups', builder: (_, __) => ApiConfig.offline ? const LocalGroupsScreen() : const GroupsScreen()),
          GoRoute(
            path: '/groups/:id',
            builder: (_, s) => ApiConfig.offline
                ? LocalGroupDetailScreen(id: s.pathParameters['id']!)
                : RequiresAccount(title: 'Group', child: GroupDetailScreen(id: s.pathParameters['id']!)),
          ),
          GoRoute(path: '/insights', builder: (_, __) => const RequiresAccount(title: 'Insights', child: InsightsScreen())),
          GoRoute(path: '/accounts', builder: (_, __) => const RequiresAccount(title: 'Accounts', child: AccountsScreen())),
          GoRoute(path: '/accounts/:id', builder: (_, s) => RequiresAccount(title: 'Account', child: AccountDetailScreen(id: s.pathParameters['id']!))),
          GoRoute(path: '/cards', builder: (_, __) => const RequiresAccount(title: 'Credit cards', child: CardsScreen())),
          GoRoute(path: '/lending', builder: (_, __) => const RequiresAccount(title: 'Lending & borrowing', child: LendingScreen())),
          GoRoute(path: '/planning', builder: (_, __) => const RequiresAccount(title: 'Budgets & savings', child: PlanningScreen())),
          GoRoute(path: '/recurring', builder: (_, __) => const RequiresAccount(title: 'Recurring', child: RecurringScreen())),
          GoRoute(path: '/ledger', builder: (_, __) => const LedgerScreen()),
          GoRoute(path: '/ledger/:id', builder: (_, s) => LedgerAccountScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/entries', builder: (_, __) => const EntriesScreen()),
          GoRoute(path: '/purchases', builder: (_, __) => const PurchasesScreen()),
          GoRoute(path: '/money', builder: (_, __) => const MoneyHubScreen()),
          GoRoute(path: '/reminders', builder: (_, __) => const RemindersScreen()),
          GoRoute(path: '/plans', builder: (_, __) => const PlansScreen()),
          GoRoute(path: '/report', builder: (_, __) => const ReportScreen()),
          GoRoute(path: '/documents', builder: (_, __) => const DocumentsScreen()),
          GoRoute(path: '/qr', builder: (_, __) => const QrHubScreen()),
          GoRoute(path: '/sip', builder: (_, __) => const SipScreen()),
          GoRoute(path: '/qr/invites', builder: (_, __) => const InvitationListScreen()),
          GoRoute(path: '/qr/invites/:id', builder: (_, s) => InvitationDetailScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/qr/guests/:id', builder: (_, s) => GuestListScreen(eventId: s.pathParameters['id']!)),
          GoRoute(path: '/qr/scan', builder: (_, __) => const ScanScreen()),
          GoRoute(path: '/qr/scan/:id', builder: (_, s) => ScanScreen(eventId: s.pathParameters['id']!)),
          GoRoute(path: '/qr/location', builder: (_, __) => const LocationQrScreen()),
          GoRoute(path: '/qr/make', builder: (_, __) => const MakeQrScreen()),
          GoRoute(path: '/loans', builder: (_, __) => const LoanTrackerScreen()),
          GoRoute(path: '/loans/:id', builder: (_, s) => LoanDetailScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/property', builder: (_, __) => const PropertiesScreen()),
          GoRoute(path: '/property/:id', builder: (_, s) => PropertyDashboardScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/notifications', builder: (_, __) => _form(const NotificationCenterScreen())),
          GoRoute(path: '/owner-account', builder: (_, __) => _form(const OwnerAccountScreen())),
          GoRoute(path: '/property/:id/hub', builder: (_, s) => HostelHubScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/property/:id/complaints', builder: (_, s) => ComplaintsScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/property/:id/feedback', builder: (_, s) => FeedbackScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/person/:id', builder: (_, s) => PersonScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/saved-cards', builder: (_, __) => const SavedCardsScreen()),
          GoRoute(path: '/backup', builder: (_, __) => _form(const BackupScreen())),
          GoRoute(path: '/vault', builder: (_, __) => const VaultScreen()),
          GoRoute(path: '/vault-hub', builder: (_, __) => const VaultHubScreen()),
          GoRoute(path: '/services', builder: (_, __) => const ServicesScreen()),
          GoRoute(path: '/tools', builder: (_, __) => const ToolsScreen()),
          GoRoute(path: '/tools/emi', builder: (_, __) => _form(const LoanCalculatorScreen())),
          GoRoute(path: '/tools/interest', builder: (_, __) => _form(const InterestCalculatorScreen())),
          GoRoute(path: '/tools/gst', builder: (_, __) => _form(const GstCalculatorScreen())),
          GoRoute(path: '/tools/tax', builder: (_, __) => _form(const IncomeTaxScreen())),
          GoRoute(path: '/market', builder: (_, __) => _form(const LiveMarketScreen())),
          GoRoute(path: '/tools/calculator', builder: (_, __) => _form(const CalculatorScreen())),
          GoRoute(path: '/tools/split', builder: (_, __) => _form(const SplitCalculatorScreen())),
          GoRoute(path: '/tools/age', builder: (_, __) => _form(const AgeCalculatorScreen())),
          GoRoute(path: '/tools/rent', builder: (_, __) => _form(const RentCalculatorScreen())),
          GoRoute(path: '/settings', builder: (_, __) => _form(const SettingsScreen())),
          GoRoute(path: '/profile', builder: (_, __) => _form(const SetupScreen(editing: true))),
        ],
      ),
    ],
  );
});

/// The first page. Waits for the saved profile, then goes to the setup page (first open) or to Home.
class _Splash extends ConsumerWidget {
  const _Splash();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final online = !ApiConfig.offline;
    if (profile.loaded) {
      final target = (!online && profile.profile == null) ? '/setup' : '/home';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(target);
      });
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}