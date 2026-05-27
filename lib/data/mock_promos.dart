import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme/app_colors.dart';

class PromoVoucher {
  final String code;
  final String title;
  final String description;
  final DateTime expiresAt;
  final List<Color> gradient;
  final IconData icon;

  /// Percent discount (0-100). When 0, [discountVnd] is used instead.
  final int discountPercent;

  /// Fixed VND discount. Null when [discountPercent] > 0.
  final int? discountVnd;

  /// Cap on percent discount (VND). Null = no cap.
  final int? maxDiscountVnd;

  /// Minimum base fare (VND) for the promo to apply.
  final int minOrderVnd;

  const PromoVoucher({
    required this.code,
    required this.title,
    required this.description,
    required this.expiresAt,
    required this.gradient,
    required this.icon,
    this.discountPercent = 0,
    this.discountVnd,
    this.maxDiscountVnd,
    this.minOrderVnd = 0,
  });
}

List<PromoVoucher> generateMockPromos() {
  final eoy = DateTime(DateTime.now().year, 12, 31);
  final midYear = DateTime(DateTime.now().year, 6, 30);
  return [
    PromoVoucher(
      code: 'WEGO50',
      title: 'Giảm 20.000đ',
      description: 'Áp dụng cho chuyến đầu tiên với WeGo',
      expiresAt: eoy,
      gradient: const [AppColors.primary500, AppColors.primary700],
      icon: PhosphorIconsRegular.confetti,
      discountVnd: 20000,
    ),
    PromoVoucher(
      code: 'HOLIDAY30',
      title: 'Giảm 30% cuối tuần',
      description: 'Áp dụng T7 & CN cho mọi chuyến dưới 100k',
      expiresAt: midYear,
      gradient: const [Color(0xFFEF4444), Color(0xFFC2410C)],
      icon: PhosphorIconsRegular.couch,
      discountPercent: 30,
      maxDiscountVnd: 30000,
      minOrderVnd: 40000,
    ),
    PromoVoucher(
      code: 'SUMMER100',
      title: 'Giảm 100.000đ',
      description: 'Cho chuyến đặt từ 200k trở lên trong hè',
      expiresAt: midYear,
      gradient: const [Color(0xFFF59E0B), Color(0xFFB45309)],
      icon: PhosphorIconsRegular.umbrella,
      discountVnd: 100000,
      minOrderVnd: 200000,
    ),
    PromoVoucher(
      code: 'AIRPORT15',
      title: 'Giảm 15% chuyến sân bay',
      description: 'Đặt chuyến đi/đến Sân bay Đà Nẵng',
      expiresAt: eoy,
      gradient: const [AppColors.sharedAccent, Color(0xFF0E7490)],
      icon: PhosphorIconsFill.airplaneTakeoff,
      discountPercent: 15,
      maxDiscountVnd: 25000,
      minOrderVnd: 50000,
    ),
    PromoVoucher(
      code: 'SHARE38',
      title: 'Tiết kiệm 38% xe ghép',
      description: 'Khi chọn Xe ghép thông minh — tự động áp dụng',
      expiresAt: eoy,
      gradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
      icon: PhosphorIconsRegular.usersThree,
    ),
    PromoVoucher(
      code: 'NEWUSER',
      title: 'Tặng 50.000đ cho bạn bè',
      description: 'Giới thiệu bạn mới — cả 2 cùng nhận voucher',
      expiresAt: eoy,
      gradient: const [Color(0xFFD4A574), Color(0xFF8B6F47)],
      icon: PhosphorIconsRegular.gift,
    ),
    // ── Phase 5I scheduled-ride promos ──────────────────────────────
    PromoVoucher(
      code: 'CARPOOL30',
      title: 'Giảm 30% xe ghép đặt trước',
      description: 'Áp dụng cho chuyến Xe ghép đặt lịch — tối đa 30k',
      expiresAt: eoy,
      gradient: const [Color(0xFF0EA5E9), AppColors.sharedAccent],
      icon: PhosphorIconsFill.calendarPlus,
      discountPercent: 30,
      maxDiscountVnd: 30000,
      minOrderVnd: 60000,
    ),
    PromoVoucher(
      code: 'FIRSTRIDE10',
      title: 'Giảm 10% chuyến đầu đặt trước',
      description: 'Cho lần đầu dùng tính năng đặt trước, tối đa 20k',
      expiresAt: eoy,
      gradient: const [AppColors.primary400, AppColors.primary600],
      icon: PhosphorIconsFill.sparkle,
      discountPercent: 10,
      maxDiscountVnd: 20000,
      minOrderVnd: 50000,
    ),
  ];
}
