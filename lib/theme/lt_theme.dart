import 'package:flutter/material.dart';
import 'lt_colors.dart';
import 'lt_text.dart';

ThemeData ltDarkTheme() {
  final scheme = ColorScheme.dark(
    primary: LTColors.lemon,
    onPrimary: LTColors.ink,
    primaryContainer: LTColors.lemonDeep,
    onPrimaryContainer: LTColors.lemonSoft,
    secondary: LTColors.ember,
    surface: LTColors.ink,
    onSurface: LTColors.paper,
    onSurfaceVariant: LTColors.ash,
    outline: LTColors.wire,
    outlineVariant: LTColors.wireSoft,
    error: LTColors.coral,
    surfaceContainerLowest: LTColors.void_,
    surfaceContainer: LTColors.graphite,
    surfaceContainerHigh: LTColors.slate,
    surfaceContainerHighest: LTColors.steel,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: LTText.textTheme(),
    fontFamily: 'PlusJakartaSans',
    scaffoldBackgroundColor: LTColors.ink,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: LTColors.graphite,
      indicatorColor: LTColors.lemonDeep,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return const IconThemeData(color: LTColors.lemon);
        return const IconThemeData(color: LTColors.ash);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return const TextStyle(fontSize: 11, color: LTColors.lemon);
        return const TextStyle(fontSize: 11, color: LTColors.ash);
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: LTColors.lemon,
        foregroundColor: LTColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: LTColors.paper,
        side: const BorderSide(color: LTColors.wire),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      color: LTColors.graphite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: LTColors.wire),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LTColors.steel,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LTColors.wire)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LTColors.wire)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LTColors.lemon)),
    ),
  );
}
