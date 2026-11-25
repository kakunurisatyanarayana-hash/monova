import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import '../tools/tools_screens.dart';
import 'quick_add_sheet.dart';

/// Phones get a bottom bar: Home | Activity | Add | Groups | Insights.
/// Wide screens (web and desktop) get a side menu with the same items, so the app feels like a web application.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = ['/home', '/activity', '/groups', '/insights'];
  static const _wideBreakpoint = 900.0;

  void _onAdd(BuildContext context, bool signedIn) {
    if (signedIn) {
      showQuickAdd(context);
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
    final signedIn = ref.watch(sessionProvider).isSignedIn;
    final location = GoRouterState.of(context).matchedLocation;
    final tab = _tabs.indexWhere(location.startsWith);
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    if (wide) {
      // Side menu: Home, Activity, Add (action), Groups, Insights. Rail index 2 is the Add action, so tabs after it shift by one.
      final railIndex = tab < 0 ? 0 : (tab >= 2 ? tab + 1 : tab);
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: railIndex,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) {
                if (i == 2) {
                  _onAdd(context, signedIn);
                  return;
                }
                context.go(_tabs[i >= 3 ? i - 1 : i]);
              },
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: Text('Home')),
                NavigationRailDestination(icon: Icon(Icons.swap_vert_rounded), label: Text('Activity')),
                NavigationRailDestination(icon: Icon(Icons.add_circle_outline_rounded), selectedIcon: Icon(Icons.add_circle_rounded), label: Text('Add')),
                NavigationRailDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: Text('Groups')),
                NavigationRailDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: Text('Insights')),
              ],
            ),
            VerticalDivider(width: 1, color: context.monova.border),
            Expanded(child: child),
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
                _NavItem(icon: Icons.home_rounded, label: 'Home', selected: index == 0, onTap: () => context.go('/home')),
                _NavItem(icon: Icons.swap_vert_rounded, label: 'Activity', selected: index == 1, onTap: () => context.go('/activity')),
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
                _NavItem(icon: Icons.groups_rounded, label: 'Groups', selected: index == 2, onTap: () => context.go('/groups')),
                _NavItem(icon: Icons.insights_rounded, label: 'Insights', selected: index == 3, onTap: () => context.go('/insights')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonovaWordmark extends StatelessWidget {
  const _MonovaWordmark({required this.colors});

  final MonovaColors colors;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => colors.aurora.createShader(r),
      child: const Text('MONOVA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
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
