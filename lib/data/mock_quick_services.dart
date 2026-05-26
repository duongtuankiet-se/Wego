import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme/app_colors.dart';

/// Discriminator used by the home tap handler to dispatch each tile's
/// behaviour without hardcoding string ids.
enum QuickServiceAction {
  /// Open the regular search screen (current location → unknown dropoff).
  openSearch,

  /// Skip search and prefill the dropoff with a hardcoded Place (e.g.
  /// Đà Nẵng International Airport).
  presetDropoff,

  /// Open the map picker so the user can choose a custom pickup
  /// different from their current GPS location (e.g. "pick up a friend").
  pickCustomPickup,

  /// Show a "sắp ra mắt" toast — placeholder for future services.
  comingSoon,
}

class QuickService {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final QuickServiceAction action;
  const QuickService({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.action,
  });
}

/// 4 ride-focused services on the passenger home. Two are live (taxi
/// search + airport preset), one opens the map picker for a custom
/// pickup, one is a teaser.
const List<QuickService> kQuickServices = [
  QuickService(
    id: 'taxi',
    label: 'Xe taxi',
    icon: PhosphorIconsFill.taxi,
    color: AppColors.warning,
    action: QuickServiceAction.openSearch,
  ),
  QuickService(
    id: 'airport',
    label: 'Sân bay',
    icon: PhosphorIconsFill.airplane,
    color: AppColors.sharedAccent,
    action: QuickServiceAction.presetDropoff,
  ),
  QuickService(
    id: 'intercity',
    label: 'Liên tỉnh',
    icon: PhosphorIconsFill.airplaneTilt,
    color: Color(0xFF8B5CF6),
    action: QuickServiceAction.comingSoon,
  ),
  QuickService(
    id: 'pickup_other',
    label: 'Đi đón khách',
    icon: PhosphorIconsFill.userCircle,
    color: AppColors.danger,
    action: QuickServiceAction.pickCustomPickup,
  ),
];
