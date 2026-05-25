import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_chip.dart';
import '../../core/widgets/wg_payment_chip.dart';
import '../../core/widgets/wg_rating_stars.dart';
import '../../core/widgets/wg_toast.dart';
import '../../models/trip.dart';
import '../../providers/auth_provider.dart';
import '../../providers/current_trip_provider.dart';
import '../../providers/payment_method_provider.dart';
import '../../providers/recent_destinations_provider.dart';
import '../../providers/selected_destination_provider.dart';
import '../../providers/selected_ride_type_provider.dart';
import '../../providers/trip_rating_provider.dart';
import '../../providers/trip_service_provider.dart';
import '_widgets/fare_breakdown.dart';
import '_widgets/route_preview_map.dart';

const _kBaseFare = 8000;
const _kPerKm = 12000;
const _kPromoDiscount = 20000;
const double _kShareDiscount = 0.62;

const _kRatingTags = [
  'Lái an toàn',
  'Xe sạch',
  'Đúng giờ',
  'Thân thiện',
  'Lịch sự',
  'Đường tốt',
];

int _roundToThousand(num v) => (v / 1000).round() * 1000;

class TripSummaryScreen extends ConsumerStatefulWidget {
  const TripSummaryScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends ConsumerState<TripSummaryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _checkAnim;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _checkAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAnim.forward());
  }

  @override
  void dispose() {
    _checkAnim.dispose();
    super.dispose();
  }

  Future<void> _complete(ActiveTrip trip) async {
    final rating = ref.read(tripRatingProvider);
    if (rating.stars == 0) {
      WgToast.error(context, 'Vui lòng đánh giá tài xế');
      return;
    }
    setState(() => _submitting = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('Mất phiên đăng nhập');
      final pm = ref.read(selectedPaymentMethodProvider);
      await ref
          .read(tripServiceProvider)
          .completeTrip(
            tripId: trip.tripId,
            passengerId: user.id,
            driverId: trip.driver.id,
            paymentMethod: pm.name,
            stars: rating.stars,
            tags: rating.tags,
          );
      if (!mounted) return;
      WgToast.success(context, 'Cảm ơn bạn đã đánh giá!');
      // Reset all per-trip state.
      ref.read(currentTripProvider.notifier).clear();
      ref.read(selectedDestinationProvider.notifier).clear();
      ref.read(tripRatingProvider.notifier).reset();
      ref.read(selectedRideTypeProvider.notifier).set(TripType.shared);
      // Refresh recents in case driver tapped completed elsewhere.
      // ignore: unused_result
      ref.refresh(recentDestinationsProvider);
      context.go('/passenger/home');
    } catch (e) {
      if (!mounted) return;
      WgToast.error(context, 'Lỗi: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(currentTripProvider);
    if (trip == null) return _missing(context);

    final distanceKm = trip.trip.distanceKm;
    final durationMin = trip.trip.durationMin;
    final type = trip.trip.type;
    final typeLabel = type == TripType.shared ? 'Xe ghép' : 'Xe riêng';

    final baseFare = _roundToThousand(distanceKm * _kPerKm + _kBaseFare);
    final isShared = type == TripType.shared;
    final shareSaving = isShared
        ? _roundToThousand(baseFare * (1 - _kShareDiscount))
        : 0;
    final subtotal = baseFare - shareSaving;
    final finalFare = (subtotal - _kPromoDiscount).clamp(0, subtotal);

    final pickup = LatLng(trip.trip.pickupLat, trip.trip.pickupLng);
    final dropoff = LatLng(trip.trip.dropoffLat, trip.trip.dropoffLng);

    final rating = ref.watch(tripRatingProvider);
    final pm = ref.watch(selectedPaymentMethodProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      bottomNavigationBar: _StickyCta(
        loading: _submitting,
        onPressed: () => _complete(trip),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _Header(checkAnim: _checkAnim),
            const SizedBox(height: 8),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RoutePreviewMap(
                    pickup: pickup,
                    dropoff: dropoff,
                    height: 100,
                    borderRadius: BorderRadius.circular(12),
                    showAttribution: false,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${distanceKm.toStringAsFixed(1)} km · $durationMin phút · $typeLabel',
                    style: AppTypography.body.copyWith(
                      color: AppColors.ink700,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FareBreakdown(
                    rows: [
                      FareBreakdownRow(label: 'Giá gốc', amount: baseFare),
                      if (isShared)
                        FareBreakdownRow(
                          label: 'Giảm xe ghép',
                          amount: shareSaving,
                          negative: true,
                          color: AppColors.sharedAccent,
                        ),
                      FareBreakdownRow(
                        label: 'Khuyến mãi WEGO50',
                        amount: _kPromoDiscount,
                        negative: true,
                        color: AppColors.success,
                      ),
                    ],
                    total: finalFare,
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Phương thức thanh toán',
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    WgPaymentChip(
                      label: PaymentMethod.cash.label,
                      icon: Icons.payments_outlined,
                      selected: pm == PaymentMethod.cash,
                      onTap: () => ref
                          .read(selectedPaymentMethodProvider.notifier)
                          .set(PaymentMethod.cash),
                    ),
                    const SizedBox(width: 10),
                    WgPaymentChip(
                      label: PaymentMethod.card.label,
                      icon: Icons.credit_card_outlined,
                      selected: pm == PaymentMethod.card,
                      onTap: () => ref
                          .read(selectedPaymentMethodProvider.notifier)
                          .set(PaymentMethod.card),
                    ),
                    const SizedBox(width: 10),
                    WgPaymentChip(
                      label: PaymentMethod.momo.label,
                      brandLetter: 'M',
                      brandColor: const Color(0xFFA50064),
                      selected: pm == PaymentMethod.momo,
                      onTap: () => ref
                          .read(selectedPaymentMethodProvider.notifier)
                          .set(PaymentMethod.momo),
                    ),
                    const SizedBox(width: 10),
                    WgPaymentChip(
                      label: PaymentMethod.zalopay.label,
                      brandLetter: 'Z',
                      brandColor: const Color(0xFF0068FF),
                      selected: pm == PaymentMethod.zalopay,
                      onTap: () => ref
                          .read(selectedPaymentMethodProvider.notifier)
                          .set(PaymentMethod.zalopay),
                    ),
                  ],
                ),
              ),
            ),
            _Section(
              title: 'Đánh giá ${trip.driver.name}',
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  WgRatingStars(
                    value: rating.stars,
                    onChanged: (n) =>
                        ref.read(tripRatingProvider.notifier).setStars(n),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: rating.stars > 0
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: _kRatingTags.map((t) {
                                return WgChip(
                                  label: t,
                                  selected: rating.tags.contains(t),
                                  onTap: () => ref
                                      .read(tripRatingProvider.notifier)
                                      .toggleTag(t),
                                );
                              }).toList(),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _missing(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chuyến đi')),
      body: Center(
        child: TextButton(
          onPressed: () => context.go('/passenger/home'),
          child: const Text('Không có dữ liệu chuyến — về trang chủ'),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.checkAnim});
  final AnimationController checkAnim;

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: checkAnim, curve: Curves.elasticOut));
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          ScaleTransition(
            scale: scale,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.success,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Bạn đã đến nơi! 🎉',
            style: AppTypography.display.copyWith(fontSize: 28),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Chuyến đi đã hoàn thành',
            style: AppTypography.body.copyWith(color: AppColors.ink500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text(
              title,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.ink900,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _StickyCta extends StatelessWidget {
  const _StickyCta({required this.loading, required this.onPressed});
  final bool loading;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, inset + 16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.ink100, width: 0.5)),
      ),
      child: WgButton.primary(
        label: loading ? 'Đang lưu...' : 'Hoàn tất thanh toán',
        size: WgButtonSize.lg,
        isFullWidth: true,
        isLoading: loading,
        trailingIcon: Icons.arrow_forward_rounded,
        onPressed: loading ? null : onPressed,
      ),
    );
  }
}
