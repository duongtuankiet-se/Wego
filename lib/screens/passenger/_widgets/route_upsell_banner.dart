import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/route.dart';
import '../../../providers/scheduled_trips_provider.dart';

/// Phase 5Q: shown in free-point mode when the entered pickup +
/// dropoff line up with one of the preset corridors — gives the user
/// a 1-tap "switch to flat fare" shortcut.
class RouteUpsellBanner extends ConsumerWidget {
  const RouteUpsellBanner({super.key, required this.route});
  final RoutePreset route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsFill.lightning,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Có tuyến cố định cho chuyến này',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${route.name} · chỉ ${route.fareLabel}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => ref
                .read(scheduleRideFormProvider.notifier)
                .acceptUpsellRoute(),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Đổi',
              style: AppTypography.caption.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
