import 'package:flutter/material.dart';

/// Fonts tried, in order, for letters the main font does not have: Telugu, then Hindi (Devanagari).
const indicFontFallback = <String>['NotoSansTelugu', 'NotoSansDevanagari'];

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
    required this.glassFill,
    required this.glowA,
    required this.glowB,
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

  /// Frosted surface for cards and bars: slightly see-through so the background glow shows through.
  final Color glassFill;

  /// Two soft light sources behind the app. They give the "ambient" feel.
  final Color glowA;
  final Color glowB;

  static const dark = MonovaColors(
    base: Color(0xFF070910),
    raised: Color(0xFF14171F),
    border: Color(0x33A5B4FC),
    ink: Color(0xFFF2F3F7),
    muted: Color(0xFF9AA1B5),
    accentStart: Color(0xFF5EEAD4),
    accentEnd: Color(0xFF8B7CF6),
    income: Color(0xFF4ADE80),
    expense: Color(0xFFFB7185),
    warning: Color(0xFFFBBF24),
    onAccent: Color(0xFF0B0D12),
    glassFill: Color(0xA6161A26),
    glowA: Color(0x4D5EEAD4),
    glowB: Color(0x598B7CF6),
  );

  static const light = MonovaColors(
    base: Color(0xFFF6F4EF),
    raised: Color(0xFFFFFFFF),
    border: Color(0xFFE2DED4),
    ink: Color(0xFF12141A),
    muted: Color(0xFF5F6575),
    accentStart: Color(0xFF00756B),
    accentEnd: Color(0xFF6D5BE0),
    income: Color(0xFF15803D),
    expense: Color(0xFFBE123C),
    warning: Color(0xFFB45309),
    onAccent: Color(0xFFFFFFFF),
    glassFill: Color(0xB8FFFFFF),
    glowA: Color(0x5200A394),
    glowB: Color(0x4A6D5BE0),
  );

  /// The accent as a flat colour. Used for icon badges, buttons and small marks, so the app keeps one calm accent.
  LinearGradient get aurora => LinearGradient(colors: [accentStart, accentStart]);

  /// The full two-colour gradient. Used only for hero cards at the top of a page.
  LinearGradient get hero => LinearGradient(
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
      // Transparent, so the ambient background behind the whole app shows through.
      scaffoldBackgroundColor: Colors.transparent,
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
        fillColor: c.base,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        labelStyle: TextStyle(color: c.muted, fontWeight: FontWeight.w500),
        floatingLabelStyle: TextStyle(color: c.accentStart, fontWeight: FontWeight.w700),
        hintStyle: TextStyle(color: c.muted.withValues(alpha: 0.7)),
        prefixIconColor: c.muted,
        suffixIconColor: c.muted,
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
          borderSide: BorderSide(color: c.accentStart, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.expense),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.expense, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accentStart,
          foregroundColor: c.onAccent,
          elevation: 0,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: BorderSide(color: c.border, width: 1.2),
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accentStart,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: c.base,
          foregroundColor: c.muted,
          selectedForegroundColor: c.onAccent,
          selectedBackgroundColor: c.accentStart,
          side: BorderSide(color: c.border),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.raised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: c.border),
        ),
        titleTextStyle: TextStyle(color: c.ink, fontSize: 19, fontWeight: FontWeight.w800),
        contentTextStyle: TextStyle(color: c.muted, fontSize: 14, height: 1.45),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        contentTextStyle: TextStyle(color: c.base, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.raised,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.raised,
        side: BorderSide(color: c.border),
        labelStyle: TextStyle(color: c.ink, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onAccent : c.muted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accentStart : c.border),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      // Hindi and Telugu text falls back to the Noto fonts bundled in assets/fonts, so those letters show instead of boxes.
      textTheme: TextTheme(
        headlineMedium: TextStyle(color: c.ink, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        titleLarge: TextStyle(color: c.ink, fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: c.ink, fontSize: 16, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(color: c.ink, fontSize: 14),
        bodySmall: TextStyle(color: c.muted, fontSize: 12),
        labelLarge: TextStyle(color: c.ink, fontSize: 14, fontWeight: FontWeight.w600),
      ).apply(fontFamilyFallback: indicFontFallback),
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
