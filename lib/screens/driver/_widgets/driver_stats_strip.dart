import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class DriverStatsStrip extends StatelessWidget {
  const DriverStatsStrip({
    super.key,
    required this.earningsLabel,
    required this.tripCount,
    required this.activeLabel,
    required this.rating,
  });

  /// Pre-formatted strings (e.g. "540K", "6h24p") so the parent owns
  /// formatting and we stay layout-only.
  final String earningsLabel;
  final int tripCount;
  final String activeLabel;
  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink900.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _cell(
            PhosphorIconsRegular.currencyDollar,
            AppColors.success,
            earningsLabel,
            'Thu nhập',
          ),
          const _Divider(),
          _cell(
            PhosphorIconsFill.car,
            AppColors.primary500,
            '$tripCount',
            'Chuyến',
          ),
          const _Divider(),
          _cell(
            PhosphorIconsRegular.clock,
            AppColors.warning,
            activeLabel,
            'Hoạt động',
          ),
          const _Divider(),
          _cell(
            PhosphorIconsFill.star,
            AppColors.warning,
            rating > 0 ? rating.toStringAsFixed(2) : '—',
            'Đánh giá',
          ),
        ],
      ),
    );
  }

  Widget _cell(IconData icon, Color color, String value, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.body.copyWith(
              color: AppColors.ink900,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: AppTypography.micro.copyWith(color: AppColors.ink500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Container(width: 0.5, height: 40, color: AppColors.ink300);
  }
}
