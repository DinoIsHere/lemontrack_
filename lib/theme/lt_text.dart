import 'package:flutter/material.dart';
import 'lt_colors.dart';

class LTText {
  static const String jakarta = 'PlusJakartaSans';
  static const String mono = 'JetBrains Mono';

  static TextTheme textTheme() {
    TextStyle jak(String family, double size, FontWeight weight, {double? ls, Color? color}) =>
        TextStyle(fontFamily: family, fontSize: size, fontWeight: weight, letterSpacing: ls, color: color);

    return TextTheme(
      displayLarge: jak(jakarta, 57, FontWeight.w400, color: LTColors.paper),
      headlineMedium: jak(jakarta, 28, FontWeight.w600, color: LTColors.paper),
      titleLarge: jak(jakarta, 22, FontWeight.w600, color: LTColors.paper),
      titleMedium: jak(jakarta, 16, FontWeight.w600, color: LTColors.paper),
      bodyLarge: jak(jakarta, 16, FontWeight.w400, color: LTColors.paper),
      bodyMedium: jak(jakarta, 14, FontWeight.w400, color: LTColors.paper),
      bodySmall: jak(jakarta, 12, FontWeight.w400, color: LTColors.ash),
      labelLarge: jak(jakarta, 14, FontWeight.w600, color: LTColors.paper),
      labelSmall: jak(jakarta, 11, FontWeight.w500, ls: 0.8, color: LTColors.ash),
    );
  }

  static const TextStyle numericLarge = TextStyle(
    fontFamily: mono,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: LTColors.lemon,
  );
  static const TextStyle numericMedium = TextStyle(
    fontFamily: mono,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: LTColors.paper,
  );
  static const TextStyle ticker = TextStyle(
    fontFamily: mono,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: LTColors.paper,
  );
}
