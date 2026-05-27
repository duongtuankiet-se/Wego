import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/format.dart';
import '../../../models/trip_pool.dart';

/// Single pool tile used in both the "Available" (confirmed) and
/// "Watching" (collecting) tabs of the Driver Pools screen.
///
/// Pass [onAccept] only for actionable cards — the watching tab leaves
/// it null which hides the CTA so drivers can't tap an unready pool.
class PoolCard extends StatelessWidget {
  const PoolCard({
    super.key,
    required this.pool,
    this.onAccept,
  });

  final TripPool pool;
  final VoidCallback? onAccept;

  String _formatDeadline(DateTime deadline) {
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) return 'đã quá hạn';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}p';
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = pool.status == TripPoolStatus.confirmed;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.xs,
        border: Border.all(
          color: isConfirmed ? AppColors.success : AppColors.ink200,
          width: isConfirmed ? 1.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isConfirmed
                        ? AppColors.success
                        : AppColors.warning,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isConfirmed ? 'Đã đủ khách' : 'Đang gom',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  pool.poolCode,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pool.routeLabel,
                  style: AppTypography.h3.copyWith(
                    color: AppColors.ink900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.clock,
                      size: 14,
                      color: AppColors.ink500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      pool.scheduledAtVN,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.ink50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            PhosphorIconsFill.usersThree,
                            size: 16,
                            color: AppColors.primary500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            pool.progressLabel,
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Xe ${pool.vehicleSeats} chỗ',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.ink600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: pool.progressToThreshold,
                          minHeight: 6,
                          backgroundColor: AppColors.ink200,
                          color: pool.isThresholdMet
                              ? AppColors.success
                              : AppColors.primary500,
                        ),
                      ),
                      if (!isConfirmed) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              PhosphorIconsRegular.timer,
                              size: 13,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Còn ${_formatDeadline(pool.cancelDeadline)} trước khi pool huỷ',
                              style: AppTypography.micro.copyWith(
                                color: AppColors.ink600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Doanh thu dự kiến',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatVnd(
                        pool.estimatedFarePerPax * pool.currentPassengers,
                      ),
                      style: AppTypography.body.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary700,
                      ),
                    ),
                  ],
                ),
                if (onAccept != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onAccept,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(PhosphorIconsBold.check, size: 18),
                      label: const Text(
                        'Nhận pool',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
