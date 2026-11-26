import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import '../tools/tools_screens.dart';
import 'quick_add_sheet.dart';

/// Phones get a bottom bar: Home | Activity | Add | Groups | Insights.
/// Wide screens (web and desktop) get a left sidebar with grouped sections and a slim top bar,
/// the same layout most web applications use.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = ['/home', '/activity', '/groups', '/insights'];
  static const _wideBreakpoint = 900.0;
  static const _sidebarWidth = 248.0;

  static List<_SidebarSection> get _sidebarSections => <_SidebarSection>[
    _SidebarSection(tr('section_overview'), [
      _SidebarItem(tr('nav_home'), Icons.home_rounded, '/home'),
      _SidebarItem(tr('nav_activity'), Icons.swap_vert_rounded, '/activity'),
      _SidebarItem(tr('nav_insights'), Icons.insights_rounded, '/insights'),
    ]),
    _SidebarSection(tr('section_money'), [
      _SidebarItem(tr('nav_accounts'), Icons.account_balance_wallet_rounded, '/accounts'),
      _SidebarItem(tr('nav_credit_cards'), Icons.credit_card_rounded, '/cards'),
      _SidebarItem(tr('nav_lending'), Icons.handshake_rounded, '/lending'),
      _SidebarItem(tr('nav_loans'), Icons.directions_car_rounded, '/loans'),
      _SidebarItem(tr('nav_budgets'), Icons.savings_rounded, '/planning'),
      _SidebarItem(tr('nav_recurring'), Icons.repeat_rounded, '/recurring'),
      _SidebarItem(tr('nav_groups'), Icons.groups_rounded, '/groups'),
    ]),
    _SidebarSection(tr('section_tools'), [
      _SidebarItem(tr('nav_all_services'), Icons.grid_view_rounded, '/services'),
      _SidebarItem(tr('nav_calculators'), Icons.calculate_outlined, '/tools'),
      _SidebarItem(tr('nav_vault'), Icons.lock_rounded, '/vault'),
      _SidebarItem(tr('nav_credit_book'), Icons.menu_book_rounded, '/ledger'),
      _SidebarItem(tr('nav_saved_cards'), Icons.credit_card_rounded, '/saved-cards'),
      _SidebarItem(tr('nav_backup'), Icons.backup_rounded, '/backup'),
    ]),
  ];

  /// Section and label of the menu entry that matches [location], e.g. (tr('section_money'), tr('nav_credit_cards')).
  static ({String section, String label})? _currentPage(String location) {
    for (final section in _sidebarSections) {
      for (final item in section.items) {
        if (location.startsWith(item.route)) return (section: section.title, label: item.label);
      }
    }
    if (location.startsWith('/settings')) return (section: 'Account', label: tr('nav_settings'));
    return null;
  }

  void _onAdd(BuildContext context, bool signedIn) {
    if (signedIn) {
      showQuickAdd(context);
      return;
    }
    if (ApiConfig.offline) {
      // The offline build keeps passwords, cards and backups on the device, so offer those instead of a sign-in.
      FormSheet.show<void>(context, title: 'What would you like to save?', child: const _AddChooser());
      return;
    }
    FormSheet.show<void>(
      context,
      title: 'Add an entry',
      child: const SignInGate(
        title: 'Sign in to record money',
        message: 'Expenses, income and transfers are saved to your account. Meanwhile you can split a bill or run a calculator.',
        actionLabel: 'Sign in or create account',
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final signedIn = session.isSignedIn;
    final location = GoRouterState.of(context).matchedLocation;
    final tab = _tabs.indexWhere(location.startsWith);
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              width: _sidebarWidth,
              location: location,
              signedIn: signedIn,
              offline: ApiConfig.offline,
              onAdd: () => _onAdd(context, signedIn),
            ),
            VerticalDivider(width: 1, color: context.monova.border),
            Expanded(
              child: Column(
                children: [
                  _TopBar(page: _currentPage(location), onAdd: () => _onAdd(context, signedIn)),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final c = context.monova;
    final index = tab;
    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        // A fixed height is essential: without it the Row's Expanded children fill the whole screen and push the page body to zero height.
        child: SizedBox(
          height: 82,
          child: Container(
            decoration: BoxDecoration(color: c.raised, border: Border(top: BorderSide(color: c.border))),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: Row(
              children: [
                _NavItem(icon: Icons.home_rounded, label: tr('nav_home'), selected: index == 0, onTap: () => context.go('/home')),
                _NavItem(icon: Icons.swap_vert_rounded, label: tr('nav_activity'), selected: index == 1, onTap: () => context.go('/activity')),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _onAdd(context, signedIn),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: c.aurora,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: c.accentStart.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 8))],
                        ),
                        child: Icon(Icons.add_rounded, color: c.onAccent, size: 32),
                      ),
                    ),
                  ),
                ),
                _NavItem(icon: Icons.groups_rounded, label: tr('nav_groups'), selected: index == 2, onTap: () => context.go('/groups')),
                _NavItem(icon: Icons.insights_rounded, label: tr('nav_insights'), selected: index == 3, onTap: () => context.go('/insights')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Choices shown by the Add button in the offline build. Each opens a page that works without an account.
class _AddChooser extends StatelessWidget {
  const _AddChooser();

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final options = [
      (icon: Icons.lock_rounded, title: 'Password or note', subtitle: 'Logins, PINs and anything you want to remember', route: '/vault'),
      (icon: Icons.credit_card_rounded, title: 'Card', subtitle: 'Card name, bank, last four digits and a photo', route: '/saved-cards'),
      (icon: Icons.backup_rounded, title: 'Backup', subtitle: 'Make an encrypted copy to restore on another device', route: '/backup'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final o in options) ...[
          MonovaCard(
            padding: const EdgeInsets.all(14),
            onTap: () {
              // Read the router before closing the sheet, because the sheet's context is gone after the pop.
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.push(o.route);
            },
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(gradient: c.aurora, borderRadius: BorderRadius.circular(14)),
                  child: Icon(o.icon, color: c.onAccent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(o.subtitle, style: TextStyle(color: c.muted, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.muted),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SidebarSection {
  const _SidebarSection(this.title, this.items);

  final String title;
  final List<_SidebarItem> items;
}

class _SidebarItem {
  const _SidebarItem(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.width,
    required this.location,
    required this.signedIn,
    required this.offline,
    required this.onAdd,
  });

  final double width;
  final String location;
  final bool signedIn;
  final bool offline;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return SizedBox(
      width: width,
      child: ColoredBox(
        color: c.raised,
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(gradient: c.aurora, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.account_balance_wallet_rounded, color: c.onAccent, size: 16),
                    ),
                    const SizedBox(width: 10),
                    ShaderMask(
                      shaderCallback: (r) => c.aurora.createShader(r),
                      child: const Text('MONOVA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final section in MainShell._sidebarSections) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                        child: Text(
                          section.title.toUpperCase(),
                          style: TextStyle(color: c.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
                        ),
                      ),
                      for (final item in section.items)
                        _SidebarTile(
                          item: item,
                          selected: location.startsWith(item.route),
                        ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SidebarTile(
                      item: _SidebarItem(tr('nav_settings'), Icons.settings_rounded, '/settings'),
                      selected: location.startsWith('/settings'),
                    ),
                    if (!signedIn && !offline)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FilledButton(
                          onPressed: () => context.go('/auth'),
                          child: Text(tr('sign_in')),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.item, required this.selected});

  final _SidebarItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final color = selected ? c.accentStart : c.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? c.accentStart.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(item.route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(item.icon, size: 19, color: selected ? c.accentStart : c.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Slim bar above the page content: the main action is always one click away.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.page, required this.onAdd});

  final ({String section, String label})? page;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final title = page?.label ?? tr('nav_home');
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: c.raised, border: Border(bottom: BorderSide(color: c.border))),
      child: Row(
        children: [
          // The page's own header shows the title; the bar keeps the breadcrumb only, so the name is not repeated.
          Text('MONOVA${page == null ? '' : ' / ${page!.section} / $title'}', style: TextStyle(color: c.muted, fontSize: 13)),
          const Spacer(),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(tr('add_entry')),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final color = selected ? c.accentStart : c.muted;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
