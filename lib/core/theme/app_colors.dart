import 'package:flutter/material.dart';

/// WeGo color palette — Xanh SM inspired mint green system.
///
/// The legacy teal (#1FA98E) was swapped for premium mint (#0FB67E) in
/// Phase 4. All existing AppColors.primary500 references inherit the new
/// hue automatically.
class AppColors {
  AppColors._();

  // ── Primary: mint green ────────────────────────────────────────────
  static const Color primary50 = Color(0xFFECFDF5);
  static const Color primary100 = Color(0xFFD1FAE5);
  static const Color primary200 = Color(0xFFA7F3D0);
  static const Color primary300 = Color(0xFF6EE7B7);
  static const Color primary400 = Color(0xFF34D399);
  static const Color primary500 = Color(0xFF0FB67E); // brand
  static const Color primary600 = Color(0xFF059669); // pressed
  static const Color primary700 = Color(0xFF047857); // dark variant
  static const Color primary800 = Color(0xFF065F46);
  static const Color primary900 = Color(0xFF064E3B);

  // ── Ink (neutrals) ─────────────────────────────────────────────────
  static const Color ink900 = Color(0xFF0F172A);
  static const Color ink800 = Color(0xFF1E293B);
  static const Color ink700 = Color(0xFF334155);
  static const Color ink600 = Color(0xFF475569);
  static const Color ink500 = Color(0xFF64748B);
  static const Color ink400 = Color(0xFF94A3B8);
  static const Color ink300 = Color(0xFFCBD5E1);
  static const Color ink200 = Color(0xFFE2E8F0);
  static const Color ink100 = Color(0xFFF1F5F9);
  static const Color ink50 = Color(0xFFF8FAFC);

  // ── Surface ────────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFFAFBFC);

  // ── Status ─────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF06B6D4);

  // ── Domain ─────────────────────────────────────────────────────────
  static const Color sharedAccent = Color(0xFF06B6D4); // cyan — xe ghép
  static const Color surge = Color(0xFFF97316);
  static const Color gold = Color(0xFFD4A574);

  // ── Glass (iOS 26-style) ───────────────────────────────────────────
  static const Color glassWhite = Color(0xCCFFFFFF); // 80% white
  static const Color glassBorder = Color(0x99FFFFFF); // 60% white border
  static const Color glassDark = Color(0xCC0F172A); // 80% ink900
}
