import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/widgets/wg_bottom_tab_bar.dart';

/// Hosts the 5 passenger tabs as a StatefulNavigationShell. The shell
/// keeps each tab's navigation stack independently, so jumping between
/// tabs preserves scroll positions and modal pushes.
class PassengerShell extends StatelessWidget {
  const PassengerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    WgTabItem(
      icon: PhosphorIconsRegular.house,
      activeIcon: PhosphorIconsFill.house,
      label: 'Trang chủ',
    ),
    WgTabItem(
      icon: PhosphorIconsRegular.clock,
      activeIcon: PhosphorIconsFill.clock,
      label: 'Hoạt động',
    ),
    WgTabItem(
      icon: PhosphorIconsRegular.gift,
      activeIcon: PhosphorIconsFill.gift,
      label: 'Ưu đãi',
    ),
    WgTabItem(
      icon: PhosphorIconsRegular.headset,
      activeIcon: PhosphorIconsFill.headset,
      label: 'Hỗ trợ',
    ),
    WgTabItem(
      icon: PhosphorIconsRegular.userCircle,
      activeIcon: PhosphorIconsFill.user,
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
