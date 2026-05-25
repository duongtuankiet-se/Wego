import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/wg_bottom_tab_bar.dart';

class DriverShell extends StatelessWidget {
  const DriverShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    WgTabItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Trang chủ',
    ),
    WgTabItem(
      icon: Icons.attach_money,
      activeIcon: Icons.attach_money,
      label: 'Thu nhập',
    ),
    WgTabItem(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet,
      label: 'Ví',
    ),
    WgTabItem(
      icon: Icons.trending_up,
      activeIcon: Icons.trending_up,
      label: 'Hiệu suất',
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
