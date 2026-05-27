import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/wg_button.dart';
import '../../providers/current_trip_provider.dart';

class DriverTripCompletedScreen extends ConsumerStatefulWidget {
  const DriverTripCompletedScreen({super.key, required this.tripId});
  final String tripId;
  @override
  ConsumerState<DriverTripCompletedScreen> createState() =>
      _DriverTripCompletedScreenState();
}

class _DriverTripCompletedScreenState
    extends ConsumerState<DriverTripCompletedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(currentTripProvider);
    final earnings = trip?.trip.price ?? 0;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              ScaleTransition(
                scale: CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIconsBold.check,
                    color: AppColors.success,
                    size: 52,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Hoàn thành chuyến!',
                style: AppTypography.display.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Cảm ơn bạn đã hoàn thành an toàn',
                style: AppTypography.body.copyWith(color: AppColors.ink500),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Text(
                      'Thu nhập chuyến',
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatVnd(earnings),
                      style: AppTypography.display.copyWith(
                        color: AppColors.primary500,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Đã cộng vào ví của bạn',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink500,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              WgButton.primary(
                label: 'Về trang chủ',
                size: WgButtonSize.lg,
                isFullWidth: true,
                trailingIcon: PhosphorIconsRegular.arrowRight,
                onPressed: () {
                  ref.read(currentTripProvider.notifier).clear();
                  context.go('/driver/home');
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
