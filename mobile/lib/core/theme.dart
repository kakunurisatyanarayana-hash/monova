import 'package:flutter/material.dart';

/// MONOVA design tokens. "Aurora" accent on graphite (dark) and bone (light).
/// Every colour used by a widget comes from here so both themes stay consistent.
class MonovaColors {
  const MonovaColors({
    required this.base,
    required this.raised,
    required this.border,
    required this.ink,
    required this.muted,
    required this.accentStart,
    required this.accentEnd,
    required this.income,
    required this.expense,
    required this.warning,
    required this.onAccent,
  });

  final Color base;
  final Color raised;
  final Color border;
  final Color ink;
  final Color muted;
  final Color accentStart;
  final Color accentEnd;
  final Color income;
  final Color expense;
  final Color warning;
  final Color onAccent;

  static const dark = MonovaColors(
    base: Color(0xFF0B0D12),
    raised: Color(0xFF14171F),
    border: Color(0xFF232838),
    ink: Color(0xFFF2F3F7),
    muted: Color(0xFF8A90A2),
    accentStart: Color(0xFF5EEAD4),
    accentEnd: Color(0xFF8B7CF6),
    income: Color(0xFF4ADE80),
    expense: Color(0xFFFB7185),
    warning: Color(0xFFFBBF24),
    onAccent: Color(0xFF0B0D12),
  );

  static const light = MonovaColors(
    base: Color(0xFFF5F4F0),
    raised: Color(0xFFFFFFFF),
    border: Color(0xFFE4E1D9),
    ink: Color(0xFF12141A),
    muted: Color(0xFF5F6575),
    accentStart: Color(0xFF00756B),
    accentEnd: Color(0xFF6D5BE0),
    income: Color(0xFF15803D),
    expense: Color(0xFFBE123C),
    warning: Color(0xFFB45309),
    onAccent: Color(0xFFFFFFFF),
  );

  LinearGradient get aurora => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accentStart, accentEnd],
      );
}

class MonovaTheme {
  static ThemeData build(Brightness brightness) {
    final c = brightness == Brightness.dark ? MonovaColors.dark : MonovaColors.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accentStart,
      onPrimary: c.onAccent,
      secondary: c.accentEnd,
      onSecondary: c.onAccent,
      error: c.expense,
      onError: c.onAccent,
      surface: c.raised,
      onSurface: c.ink,
      surfaceContainerHighest: c.border,
      outline: c.border,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.base,
      canvasColor: c.base,
      dividerColor: c.border,
      appBarTheme: AppBarTheme(
        backgroundColor: c.base,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: c.ink, fontSize: 20, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: c.raised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.raised,
        labelStyle: TextStyle(color: c.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.accentStart, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accentStart,
          foregroundColor: c.onAccent,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(color: c.ink, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        titleLarge: TextStyle(color: c.ink, fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: c.ink, fontSize: 16, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(color: c.ink, fontSize: 14),
        bodySmall: TextStyle(color: c.muted, fontSize: 12),
        labelLarge: TextStyle(color: c.ink, fontSize: 14, fontWeight: FontWeight.w600),
      ),
      extensions: [MonovaThemeExtension(c)],
    );
  }
}

/// Exposes MonovaColors to widgets via Theme.of(context).extension<MonovaThemeExtension>().
class MonovaThemeExtension extends ThemeExtension<MonovaThemeExtension> {
  const MonovaThemeExtension(this.colors);

  final MonovaColors colors;

  @override
  MonovaThemeExtension copyWith({MonovaColors? colors}) => MonovaThemeExtension(colors ?? this.colors);

  @override
  MonovaThemeExtension lerp(ThemeExtension<MonovaThemeExtension>? other, double t) => this;
}

extension MonovaContext on BuildContext {
  MonovaColors get monova => Theme.of(this).extension<MonovaThemeExtension>()!.colors;
}
