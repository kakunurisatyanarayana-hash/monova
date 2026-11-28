import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/app_lock.dart';
import '../../core/cloud_sync.dart';
import '../../core/build_info.dart';
import '../../core/i18n.dart';
import '../../core/profile_store.dart';
import '../../core/theme_mode.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import '../lock/lock_screen.dart';

/// Settings in four short sections: your profile and appearance, security, your data, and the account (online build only).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(sessionProvider).isSignedIn;
    final pinOn = ref.watch(appLockProvider).status != LockStatus.disabled;
    final c = context.monova;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _ProfileCard(),
          const SizedBox(height: 22),
          SectionTitle('Appearance'),
          const SizedBox(height: 8),
          const _LanguageCard(),
          const SizedBox(height: 22),
          const SectionTitle('Security'),
          const SizedBox(height: 8),
          _SettingRow(
            icon: Icons.lock_outline_rounded,
            title: 'App PIN',
            subtitle: pinOn ? 'On. Asked each time MONOVA opens.' : 'Off. Set a PIN to lock MONOVA.',
            onTap: () => togglePinFromSettings(context, ref),
          ),
          const SizedBox(height: 22),
          const SectionTitle('Your data'),
          const SizedBox(height: 8),
          _SettingRow(
            icon: Icons.backup_rounded,
            title: 'Backup and restore',
            subtitle: 'An encrypted copy you can restore on another phone.',
            onTap: () => context.push('/backup'),
          ),
          _SettingRow(
            icon: Icons.grid_view_rounded,
            title: 'All services',
            subtitle: 'Every feature, grouped by what it is for.',
            onTap: () => context.push('/services'),
          ),
          // Works in every build: lock the app with its PIN, and sign out of the owner account when signed in.
          const SizedBox(height: 22),
          const SectionTitle('App access'),
          const SizedBox(height: 8),
          if (ref.watch(appLockProvider).status == LockStatus.locked || ref.watch(appLockProvider).status == LockStatus.unlocked)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => ref.read(appLockProvider.notifier).lockIfSet(),
              icon: const Icon(Icons.lock_outline_rounded),
              label: const Text('Lock the app now'),
            ),
          if (OwnerAccount.user != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: c.expense, side: BorderSide(color: c.expense), minimumSize: const Size.fromHeight(52)),
              onPressed: () => OwnerAccount.signOut(),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out of owner account'),
            ),
          ],
          if (!ApiConfig.offline) ...[
            const SizedBox(height: 22),
            const SectionTitle('Account'),
            const SizedBox(height: 8),
            if (signedIn)
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
          const SizedBox(height: 28),
          Center(child: Text(buildLabel, style: TextStyle(color: c.muted, fontSize: 11))),
        ],
      ),
    );
  }
}

/// One tappable row in Settings: icon, title, a short line of what it does, and a chevron.
class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MonovaCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: c.accentStart),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: c.muted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.muted),
          ],
        ),
      ),
    );
  }
}
/// Language and theme as chips: one tap each, no hidden menus.
class _LanguageCard extends ConsumerWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.monova;
    final lang = ref.watch(languageProvider);
    final mode = ref.watch(themeModeProvider);
    return MonovaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('settings_language'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in AppLang.values)
                ChoiceChip(
                  label: Text(l.label),
                  selected: l == lang,
                  onSelected: (_) => ref.read(languageProvider.notifier).set(l),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Theme', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in ThemeMode.values)
                ChoiceChip(
                  label: Text(themeLabel(m)),
                  selected: m == mode,
                  onSelected: (_) => ref.read(themeModeProvider.notifier).set(m),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(tr('settings_language_note'), style: TextStyle(color: c.muted, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}
/// The profile at the top of Settings. Tap to edit the name and contact details.
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.monova;
    final p = ref.watch(profileProvider).profile;
    final details = [if (p != null && p.phone.isNotEmpty) p.phone, if (p != null && p.email.isNotEmpty) p.email].join(' · ');
    return MonovaCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/profile'),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: c.accentStart,
            child: Text(
              p == null || p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
              style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p == null ? 'Add your name' : p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(details.isEmpty ? 'Tap to edit your profile' : details, style: TextStyle(color: c.muted, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.muted),
        ],
      ),
    );
  }
}