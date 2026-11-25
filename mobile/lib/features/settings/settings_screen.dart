import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

/// Account details, shortcuts to every module, and sign out. Sign out clears the stored tokens on this device.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    final c = context.monova;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          MonovaCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: c.accentStart,
                  child: Text((user?.displayName.isNotEmpty ?? false) ? user!.displayName[0].toUpperCase() : '?', style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w800, fontSize: 18)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.displayName ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(user?.email ?? '', style: TextStyle(color: c.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Money'),
          const SizedBox(height: 8),
          _Link(icon: Icons.account_balance_rounded, label: 'Accounts', onTap: () => context.push('/accounts')),
          _Link(icon: Icons.credit_card_rounded, label: 'Credit cards', onTap: () => context.push('/cards')),
          _Link(icon: Icons.handshake_rounded, label: 'Lending & borrowing', onTap: () => context.push('/lending')),
          _Link(icon: Icons.directions_car_rounded, label: 'Loans & EMI', onTap: () => context.push('/loans')),
          _Link(icon: Icons.savings_rounded, label: 'Budgets & savings goals', onTap: () => context.push('/planning')),
          _Link(icon: Icons.repeat_rounded, label: 'Recurring entries', onTap: () => context.push('/recurring')),
          const SizedBox(height: 16),
          const SectionTitle('Security'),
          const SizedBox(height: 8),
          MonovaCard(
            child: Text(
              'Tokens are stored in the device keystore. Sessions expire after 30 days of inactivity and are revoked on sign-out.',
              style: TextStyle(color: c.muted),
            ),
          ),
          const SizedBox(height: 24),
          if (ApiConfig.offline)
            const SizedBox.shrink()
          else if (ref.watch(sessionProvider).isSignedIn)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: c.expense, side: BorderSide(color: c.expense), minimumSize: const Size.fromHeight(52)),
              onPressed: () async {
                await ref.read(sessionProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            )
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => context.push('/auth'),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Sign in or create account'),
            ),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MonovaCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: context.monova.accentStart),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Icon(Icons.chevron_right_rounded, color: context.monova.muted),
          ],
        ),
      ),
    );
  }
}
