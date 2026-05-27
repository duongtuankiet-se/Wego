import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_toast.dart';
import '../../models/scheduled_trip.dart';
import '../../providers/scheduled_trips_provider.dart';
import '_widgets/pool_tracking_card.dart';

class ScheduleConfirmationScreen extends ConsumerStatefulWidget {
  const ScheduleConfirmationScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<ScheduleConfirmationScreen> createState() =>
      _ScheduleConfirmationScreenState();
}

class _ScheduleConfirmationScreenState
    extends ConsumerState<ScheduleConfirmationScreen> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Rebuild every 30s so countdownText stays fresh while the user
    // dwells on the confirmation screen.
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _copyCode(String code) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: code));
    WgToast.success(context, 'Đã sao chép mã $code');
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(scheduledTripDetailProvider(widget.tripId));

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: tripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(error: e.toString()),
        data: (trip) => trip == null
            ? const _ErrorState(error: 'Không tìm thấy chuyến đi')
            : _Body(trip: trip, onCopyCode: _copyCode),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.trip, required this.onCopyCode});
  final ScheduledTrip trip;
  final void Function(String code) onCopyCode;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SuccessHero(trip: trip),
                if (trip.poolId != null) ...[
                  const SizedBox(height: 16),
                  PoolTrackingCard(poolId: trip.poolId!),
                ],
                const SizedBox(height: 16),
                _TripCodeCard(trip: trip, onCopy: onCopyCode),
                const SizedBox(height: 12),
                _CountdownCard(trip: trip),
                const SizedBox(height: 12),
                _RouteCard(trip: trip),
                const SizedBox(height: 12),
                _DetailsCard(trip: trip),
                const SizedBox(height: 12),
                _FareCard(trip: trip),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 12,
            child: Row(
              children: [
                Expanded(
                  child: WgButton.secondary(
                    label: 'Chi tiết',
                    leadingIcon: PhosphorIconsRegular.listBullets,
                    onPressed: () => context.pushReplacement(
                      '/passenger/schedule-detail/${trip.id}',
                    ),
                    isFullWidth: true,
                    size: WgButtonSize.lg,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: WgButton.primary(
                    label: 'Về trang chủ',
                    trailingIcon: PhosphorIconsRegular.house,
                    onPressed: () => context.go('/passenger/home'),
                    isFullWidth: true,
                    size: WgButtonSize.lg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessHero extends StatelessWidget {
  const _SuccessHero({required this.trip});
  final ScheduledTrip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary500, AppColors.primary700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.heroCard,
        boxShadow: AppShadows.heroGlow(AppColors.primary500),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              PhosphorIconsFill.checkCircle,
              color: AppColors.white,
              size: 42,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Đặt chuyến thành công!',
            style: AppTypography.h2.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Hệ thống đang tìm tài xế phù hợp cho chuyến của bạn',
            style: AppTypography.caption.copyWith(
              color: AppColors.white.withValues(alpha: 0.92),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TripCodeCard extends StatelessWidget {
  const _TripCodeCard({required this.trip, required this.onCopy});
  final ScheduledTrip trip;
  final void Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              PhosphorIconsFill.ticket,
              color: AppColors.primary600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mã chuyến đi',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  trip.tripCode,
                  style: AppTypography.h3.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    letterSpacing: 1.5,
                    color: AppColors.ink900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.copy, size: 20),
            color: AppColors.primary500,
            onPressed: () => onCopy(trip.tripCode),
          ),
        ],
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.trip});
  final ScheduledTrip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.card,
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsFill.timer,
            color: Color(0xFFB45309),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Chuyến sẽ bắt đầu',
                  style: AppTypography.caption.copyWith(
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  trip.countdownText,
                  style: AppTypography.h3.copyWith(
                    color: const Color(0xFF78350F),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  trip.scheduledAtVN,
                  style: AppTypography.caption.copyWith(
                    color: const Color(0xFF92400E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.trip});
  final ScheduledTrip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(width: 2, height: 28, color: AppColors.ink200),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.pickup.name,
                  style: AppTypography.body.copyWith(
                    color: AppColors.ink900,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  trip.pickup.address,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 18),
                Text(
                  trip.dropoff.name,
                  style: AppTypography.body.copyWith(
                    color: AppColors.ink900,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  trip.dropoff.address,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.trip});
  final ScheduledTrip trip;

  String _luggage() => switch (trip.luggage) {
    LuggageType.none => 'Không có',
    LuggageType.small => 'Hành lý nhỏ',
    LuggageType.large => 'Hành lý lớn',
  };

  String _recurrence() => switch (trip.recurrence) {
    RecurrenceType.once => '1 lần',
    RecurrenceType.daily => 'Hàng ngày',
    RecurrenceType.weekly => 'Hàng tuần',
  };

  String _payment() => switch (trip.paymentMethod) {
    SchedulePaymentMethod.cash => 'Tiền mặt',
    SchedulePaymentMethod.vnpay => 'VNPay',
    SchedulePaymentMethod.momo => 'MoMo',
  };

  @override
  Widget build(BuildContext context) {
    final flex = trip.flexibleWindowMin == 0
        ? 'Đúng giờ'
        : '± ${trip.flexibleWindowMin} phút';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.xs,
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: PhosphorIconsFill.car,
            label: 'Loại xe',
            value: trip.rideType == 'shared'
                ? 'Xe ghép thông minh'
                : 'Xe riêng',
          ),
          _DetailRow(
            icon: PhosphorIconsFill.user,
            label: 'Hành khách',
            value: '${trip.passengerCount} người',
          ),
          _DetailRow(
            icon: PhosphorIconsFill.suitcase,
            label: 'Hành lý',
            value: _luggage(),
          ),
          _DetailRow(
            icon: PhosphorIconsFill.clockClockwise,
            label: 'Linh hoạt',
            value: flex,
          ),
          _DetailRow(
            icon: PhosphorIconsFill.repeat,
            label: 'Lặp lại',
            value: _recurrence(),
          ),
          _DetailRow(
            icon: PhosphorIconsFill.wallet,
            label: 'Thanh toán',
            value: _payment(),
          ),
          if (trip.note != null && trip.note!.isNotEmpty)
            _DetailRow(
              icon: PhosphorIconsFill.note,
              label: 'Ghi chú',
              value: trip.note!,
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.ink500),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: AppColors.ink500),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTypography.body.copyWith(
                color: AppColors.ink900,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FareCard extends StatelessWidget {
  const _FareCard({required this.trip});
  final ScheduledTrip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary50, AppColors.primary100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.primary200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Giá gốc',
                style: AppTypography.body.copyWith(color: AppColors.ink700),
              ),
              Text(
                formatVnd(trip.baseFare),
                style: AppTypography.body.copyWith(
                  color: AppColors.ink700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          if (trip.discount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  trip.promoCode != null
                      ? 'Giảm giá (${trip.promoCode})'
                      : 'Giảm giá',
                  style: AppTypography.body.copyWith(
                    color: AppColors.success,
                  ),
                ),
                Text(
                  '- ${formatVnd(trip.discount)}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.success,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 20, color: AppColors.primary200),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng cộng',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.ink900,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                formatVnd(trip.estimatedFare),
                style: AppTypography.h2.copyWith(
                  color: AppColors.primary600,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                PhosphorIconsRegular.warningCircle,
                color: AppColors.warning,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                error,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.ink700),
              ),
              const SizedBox(height: 16),
              WgButton.primary(
                label: 'Về trang chủ',
                onPressed: () => context.go('/passenger/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
