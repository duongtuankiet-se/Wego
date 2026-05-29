import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/wg_badge.dart';
import '../../../core/widgets/wg_button.dart';
import '../../../core/widgets/wg_countdown_ring.dart';
import '../../../core/widgets/wg_toast.dart';
import '../../../models/scheduled_trip.dart';
import '../../../providers/driver_provider.dart';
import '../../../providers/scheduled_trips_provider.dart';
import '../../../providers/trip_offer_provider.dart';

/// Phase 5R driver offer popup. Shows the freshly-offered scheduled
/// trip with a live countdown; auto-rejects if the window elapses.
class TripOfferPopup extends ConsumerStatefulWidget {
  const TripOfferPopup({
    super.key,
    required this.trip,
    required this.initialSecondsLeft,
  });

  final ScheduledTrip trip;
  final int initialSecondsLeft;

  /// Pop the modal. Resolves to `true` if the driver accepted, `false`
  /// on reject / timeout / race lost.
  static Future<bool> show(
    BuildContext context, {
    required ScheduledTrip trip,
    required int initialSecondsLeft,
  }) async {
    HapticFeedback.mediumImpact();
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'trip-offer',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => TripOfferPopup(
        trip: trip,
        initialSecondsLeft: initialSecondsLeft,
      ),
      transitionBuilder: (_, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
    return result ?? false;
  }

  @override
  ConsumerState<TripOfferPopup> createState() => _TripOfferPopupState();
}

class _TripOfferPopupState extends ConsumerState<TripOfferPopup> {
  late int _secondsLeft;
  Timer? _timer;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    // Clamp because the polled `secondsLeft` could be smaller than
    // offerWindow if the popup opened a few seconds after the offer
    // was issued (e.g. polling jitter).
    _secondsLeft = widget.initialSecondsLeft.clamp(
      1,
      kOfferWindowSeconds,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _handleTimeout();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleTimeout() async {
    if (_processing || !mounted) return;
    setState(() => _processing = true);
    final driver = await ref.read(currentDriverProvider.future);
    if (driver == null) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    await ref.read(tripOfferServiceProvider).rejectOffer(
          tripId: widget.trip.id,
          driverId: driver.id,
          isTimeout: true,
        );
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _accept() async {
    if (_processing) return;
    setState(() => _processing = true);
    _timer?.cancel();

    final driver = await ref.read(currentDriverProvider.future);
    if (driver == null) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    final result = await ref.read(tripOfferServiceProvider).acceptOffer(
          tripId: widget.trip.id,
          driverId: driver.id,
        );
    if (!mounted) return;
    if (result.success) {
      ref.invalidate(driverUpcomingTripsProvider);
      WgToast.success(context, 'Đã nhận chuyến ${widget.trip.tripCode}');
      Navigator.of(context).pop(true);
    } else {
      // Phase 5R hotfix: show the specific reason the service handed
      // back instead of the previous generic "không còn khả dụng".
      WgToast.error(
        context,
        result.reason ?? 'Chuyến đã không còn khả dụng',
      );
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _reject() async {
    if (_processing) return;
    setState(() => _processing = true);
    _timer?.cancel();

    final driver = await ref.read(currentDriverProvider.future);
    if (driver == null) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    await ref.read(tripOfferServiceProvider).rejectOffer(
          tripId: widget.trip.id,
          driverId: driver.id,
        );
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    // Drivers see their take-home (fare minus the 15% commission). The
    // payout column on the wallet ledger uses the same formula so the
    // popup matches what they'll actually receive.
    final driverTakeHome = (trip.estimatedFare * 0.85).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Material(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(28),
            elevation: 24,
            shadowColor: AppColors.ink900.withValues(alpha: 0.3),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(
                  trip: trip,
                  secondsLeft: _secondsLeft,
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          WgBadge(
                            label: trip.mode == ScheduleMode.fixedRoute
                                ? 'XE GHÉP TUYẾN'
                                : 'TỰ CHỌN ĐIỂM',
                            variant: trip.mode == ScheduleMode.fixedRoute
                                ? WgBadgeVariant.shared
                                : WgBadgeVariant.info,
                          ),
                          const Spacer(),
                          Text(
                            trip.scheduledAtVN,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.ink600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _RouteBlock(trip: trip),
                      const SizedBox(height: 16),
                      _PayoutCard(
                        driverTakeHome: driverTakeHome,
                        paymentMethod: trip.paymentMethod,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: WgButton.ghost(
                              label: 'Bỏ qua',
                              onPressed: _processing ? null : _reject,
                              size: WgButtonSize.lg,
                              isFullWidth: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: WgButton.primary(
                              label: 'Nhận chuyến',
                              onPressed: _processing ? null : _accept,
                              isLoading: _processing,
                              size: WgButtonSize.lg,
                              isFullWidth: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hardcoded mirror of [TripOfferService.offerWindow] inSeconds —
/// avoids importing the service just for a const, and any drift gets
/// caught by the popup clamp showing a slightly low number rather
/// than a crash.
const int kOfferWindowSeconds = 15;

class _Header extends StatelessWidget {
  const _Header({required this.trip, required this.secondsLeft});
  final ScheduledTrip trip;
  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary500, AppColors.primary700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsFill.car,
            color: AppColors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Có chuyến mới!',
                  style: AppTypography.h2.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  trip.tripCode,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: WgCountdownRing(
              secondsLeft: secondsLeft,
              totalSeconds: kOfferWindowSeconds,
              size: 44,
              color: AppColors.primary600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteBlock extends StatelessWidget {
  const _RouteBlock({required this.trip});
  final ScheduledTrip trip;

  @override
  Widget build(BuildContext context) {
    return Row(
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
              Container(width: 1.5, height: 30, color: AppColors.ink300),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Đón',
                style: AppTypography.micro.copyWith(color: AppColors.ink500),
              ),
              Text(
                trip.pickup.name,
                style: AppTypography.body.copyWith(
                  color: AppColors.ink900,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                'Đến',
                style: AppTypography.micro.copyWith(color: AppColors.ink500),
              ),
              Text(
                trip.dropoff.name,
                style: AppTypography.body.copyWith(
                  color: AppColors.ink900,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${trip.estimatedDistanceKm.toStringAsFixed(1)} km · '
                '${trip.estimatedDurationMin} phút',
                style: AppTypography.caption.copyWith(color: AppColors.ink500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({
    required this.driverTakeHome,
    required this.paymentMethod,
  });
  final int driverTakeHome;
  final SchedulePaymentMethod paymentMethod;

  @override
  Widget build(BuildContext context) {
    final isCash = paymentMethod == SchedulePaymentMethod.cash;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bạn nhận',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                  ),
                ),
                Text(
                  formatVnd(driverTakeHome),
                  style: AppTypography.h2.copyWith(
                    color: AppColors.primary600,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'sau khi trừ 15% hoa hồng',
                  style: AppTypography.micro.copyWith(
                    color: AppColors.ink500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isCash
                  ? AppColors.warning.withValues(alpha: 0.15)
                  : AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCash
                      ? PhosphorIconsFill.money
                      : PhosphorIconsFill.wallet,
                  size: 14,
                  color: isCash ? AppColors.warning : AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  isCash ? 'Tiền mặt' : _paymentLabel(paymentMethod),
                  style: AppTypography.micro.copyWith(
                    color: isCash ? AppColors.warning : AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _paymentLabel(SchedulePaymentMethod m) => switch (m) {
    SchedulePaymentMethod.cash => 'Tiền mặt',
    SchedulePaymentMethod.vnpay => 'VNPay',
    SchedulePaymentMethod.momo => 'MoMo',
  };
}
