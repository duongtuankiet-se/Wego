import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/format.dart';

/// Gold-tinted promotional card shared between Driver Home + Earnings.
class WgIncentiveCard extends StatelessWidget {
  const WgIncentiveCard({
    super.key,
    required this.title,
    required this.completed,
    required this.target,
    required this.rewardVnd,
  });

  final String title;
  final int completed;
  final int target;
  final int rewardVnd;

  static const _gold = Color(0xFFD4A574);
  static const _goldBg = Color(0xFFFFF8EC);
  static const _goldFg = Color(0xFF8B6F47);

  @override
  Widget build(BuildContext context) {
    final remaining = (target - completed).clamp(0, target);
    final progress = target == 0 ? 0.0 : (completed / target).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _goldBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  PhosphorIconsFill.fire,
                  color: _gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: AppTypography.bodyLarge.copyWith(
                  color: _goldFg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Hoàn thành $completed/$target chuyến hôm nay',
            style: AppTypography.body.copyWith(
              color: AppColors.ink700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: AppColors.ink100,
                valueColor: const AlwaysStoppedAnimation(_gold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Còn $remaining chuyến',
                style: AppTypography.caption.copyWith(color: AppColors.ink500),
              ),
              Text(
                'Nhận thưởng ${formatVnd(rewardVnd)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
