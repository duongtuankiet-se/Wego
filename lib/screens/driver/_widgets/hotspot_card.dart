import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/wg_button.dart';
import '../../../data/mock_hotspots.dart';

class HotspotCard extends StatelessWidget {
  const HotspotCard({super.key, required this.hotspot, required this.onTap});
  final Hotspot hotspot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink100),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hotspot.heatColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(hotspot.icon, color: hotspot.heatColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hotspot.name,
                  style: AppTypography.body.copyWith(
                    color: AppColors.ink900,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${hotspot.activeRequests} yêu cầu',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.sharedAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '  ·  ${hotspot.distanceKm.toStringAsFixed(1)} km',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          WgButton.ghost(
            label: 'Chỉ đường',
            size: WgButtonSize.sm,
            trailingIcon: PhosphorIconsRegular.arrowRight,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
