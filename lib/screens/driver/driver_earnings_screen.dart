import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/wg_incentive_card.dart';
import '../../core/widgets/wg_sparkline.dart';
import '../../core/widgets/wg_toast.dart';
import '../../providers/earnings_provider.dart';

class DriverEarningsScreen extends ConsumerStatefulWidget {
  const DriverEarningsScreen({super.key});
  @override
  ConsumerState<DriverEarningsScreen> createState() =>
      _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends ConsumerState<DriverEarningsScreen> {
  int _tabIdx = 0;
  static const _tabs = ['Hôm nay', 'Tuần này', 'Tháng', 'Năm'];

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(driverTodayStatsProvider);
    final recentAsync = ref.watch(driverRecentTripsProvider);

    final earnings = statsAsync.valueOrNull?.earningsVnd ?? 0;
    final tripCount = statsAsync.valueOrNull?.tripCount ?? 0;
    final activeMin = statsAsync.valueOrNull?.activeMinutes ?? 0;
    final gross = (earnings * 1.176).round();
    final commission = (gross - earnings).round();
    const tip = 0;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Thu nhập'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.faders),
            onPressed: () => WgToast.info(context, 'Bộ lọc sắp ra mắt'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroCard(
            earnings: earnings,
            tripCount: tripCount,
            activeMin: activeMin,
          ),
          const SizedBox(height: 16),
          _SegmentedTabs(
            tabs: _tabs,
            selected: _tabIdx,
            onChange: (i) {
              setState(() => _tabIdx = i);
              if (i != 0) {
                WgToast.info(context, 'Dữ liệu mock — chỉ "Hôm nay" là thật');
              }
            },
          ),
          const SizedBox(height: 16),
          _BreakdownCard(
            gross: gross,
            commission: commission,
            tip: tip,
            net: earnings,
          ),
          const SizedBox(height: 16),
          WgIncentiveCard(
            title: 'Thưởng chăm chỉ',
            completed: tripCount,
            target: 20,
            rewardVnd: 200000,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Chuyến gần đây',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.ink900,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          recentAsync.when(
            data: (rows) => rows.isEmpty
                ? _EmptyRecent()
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: List.generate(rows.length, (i) {
                        final r = rows[i];
                        return Column(
                          children: [
                            ListTile(
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  PhosphorIconsFill.car,
                                  color: AppColors.primary500,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                '${r.pickupAddress} → ${r.dropoffAddress}',
                                style: AppTypography.body.copyWith(
                                  color: AppColors.ink900,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${_time(r.completedAt)} · ${r.distanceKm.toStringAsFixed(1)} km',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.ink500,
                                ),
                              ),
                              trailing: Text(
                                '+${formatVnd(r.price)}',
                                style: AppTypography.body.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            if (i < rows.length - 1)
                              const Divider(
                                height: 1,
                                color: AppColors.ink100,
                                indent: 68,
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => _EmptyRecent(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _time(DateTime dt) {
    final l = dt.toLocal();
    final hh = l.hour.toString().padLeft(2, '0');
    final mm = l.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.earnings,
    required this.tripCount,
    required this.activeMin,
  });
  final int earnings;
  final int tripCount;
  final int activeMin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary500, AppColors.primary700],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary500.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thu nhập hôm nay',
            style: AppTypography.body.copyWith(
              color: AppColors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: earnings.toDouble()),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              formatVnd(v.round()),
              style: AppTypography.display.copyWith(
                color: AppColors.white,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                PhosphorIconsRegular.trendUp,
                color: AppColors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '+12% so với hôm qua',
                style: AppTypography.caption.copyWith(
                  color: AppColors.white.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$tripCount chuyến · ${_dur(activeMin)} hoạt động',
            style: AppTypography.caption.copyWith(
              color: AppColors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 20),
          const WgSparkline(
            values: [320, 420, 380, 540, 480, 620, 540],
            height: 50,
          ),
        ],
      ),
    );
  }

  String _dur(int m) {
    if (m == 0) return '0p';
    final h = m ~/ 60;
    final mm = m % 60;
    return h == 0 ? '${mm}p' : '${h}h${mm}p';
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.tabs,
    required this.selected,
    required this.onChange,
  });
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.ink100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChange(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  color: active ? AppColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.ink900.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    tabs[i],
                    style: AppTypography.body.copyWith(
                      color: active ? AppColors.ink900 : AppColors.ink500,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.gross,
    required this.commission,
    required this.tip,
    required this.net,
  });
  final int gross;
  final int commission;
  final int tip;
  final int net;

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
            'Chi tiết',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.ink900,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _row('Doanh thu gộp', formatVnd(gross), AppColors.ink500),
          _row(
            'Hoa hồng WeGo (15%)',
            '-${formatVnd(commission)}',
            AppColors.danger,
          ),
          _row('Tiền tip khách', '+${formatVnd(tip)}', AppColors.success),
          const Divider(height: 20, color: AppColors.ink100),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Thực nhận',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.ink900,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                formatVnd(net),
                style: AppTypography.h2.copyWith(
                  color: AppColors.primary500,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.body.copyWith(color: AppColors.ink700),
        ),
        Text(
          value,
          style: AppTypography.body.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
      ],
    ),
  );
}

class _EmptyRecent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            PhosphorIconsRegular.wrench,
            color: AppColors.ink300,
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            'Chưa có chuyến hôm nay.\nBật nhận chuyến để bắt đầu!',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.ink500),
          ),
        ],
      ),
    );
  }
}
