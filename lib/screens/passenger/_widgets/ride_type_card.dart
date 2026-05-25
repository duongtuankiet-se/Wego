import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/wg_badge.dart';

class RideTypeCard extends StatelessWidget {
  const RideTypeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.etaLabel,
    required this.price,
    required this.selected,
    required this.onTap,
    this.strikethroughPrice,
    this.savingBadge,
  });

  final IconData icon;
  final String title;
  final String etaLabel;
  final int price;
  final bool selected;
  final VoidCallback onTap;
  final int? strikethroughPrice;
  final String? savingBadge;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.0 : 0.99,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.primary500 : AppColors.ink300,
                width: selected ? 2 : 1,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: AppColors.primary500, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.ink900,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            etaLabel,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.ink500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (strikethroughPrice != null)
                          Text(
                            formatVnd(strikethroughPrice!),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.ink500,
                              decoration: TextDecoration.lineThrough,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        Text(
                          formatVnd(price),
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.primary500,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (savingBadge != null)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: WgBadge(
                      label: savingBadge!,
                      variant: WgBadgeVariant.shared,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
