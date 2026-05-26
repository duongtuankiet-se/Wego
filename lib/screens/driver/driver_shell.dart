import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/widgets/wg_bottom_tab_bar.dart';

class DriverShell extends StatelessWidget {
  const DriverShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static final _items = [
    WgTabItem(
      icon: PhosphorIconsRegular.house,
      activeIcon: PhosphorIconsFill.house,
      label: 'Trang chủ',
    ),
    WgTabItem(
      icon: PhosphorIconsRegular.currencyDollar,
      activeIcon: PhosphorIconsFill.currencyDollar,
      label: 'Thu nhập',
    ),
    WgTabItem(
      icon: PhosphorIconsRegular.wallet,
      activeIcon: PhosphorIconsFill.wallet,
      label: 'Ví',
    ),
    WgTabItem(
      icon: PhosphorIconsRegular.trendUp,
      activeIcon: PhosphorIconsFill.trendUp,
      label: 'Hiệu suất',
    ),
    WgTabItem(
      icon: PhosphorIconsRegular.user,
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
