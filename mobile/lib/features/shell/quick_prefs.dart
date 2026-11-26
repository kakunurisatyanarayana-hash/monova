import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/theme_mode.dart';

/// Language picker for the top bar and Settings. Shows the current language code and a check on the chosen one.
class LanguageMenuButton extends ConsumerWidget {
  const LanguageMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.monova;
    final lang = ref.watch(languageProvider);
    return PopupMenuButton<AppLang>(
      tooltip: tr('settings_language'),
      onSelected: (l) => ref.read(languageProvider.notifier).set(l),
      itemBuilder: (_) => [
        for (final l in AppLang.values)
          PopupMenuItem<AppLang>(
            value: l,
            child: Row(
              children: [
                SizedBox(width: 22, child: l == lang ? Icon(Icons.check_rounded, size: 18, color: c.accentStart) : null),
                Text(l.label),
              ],
            ),
          ),
      ],
      child: _PillButton(icon: Icons.translate_rounded, label: lang.label),
    );
  }
}

/// Theme picker: device setting, light or dark.
class ThemeMenuButton extends ConsumerWidget {
  const ThemeMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.monova;
    final mode = ref.watch(themeModeProvider);
    final icon = switch (mode) {
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
      ThemeMode.system => Icons.brightness_auto_rounded,
    };
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Theme',
      onSelected: (m) => ref.read(themeModeProvider.notifier).set(m),
      itemBuilder: (_) => [
        for (final m in ThemeMode.values)
          PopupMenuItem<ThemeMode>(
            value: m,
            child: Row(
              children: [
                SizedBox(width: 22, child: m == mode ? Icon(Icons.check_rounded, size: 18, color: c.accentStart) : null),
                Text(themeLabel(m)),
              ],
            ),
          ),
      ],
      child: _PillButton(icon: icon, label: themeLabel(mode)),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.raised.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c.accentStart),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: c.ink, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 2),
          Icon(Icons.expand_more_rounded, size: 16, color: c.muted),
        ],
      ),
    );
  }
}
