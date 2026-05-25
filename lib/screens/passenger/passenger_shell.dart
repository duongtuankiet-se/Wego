import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/wg_bottom_tab_bar.dart';

/// Hosts the 5 passenger tabs as a StatefulNavigationShell. The shell
/// keeps each tab's navigation stack independently, so jumping between
/// tabs preserves scroll positions and modal pushes.
class PassengerShell extends StatelessWidget {
  const PassengerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    WgTabItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Trang chủ',
    ),
    WgTabItem(
      icon: Icons.access_time,
      activeIcon: Icons.access_time_filled,
      label: 'Hoạt động',
    ),
    WgTabItem(
      icon: Icons.card_giftcard_outlined,
      activeIcon: Icons.card_giftcard,
      label: 'Ưu đãi',
    ),
    WgTabItem(
      icon: Icons.support_agent_outlined,
      activeIcon: Icons.support_agent,
      label: 'Hỗ trợ',
    ),
    WgTabItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Tôi',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: WgBottomTabBar(
        currentIndex: navigationShell.currentIndex,
        items: _items,
        onTap: (idx) => navigationShell.goBranch(
          idx,
          initialLocation: idx == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
