import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/format.dart';

class FareBreakdownRow {
  const FareBreakdownRow({
    required this.label,
    required this.amount,
    this.color,
    this.negative = false,
  });

  final String label;
  final int amount;
  final Color? color;
  final bool negative;
}

class FareBreakdown extends StatelessWidget {
  const FareBreakdown({
    super.key,
    required this.rows,
    required this.total,
    this.totalLabel = 'Tổng cộng',
  });

  final List<FareBreakdownRow> rows;
  final int total;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...rows.map(
          (r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  r.label,
                  style: AppTypography.body.copyWith(color: AppColors.ink700),
                ),
                Text(
                  '${r.negative ? '-' : ''}${formatVnd(r.amount)}',
                  style: AppTypography.body.copyWith(
                    color: r.color ?? AppColors.ink700,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.ink100),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalLabel,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.ink900,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                formatVnd(total),
                style: AppTypography.h2.copyWith(
                  color: AppColors.primary500,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
