import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
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
      // Phones use the full width. Desktop and web use up to 1100 px, centred, so screens look like a web application.
      builder: (context, child) {
        final base = Theme.of(context).scaffoldBackgroundColor;
        return ColoredBox(
          color: base,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
