import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Soft iOS 26-style elevation tokens. Use these instead of raw
/// BoxShadow lists so component depth stays consistent across screens.
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> xs = [
    BoxShadow(blurRadius: 2, offset: Offset(0, 1), color: Color(0x0A000000)),
  ];

  static const List<BoxShadow> sm = [
    BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Color(0x10000000)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(blurRadius: 16, offset: Offset(0, 4), color: Color(0x14000000)),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(blurRadius: 32, offset: Offset(0, 12), color: Color(0x1A000000)),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(blurRadius: 48, offset: Offset(0, 20), color: Color(0x1F000000)),
  ];

  /// Coloured glow — typically used behind the primary CTA so it pops.
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      blurRadius: 24,
      offset: const Offset(0, 8),
      color: color.withValues(alpha: 0.25),
    ),
  ];

  static List<BoxShadow> glowPrimary() => glow(AppColors.primary500);
}
