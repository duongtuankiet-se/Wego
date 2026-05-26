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

/// 4 destinations the user can tap from the home carousel. Coords here
/// flow into `_onExploreTap` in [PassengerHomeScreen] — distances are
/// rough Đà Nẵng-area numbers used only as label text.
List<ExplorePlace> generateExplorePlaces() {
  return [
    ExplorePlace(
      id: 'city_danang',
      name: 'Đà Nẵng',
      tagline: 'Trung tâm thành phố',
      distanceKm: 0.5,
      icon: PhosphorIconsFill.city,
      gradient: const [AppColors.primary500, AppColors.primary700],
    ),
    ExplorePlace(
      id: 'city_hoian',
      name: 'Hội An',
      tagline: 'Phố cổ',
      distanceKm: 30.2,
      icon: PhosphorIconsFill.castleTurret,
      gradient: const [Color(0xFFFBBF24), Color(0xFFF59E0B)],
    ),
    ExplorePlace(
      id: 'city_banahills',
      name: 'Bà Nà Hills',
      tagline: 'Cầu Vàng',
      distanceKm: 36.0,
      icon: PhosphorIconsFill.mountains,
      gradient: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    ),
    ExplorePlace(
      id: 'city_mykhe',
      name: 'Mỹ Khê',
      tagline: 'Biển',
      distanceKm: 5.0,
      icon: PhosphorIconsFill.umbrellaSimple,
      gradient: const [Color(0xFF06B6D4), Color(0xFF0891B2)],
    ),
  ];
}
