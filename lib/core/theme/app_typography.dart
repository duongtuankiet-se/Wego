import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Xanh SM-inspired typography. Tight letter-spacing for premium feel,
/// but Vietnamese-safe — diacritics (â, ô, ấ, ằ, ữ, ợ…) need vertical
/// breathing room and don't render well with extra-bold weights on
/// systems that fall back to a non-Vietnamese font.
class AppTypography {
  AppTypography._();

  /// System defaults — let each platform pick its best Latin face,
  /// then fall back to fonts that ship full Vietnamese coverage so
  /// we never get a tofu/clipped diacritic.
  static const List<String> _fontFamilyFallback = [
    'Noto Sans',
    'Roboto',
    'sans-serif',
  ];

  /// Vietnamese diacritics need a roomy line so the upper accent
  /// (â, ấ, ằ, …) isn't clipped by the baseline metrics.
  static const double _minHeight = 1.25;

  /// Heavier weights (w800/w900) on the system fallback font often
  /// render diacritics blurrily or strip the accent entirely. Cap at
  /// w700 so the design intent ("bold") survives the fallback.
  static FontWeight _clampWeight(FontWeight w) =>
      w.value > FontWeight.w700.value ? FontWeight.w700 : w;

  static TextStyle _base({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w500,
    double letterSpacing = 0,
    double height = 1.4,
    Color color = AppColors.ink900,
  }) {
    return TextStyle(
      fontFamilyFallback: _fontFamilyFallback,
      fontSize: fontSize,
      fontWeight: _clampWeight(fontWeight),
      // Clamp letter spacing — designers sometimes go to -0.5+ which
      // makes diacritics collide with the previous character.
      letterSpacing: letterSpacing.clamp(-0.3, 0.5),
      height: height < _minHeight ? _minHeight : height,
      color: color,
    );
  }

  static TextStyle display = _base(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static TextStyle h1 = _base(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static TextStyle h2 = _base(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.35,
  );

  static TextStyle h3 = _base(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.05,
    height: 1.4,
  );

  static TextStyle bodyLarge = _base(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  static TextStyle body = _base(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.ink700,
  );

  static TextStyle caption = _base(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.ink500,
  );

  static TextStyle micro = _base(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.35,
    color: AppColors.ink500,
  );

  static TextStyle mono = _base(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.35,
  ).copyWith(fontFamily: 'monospace');
}
