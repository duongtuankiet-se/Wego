import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/wg_avatar.dart';
import '../../core/widgets/wg_bar_chart.dart';
import '../../core/widgets/wg_metric_tile.dart';
import '../../data/mock_reviews.dart';
import '../../providers/driver_provider.dart';
import '../../providers/earnings_provider.dart';
import '_widgets/review_card.dart';

class DriverPerformanceScreen extends ConsumerWidget {
  const DriverPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(currentDriverProvider).valueOrNull;
    final weekly =
        ref.watch(driverWeeklyCountsProvider).valueOrNull ??
        const [0, 0, 0, 0, 0, 0, 0];
    final reviews = generateMockReviews();
    final todayIdx = DateTime.now().weekday - 1;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Hiệu suất'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LevelCard(
            name: driver?.name ?? 'Tài xế WeGo',
            rating: driver?.ratingAvg ?? 0,
            totalTrips: driver?.totalTrips ?? 0,
          ),
          const SizedBox(height: 16),
          _MetricsCard(
            acceptRate: 0.94,
            cancelRate: 0.021,
            rating: (driver?.ratingAvg ?? 0).clamp(0, 5).toDouble(),
            totalTrips: driver?.totalTrips ?? 0,
          ),
          const SizedBox(height: 16),
          _WeeklyChartCard(values: weekly, todayIdx: todayIdx),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Đánh giá gần đây',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.ink900,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...reviews.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ReviewCard(review: r),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.name,
    required this.rating,
    required this.totalTrips,
  });
  final String name;
  final double rating;
  final int totalTrips;

  static const _gold = Color(0xFFD4A574);
  static const _platinum = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    const target = 1000;
    final progress = (totalTrips / target).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink900.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 36,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_gold, Color(0xFFB8915E)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Center(
              child: Text(
                'TÀI XẾ KIM CƯƠNG',
                style: AppTypography.micro.copyWith(
                  color: Colors.white,
                  // Heavy tracking is fine on uppercase Latin (no
                  // diacritic collision here — VI uppercase still
                  // breathes at 1.4 because there are no accents).
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    WgAvatar(
                      name: name,
                      size: 56,
                      rating: rating > 0 ? rating : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.ink900,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                PhosphorIconsFill.star,
                                color: AppColors.warning,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${rating > 0 ? rating.toStringAsFixed(2) : "—"} · $totalTrips chuyến',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.ink500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tiến độ lên hạng Bạch Kim',
                    style: AppTypography.body.copyWith(
                      color: AppColors.ink700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 10,
                      backgroundColor: _platinum,
                      valueColor: const AlwaysStoppedAnimation(_gold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$totalTrips / $target điểm',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink500,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      'Cần thêm ${(target - totalTrips).clamp(0, target)} điểm',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary500,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({
    required this.acceptRate,
    required this.cancelRate,
    required this.rating,
    required this.totalTrips,
  });
  final double acceptRate;
  final double cancelRate;
  final double rating;
  final int totalTrips;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chỉ số tháng này',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.ink900,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            // Phase 5O: 1.35 left ~26px of overflow because 3/4 tiles
            // render the optional progress bar. 1.0 gives the tile
            // enough vertical room for icon + h1 value + label + bar.
            childAspectRatio: 1.0,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              WgMetricTile(
                icon: PhosphorIconsRegular.checkCircle,
                value: '${(acceptRate * 100).round()}%',
                label: 'Tỷ lệ nhận chuyến',
                iconColor: AppColors.success,
                progress: acceptRate,
                progressColor: AppColors.success,
              ),
              WgMetricTile(
                icon: PhosphorIconsRegular.xCircle,
                value: '${(cancelRate * 100).toStringAsFixed(1)}%',
                label: 'Tỷ lệ huỷ',
                iconColor: AppColors.success,
                progress: 1 - cancelRate,
                progressColor: AppColors.success,
              ),
              WgMetricTile(
                icon: PhosphorIconsFill.star,
                value: rating > 0 ? rating.toStringAsFixed(2) : '—',
                label: 'Đánh giá TB',
                iconColor: AppColors.warning,
                progress: rating / 5,
                progressColor: AppColors.warning,
              ),
              WgMetricTile(
                icon: PhosphorIconsFill.car,
                value: totalTrips.toString(),
                label: 'Tổng chuyến',
                iconColor: AppColors.primary500,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyChartCard extends StatelessWidget {
  const _WeeklyChartCard({required this.values, required this.todayIdx});
  final List<int> values;
  final int todayIdx;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hoạt động tuần này',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.ink900,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Số chuyến hoàn thành mỗi ngày',
            style: AppTypography.caption.copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: 18),
          WgBarChart(
            values: values,
            labels: const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'],
            highlightIndex: todayIdx,
          ),
        ],
      ),
    );
  }
}
