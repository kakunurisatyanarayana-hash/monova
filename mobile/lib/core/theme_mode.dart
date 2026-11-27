import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_store.dart';

const themeKey = 'monova.theme';

/// Saved theme choice: follow the device, or always light, or always dark.
class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final store = await LocalStore.open();
    final raw = store.readList(themeKey);
    final name = raw.isEmpty ? null : '${raw.first['mode']}';
    state = switch (name) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final store = await LocalStore.open();
    await store.writeList(themeKey, [
      {'mode': mode.name},
    ]);
  }
}

final themeModeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

/// Short label for each theme choice, shown in menus.
String themeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
  ThemeMode.system => 'Device',
};
