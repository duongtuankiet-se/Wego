import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/format.dart';
import '../../../models/trip_pool.dart';
import '../../../providers/trip_pools_provider.dart';

/// Live pool status card injected into ScheduleDetail + ScheduleConfirmation.
/// Polls every 5s via [tripPoolDetailProvider]; renders nothing while
/// the pool doc is loading so it never flashes an empty placeholder.
class PoolTrackingCard extends ConsumerWidget {
  const PoolTrackingCard({super.key, required this.poolId});
  final String poolId;

  IconData _statusIcon(TripPoolStatus s) => switch (s) {
    TripPoolStatus.collecting => PhosphorIconsFill.usersThree,
    TripPoolStatus.confirmed => PhosphorIconsFill.checkCircle,
    TripPoolStatus.assigned => PhosphorIconsFill.steeringWheel,
    TripPoolStatus.started => PhosphorIconsFill.car,
    TripPoolStatus.completed => PhosphorIconsFill.flagCheckered,
    TripPoolStatus.cancelledNoPool ||
    TripPoolStatus.cancelledNoDriver => PhosphorIconsFill.xCircle,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolAsync = ref.watch(tripPoolDetailProvider(poolId));
    return poolAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (pool) {
        if (pool == null) return const SizedBox.shrink();
        return _Card(pool: pool, icon: _statusIcon(pool.status));
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.pool, required this.icon});
  final TripPool pool;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary500, AppColors.primary700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.heroGlow(AppColors.primary500),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pool.status.label,
                  style: AppTypography.body.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                pool.poolCode,
                style: AppTypography.caption.copyWith(
                  color: AppColors.white.withValues(alpha: 0.85),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            pool.routeLabel,
            style: AppTypography.h3.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.clock,
                color: AppColors.white.withValues(alpha: 0.9),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'Khởi hành ${pool.scheduledAtVN}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      pool.progressLabel,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (pool.isThresholdMet)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Đã đủ',
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pool.progressToThreshold,
                    minHeight: 8,
                    backgroundColor: AppColors.white.withValues(alpha: 0.25),
                    color: pool.isThresholdMet
                        ? AppColors.success
                        : AppColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _hint(pool),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                PhosphorIconsFill.car,
                color: AppColors.white.withValues(alpha: 0.9),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'Xe ${pool.vehicleSeats} chỗ',
                style: AppTypography.caption.copyWith(
                  color: AppColors.white.withValues(alpha: 0.92),
                ),
              ),
              const Spacer(),
              Text(
                '${formatVnd(pool.estimatedFarePerPax)}/người',
                style: AppTypography.caption.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _hint(TripPool pool) {
    if (pool.status == TripPoolStatus.collecting) {
      final need = pool.minThreshold - pool.currentPassengers;
      return 'Còn cần $need khách nữa';
    }
    if (pool.status == TripPoolStatus.confirmed) {
      return 'Đang đợi tài xế nhận pool…';
    }
    if (pool.status == TripPoolStatus.assigned) {
      return 'Tài xế sẽ đón bạn theo lịch';
    }
    if (pool.status == TripPoolStatus.started) return 'Pool đang trên đường';
    if (pool.status == TripPoolStatus.completed) return 'Chuyến đã hoàn tất';
    return pool.cancelledReason ?? 'Pool đã huỷ';
  }
}
