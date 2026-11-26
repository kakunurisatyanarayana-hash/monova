import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'features/lock/lock_screen.dart';
import 'core/ambient.dart';
import 'core/i18n.dart';
import 'core/theme_mode.dart';
import 'core/scroll_behavior.dart';
import 'core/theme.dart';

class MonovaApp extends ConsumerWidget {
  const MonovaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return MaterialApp.router(
      // A new key on a language change rebuilds the whole app, so every label switches at once.
      key: ValueKey(lang),
      title: 'MONOVA',
      debugShowCheckedModeBanner: false,
      theme: MonovaTheme.build(Brightness.light),
      darkTheme: MonovaTheme.build(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      scrollBehavior: const MonovaScrollBehavior(),
      // Full width on every device, like a web application: the side menu and top bar frame the page.
      builder: (context, child) {
        // The ambient background sits behind everything; the lock gate covers the app when a PIN is set.
        return Stack(
          fit: StackFit.expand,
          children: [
            AmbientBackground(colors: context.monova),
            LockGate(child: child!),
          ],
        );
      },
    );
  }
}
