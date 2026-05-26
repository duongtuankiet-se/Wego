import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme/app_colors.dart';

class QuickService {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final bool comingSoon;
  const QuickService({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.comingSoon = false,
  });
}

const List<QuickService> kQuickServices = [
  QuickService(
    id: 'bike',
    label: 'Xe máy',
    icon: PhosphorIconsFill.motorcycle,
    color: AppColors.primary500,
  ),
  QuickService(
    id: 'taxi',
    label: 'Đặt taxi',
    icon: PhosphorIconsFill.taxi,
    color: AppColors.warning,
  ),
  QuickService(
    id: 'delivery',
    label: 'Giao hàng',
    icon: PhosphorIconsFill.package,
    color: AppColors.info,
  ),
  QuickService(
    id: 'vip',
    label: 'Hội viên',
    icon: PhosphorIconsFill.crown,
    color: AppColors.gold,
    comingSoon: true,
  ),
  QuickService(
    id: 'rent',
    label: 'Thuê xe',
    icon: PhosphorIconsFill.car,
    color: Color(0xFF8B5CF6),
    comingSoon: true,
  ),
  QuickService(
    id: 'intercity',
    label: 'Liên tỉnh',
    icon: PhosphorIconsFill.van,
    color: Color(0xFF0E7490),
    comingSoon: true,
  ),
  QuickService(
    id: 'ev',
    label: 'Xe điện',
    icon: PhosphorIconsFill.chargingStation,
    color: AppColors.success,
    comingSoon: true,
  ),
  QuickService(
    id: 'gift',
    label: 'Quà tặng',
    icon: PhosphorIconsFill.gift,
    color: Color(0xFFEC4899),
    comingSoon: true,
  ),
];
