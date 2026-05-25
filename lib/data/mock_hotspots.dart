import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class Hotspot {
  final String id;
  final String name;
  final String shortLabel;
  final double lat;
  final double lng;
  final int activeRequests;
  final double distanceKm;
  final Color heatColor;
  final double heatRadius;
  final IconData icon;

  const Hotspot({
    required this.id,
    required this.name,
    required this.shortLabel,
    required this.lat,
    required this.lng,
    required this.activeRequests,
    required this.distanceKm,
    required this.heatColor,
    required this.heatRadius,
    required this.icon,
  });
}

/// 3 demand zones around Đà Nẵng for the driver-side heat map.
const List<Hotspot> kHotspots = [
  Hotspot(
    id: 'h1',
    name: 'Sân bay Đà Nẵng',
    shortLabel: 'Sân bay',
    lat: 16.0439,
    lng: 108.1995,
    activeRequests: 45,
    distanceKm: 4.2,
    heatColor: AppColors.danger,
    heatRadius: 80,
    icon: Icons.flight,
  ),
  Hotspot(
    id: 'h2',
    name: 'Vincom Đà Nẵng',
    shortLabel: 'Vincom',
    lat: 16.0639,
    lng: 108.2391,
    activeRequests: 28,
    distanceKm: 2.1,
    heatColor: AppColors.warning,
    heatRadius: 60,
    icon: Icons.storefront,
  ),
  Hotspot(
    id: 'h3',
    name: 'Cầu Rồng',
    shortLabel: 'Cầu Rồng',
    lat: 16.0612,
    lng: 108.2272,
    activeRequests: 19,
    distanceKm: 1.4,
    heatColor: Color(0xFFFFC107),
    heatRadius: 50,
    icon: Icons.location_city,
  ),
];
