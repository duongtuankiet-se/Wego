import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum WgStatusTone { warning, success, danger, info }

/// Inline status badge — icon + label on a tinted background. Used on
/// trip cards, driver notification rows, etc.
class WgStatusBadge extends StatelessWidget {
  const WgStatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final WgStatusTone tone;
  final IconData? icon;

  Color get _color {
    switch (tone) {
      case WgStatusTone.warning:
        return AppColors.warning;
      case WgStatusTone.success:
        return AppColors.success;
      case WgStatusTone.danger:
        return AppColors.danger;
      case WgStatusTone.info:
        return AppColors.info;
    }
  }

  IconData get _defaultIcon {
    switch (tone) {
      case WgStatusTone.success:
        return PhosphorIconsFill.checkCircle;
      case WgStatusTone.danger:
        return PhosphorIconsFill.xCircle;
      case WgStatusTone.warning:
        return PhosphorIconsFill.clockCountdown;
      case WgStatusTone.info:
        return PhosphorIconsFill.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? _defaultIcon, color: c, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.micro.copyWith(
              color: c,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
