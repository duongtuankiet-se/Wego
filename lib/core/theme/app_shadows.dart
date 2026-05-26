import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Phase 5 Xanh SM ultra-soft shadows. Pull these instead of hand-rolling
/// BoxShadow lists so depth stays consistent across screens.
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> xs = [
    BoxShadow(blurRadius: 12, offset: Offset(0, 2), color: Color(0x08000000)),
  ];

  static const List<BoxShadow> sm = [
    BoxShadow(blurRadius: 16, offset: Offset(0, 4), color: Color(0x0C000000)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(blurRadius: 24, offset: Offset(0, 8), color: Color(0x10000000)),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(blurRadius: 40, offset: Offset(0, 16), color: Color(0x14000000)),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(blurRadius: 48, offset: Offset(0, 20), color: Color(0x1F000000)),
  ];

  /// Mint glow shadow for the primary CTA + brand surfaces.
  static List<BoxShadow> heroGlow(Color color) => [
    BoxShadow(
      blurRadius: 32,
      offset: const Offset(0, 12),
      color: color.withValues(alpha: 0.15),
    ),
  ];

  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      blurRadius: 24,
      offset: const Offset(0, 8),
      color: color.withValues(alpha: 0.25),
    ),
  ];

  static List<BoxShadow> glowPrimary() => glow(AppColors.primary500);
}
