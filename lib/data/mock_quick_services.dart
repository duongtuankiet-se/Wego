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

/// 4 ride-only services. Taxi is the only one that's live; the rest are
/// teaser tiles that show a "sắp ra mắt" toast.
const List<QuickService> kQuickServices = [
  QuickService(
    id: 'taxi',
    label: 'Xe taxi',
    icon: PhosphorIconsFill.taxi,
    color: AppColors.warning,
  ),
  QuickService(
    id: 'bike',
    label: 'Xe máy',
    icon: PhosphorIconsFill.motorcycle,
    color: AppColors.sharedAccent,
    comingSoon: true,
  ),
  QuickService(
    id: 'intercity',
    label: 'Liên tỉnh',
    icon: PhosphorIconsFill.airplaneTilt,
    color: Color(0xFF8B5CF6),
    comingSoon: true,
  ),
  QuickService(
    id: 'rent',
    label: 'Thuê xe',
    icon: PhosphorIconsFill.key,
    color: AppColors.danger,
    comingSoon: true,
  ),
];
