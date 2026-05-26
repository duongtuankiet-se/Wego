import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme/app_colors.dart';

/// City shortcut shown in the passenger-home explore carousel. Each
/// entry pre-fills both the destination metadata (`name`, `tagline`) and
/// the real-world coords used by Directions/matching.
class CityExplore {
  final String id;
  final String name;
  final String tagline;
  final double distanceKm;
  final IconData icon;
  final List<Color> gradient;
  final double lat;
  final double lng;
  const CityExplore({
    required this.id,
    required this.name,
    required this.tagline,
    required this.distanceKm,
    required this.icon,
    required this.gradient,
    required this.lat,
    required this.lng,
  });
}

/// 4 Đà Nẵng-area destinations the user can tap from the home carousel.
/// Distances are rough labels; tap → drops the user into ride options
/// with these coords as the pre-selected dropoff.
const List<CityExplore> kCityExplorePlaces = [
  CityExplore(
    id: 'city_danang',
    name: 'Đà Nẵng',
    tagline: 'Trung tâm thành phố',
    distanceKm: 0.5,
    icon: PhosphorIconsFill.city,
    gradient: [AppColors.primary500, AppColors.primary700],
    lat: 16.0544,
    lng: 108.2022,
  ),
  CityExplore(
    id: 'city_hoian',
    name: 'Hội An',
    tagline: 'Phố cổ',
    distanceKm: 30.2,
    icon: PhosphorIconsFill.castleTurret,
    gradient: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
    lat: 15.8801,
    lng: 108.3380,
  ),
  CityExplore(
    id: 'city_banahills',
    name: 'Bà Nà Hills',
    tagline: 'Cầu Vàng',
    distanceKm: 36.0,
    icon: PhosphorIconsFill.mountains,
    gradient: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    lat: 15.9978,
    lng: 107.9881,
  ),
  CityExplore(
    id: 'city_mykhe',
    name: 'Mỹ Khê',
    tagline: 'Biển',
    distanceKm: 5.0,
    icon: PhosphorIconsFill.umbrellaSimple,
    gradient: [Color(0xFF06B6D4), Color(0xFF0891B2)],
    lat: 16.0742,
    lng: 108.2470,
  ),
];
