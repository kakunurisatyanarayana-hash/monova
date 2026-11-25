import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'features/lock/lock_screen.dart';
import 'core/scroll_behavior.dart';
import 'core/theme.dart';

class MonovaApp extends ConsumerWidget {
  const MonovaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MONOVA',
      debugShowCheckedModeBanner: false,
      theme: MonovaTheme.build(Brightness.light),
      darkTheme: MonovaTheme.build(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
      scrollBehavior: const MonovaScrollBehavior(),
      // Full width on every device, like a web application: the side menu and top bar frame the page.
      builder: (context, child) {
        final base = Theme.of(context).scaffoldBackgroundColor;
        // The lock gate covers the whole app when a PIN is set.
        return ColoredBox(color: base, child: LockGate(child: child!));
      },
    );
  }
}
