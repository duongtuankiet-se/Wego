import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Mini origin→destination connector card with distance/eta footer.
/// Reused on RideOptions and LiveTrip bottom sheets.
class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({
    super.key,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.distanceKm,
    this.durationMin,
    this.dense = false,
  });

  final String pickupAddress;
  final String dropoffAddress;
  final double? distanceKm;
  final int? durationMin;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final gap = dense ? 8.0 : 12.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: dense ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _Connector(gap: gap),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickupAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: gap + 6),
                    Text(
                      dropoffAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (distanceKm != null && durationMin != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.ink100),
            const SizedBox(height: 10),
            Text(
              '${distanceKm!.toStringAsFixed(1)} km · $durationMin phút ước tính',
              style: AppTypography.caption.copyWith(
                color: AppColors.ink500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.gap});
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
        ),
        Container(width: 1.5, height: gap + 14, color: AppColors.ink300),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
