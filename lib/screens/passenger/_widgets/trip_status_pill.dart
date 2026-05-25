import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Floating glass pill that shows the current trip phase + ETA.
class TripStatusPill extends StatelessWidget {
  const TripStatusPill({
    super.key,
    required this.label,
    required this.emphasis,
    this.icon = Icons.directions_car,
  });

  /// Leading text, e.g. "Tài xế đến sau ".
  final String label;

  /// Highlighted suffix, e.g. "3 phút".
  final String emphasis;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: Container(
        key: ValueKey('$label$emphasis'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.white.withValues(alpha: 0.6),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink900.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: AppColors.primary100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: AppColors.primary500),
            ),
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(
                style: AppTypography.body.copyWith(
                  color: AppColors.ink900,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(text: label),
                  TextSpan(
                    text: emphasis,
                    style: const TextStyle(
                      color: AppColors.primary500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}
