import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme/app_colors.dart';

class ExplorePlace {
  final String id;
  final String name;
  final String tagline;
  final double distanceKm;
  final IconData icon;
  final List<Color> gradient;
  const ExplorePlace({
    required this.id,
    required this.name,
    required this.tagline,
    required this.distanceKm,
    required this.icon,
    required this.gradient,
  });
}

List<ExplorePlace> generateExplorePlaces() {
  return [
    ExplorePlace(
      id: 'ep1',
      name: 'Sân bay Đà Nẵng',
      tagline: 'Đưa đón giá tốt',
      distanceKm: 4.2,
      icon: PhosphorIconsFill.airplane,
      gradient: const [AppColors.info, Color(0xFF0E7490)],
    ),
    ExplorePlace(
      id: 'ep2',
      name: 'Vincom Đà Nẵng',
      tagline: 'Mua sắm cuối tuần',
      distanceKm: 2.1,
      icon: PhosphorIconsFill.storefront,
      gradient: const [Color(0xFFEF4444), Color(0xFFB91C1C)],
    ),
    ExplorePlace(
      id: 'ep3',
      name: 'Bà Nà Hills',
      tagline: 'Cầu Vàng huyền thoại',
      distanceKm: 28.0,
      icon: PhosphorIconsFill.mountains,
      gradient: const [AppColors.primary500, AppColors.primary700],
    ),
    ExplorePlace(
      id: 'ep4',
      name: 'Cầu Rồng',
      tagline: 'Biểu tượng thành phố',
      distanceKm: 1.4,
      icon: PhosphorIconsFill.buildings,
      gradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    ),
    ExplorePlace(
      id: 'ep5',
      name: 'Biển Mỹ Khê',
      tagline: 'Top 6 biển đẹp châu Á',
      distanceKm: 3.6,
      icon: PhosphorIconsFill.umbrella,
      gradient: const [Color(0xFF06B6D4), Color(0xFF0891B2)],
    ),
    ExplorePlace(
      id: 'ep6',
      name: 'Chợ Hàn',
      tagline: 'Ẩm thực địa phương',
      distanceKm: 1.8,
      icon: PhosphorIconsFill.shoppingBag,
      gradient: const [Color(0xFFF59E0B), Color(0xFFB45309)],
    ),
  ];
}
