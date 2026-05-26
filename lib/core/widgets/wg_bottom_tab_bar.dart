import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class WgTabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const WgTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Glassmorphic bottom navigation. Compatible with both the legacy
/// 4-item shape (`activeIndex` + `onTap` callback) and the Phase 4
/// shell-driven shape (`items` + `currentIndex`).
class WgBottomTabBar extends StatelessWidget {
  const WgBottomTabBar({
    super.key,
    this.activeIndex,
    this.currentIndex,
    this.items,
    this.onTap,
  });

  /// Legacy alias for [currentIndex].
  final int? activeIndex;
  final int? currentIndex;
  final List<WgTabItem>? items;
  final ValueChanged<int>? onTap;

  static final List<WgTabItem> _defaultItems = [
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
      icon: PhosphorIconsRegular.user,
      activeIcon: PhosphorIconsFill.user,
      label: 'Tôi',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = items ?? _defaultItems;
    final current = currentIndex ?? activeIndex ?? 0;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.88),
            border: const Border(
              top: BorderSide(color: AppColors.ink100, width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: List.generate(tabs.length, (i) {
                  final active = i == current;
                  final t = tabs[i];
                  final color = active
                      ? AppColors.primary500
                      : AppColors.ink400;
                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onTap?.call(i);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              active ? t.activeIcon : t.icon,
                              key: ValueKey(active),
                              color: color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t.label,
                            style: AppTypography.micro.copyWith(
                              color: color,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 10.5,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: active ? 14 : 0,
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppColors.primary500,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
