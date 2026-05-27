import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// One option inside the payment-method selector. Supports both icon-based
/// chips (cash/card) and brand-letter chips (MoMo/ZaloPay).
class WgPaymentChip extends StatelessWidget {
  const WgPaymentChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.brandLetter,
    this.brandColor,
  }) : assert(
         icon != null || brandLetter != null,
         'Provide either icon or brandLetter',
       );

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? brandLetter;
  final Color? brandColor;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.primary500 : AppColors.ink300;
    final bgColor = selected ? AppColors.primary50 : AppColors.white;

    return AnimatedScale(
      scale: selected ? 1.0 : 0.97,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: selected ? 2 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null)
                  Icon(icon, size: 22, color: AppColors.primary500)
                else
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: brandColor ?? AppColors.primary500,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      brandLetter!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: AppTypography.body.copyWith(
                    color: AppColors.ink900,
                    fontWeight: FontWeight.w600,
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
