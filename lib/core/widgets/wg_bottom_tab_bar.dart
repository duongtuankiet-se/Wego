import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class WgBottomTabBar extends StatelessWidget {
  const WgBottomTabBar({super.key, required this.activeIndex, this.onTap});

  final int activeIndex;
  final ValueChanged<int>? onTap;

  static const _tabs = [
    (Icons.home_rounded, Icons.home_outlined, 'Trang chủ'),
    (Icons.access_time_filled_rounded, Icons.access_time, 'Hoạt động'),
    (Icons.card_giftcard_rounded, Icons.card_giftcard_outlined, 'Ưu đãi'),
    (Icons.person_rounded, Icons.person_outline, 'Tài khoản'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.ink100, width: 0.5)),
      ),
      child: SizedBox(
        height: 64 + bottomInset,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final active = i == activeIndex;
              final (iconOn, iconOff, label) = _tabs[i];
              final color = active ? AppColors.primary500 : AppColors.ink500;
              return Expanded(
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap?.call(i);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(active ? iconOn : iconOff, color: color, size: 24),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: AppTypography.micro.copyWith(
                          color: color,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          letterSpacing: 0.2,
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
    );
  }
}
