import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class PromoVoucher {
  final String code;
  final String title;
  final String description;
  final DateTime expiresAt;
  final List<Color> gradient;
  final IconData icon;

  const PromoVoucher({
    required this.code,
    required this.title,
    required this.description,
    required this.expiresAt,
    required this.gradient,
    required this.icon,
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
      icon: Icons.celebration_outlined,
    ),
    PromoVoucher(
      code: 'HOLIDAY30',
      title: 'Giảm 30% cuối tuần',
      description: 'Áp dụng T7 & CN cho mọi chuyến dưới 100k',
      expiresAt: midYear,
      gradient: const [Color(0xFFEF4444), Color(0xFFC2410C)],
      icon: Icons.weekend_outlined,
    ),
    PromoVoucher(
      code: 'SUMMER100',
      title: 'Giảm 100.000đ',
      description: 'Cho chuyến đặt từ 200k trở lên trong hè',
      expiresAt: midYear,
      gradient: const [Color(0xFFF59E0B), Color(0xFFB45309)],
      icon: Icons.beach_access_outlined,
    ),
    PromoVoucher(
      code: 'AIRPORT15',
      title: 'Giảm 15% chuyến sân bay',
      description: 'Đặt chuyến đi/đến Sân bay Đà Nẵng',
      expiresAt: eoy,
      gradient: const [AppColors.sharedAccent, Color(0xFF0E7490)],
      icon: Icons.flight_takeoff,
    ),
    PromoVoucher(
      code: 'SHARE38',
      title: 'Tiết kiệm 38% xe ghép',
      description: 'Khi chọn Xe ghép thông minh — tự động áp dụng',
      expiresAt: eoy,
      gradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
      icon: Icons.groups_outlined,
    ),
    PromoVoucher(
      code: 'NEWUSER',
      title: 'Tặng 50.000đ cho bạn bè',
      description: 'Giới thiệu bạn mới — cả 2 cùng nhận voucher',
      expiresAt: eoy,
      gradient: const [Color(0xFFD4A574), Color(0xFF8B6F47)],
      icon: Icons.card_giftcard_outlined,
    ),
  ];
}
