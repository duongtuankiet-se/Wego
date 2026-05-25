import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum WgBadgeVariant { info, success, shared, surge }

class WgBadge extends StatelessWidget {
  const WgBadge({
    super.key,
    required this.label,
    this.variant = WgBadgeVariant.info,
  });

  final String label;
  final WgBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color fg}) c = switch (variant) {
      WgBadgeVariant.info => (
        bg: AppColors.info.withValues(alpha: 0.12),
        fg: AppColors.info,
      ),
      WgBadgeVariant.success => (
        bg: AppColors.success.withValues(alpha: 0.14),
        fg: AppColors.success,
      ),
      WgBadgeVariant.shared => (
        bg: AppColors.sharedAccent.withValues(alpha: 0.14),
        fg: AppColors.sharedAccent,
      ),
      WgBadgeVariant.surge => (
        bg: AppColors.surge.withValues(alpha: 0.14),
        fg: AppColors.surge,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.micro.copyWith(color: c.fg),
      ),
    );
  }
}
