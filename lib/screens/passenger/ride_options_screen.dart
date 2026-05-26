import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/geohash_util.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_toast.dart';
import '../../models/place.dart';
import '../../models/trip.dart';
import '../../providers/location_provider.dart';
import '../../providers/selected_destination_provider.dart';
import '../../providers/selected_ride_type_provider.dart';
import '_widgets/ride_type_card.dart';
import '_widgets/route_preview_map.dart';
import '_widgets/route_summary_card.dart';

// Pricing constants for Phase 1B mock fares.
const _kOpenFare = 8000; // VND base fare (cửa)
const _kPerKm = 12000; // VND per km
const _kPromoDiscount = 20000; // WEGO50 fixed discount
const double _kAvgSpeedKmh = 25; // for ETA estimation
const double _kShareDiscount = 0.62; // 38% off vs private
const double _kSevenSeatMultiplier = 1.45;

int _roundToThousand(num v) => (v / 1000).round() * 1000;

class RideOptionsScreen extends ConsumerStatefulWidget {
  const RideOptionsScreen({super.key});

  @override
  ConsumerState<RideOptionsScreen> createState() => _RideOptionsScreenState();
}

class _RideOptionsScreenState extends ConsumerState<RideOptionsScreen> {
  /// Stand-in pickup address until reverse-geocoding lands.
  static const _pickupAddress = 'Vị trí hiện tại';

  @override
  Widget build(BuildContext context) {
    final dropoff = ref.watch(selectedDestinationProvider);
    if (dropoff == null) {
      return _MissingDropoff();
    }

    final origin =
        ref.watch(currentLocationProvider).valueOrNull ?? kDanangFallback;
    final selectedType = ref.watch(selectedRideTypeProvider);

    final pickup = LatLng(origin.latitude, origin.longitude);
    final dest = LatLng(dropoff.lat, dropoff.lng);

    final distanceKm = GeohashUtil.distanceKm(
      pickup.latitude,
      pickup.longitude,
      dest.latitude,
      dest.longitude,
    );
    final durationMin = (distanceKm / _kAvgSpeedKmh * 60).round().clamp(1, 240);
    final baseFare = _roundToThousand(distanceKm * _kPerKm + _kOpenFare);
    final sharedFare = _roundToThousand(baseFare * _kShareDiscount);
    final sevenSeatFare = _roundToThousand(baseFare * _kSevenSeatMultiplier);

    final selectedFare = switch (selectedType) {
      TripType.shared => sharedFare,
      TripType.private => baseFare,
    };
    final finalFare = (selectedFare - _kPromoDiscount).clamp(0, selectedFare);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Chọn chuyến xe'),
      ),
      bottomNavigationBar: _StickyCta(
        label: switch (selectedType) {
          TripType.shared => 'Đặt Xe ghép — ${formatVnd(finalFare)}',
          TripType.private => 'Đặt Xe riêng — ${formatVnd(finalFare)}',
        },
        onPressed: () => _book(
          pickup: dropoff, // placeholder until reverse-geocoded pickup
          dropoff: dropoff,
          type: selectedType,
          price: finalFare,
          distanceKm: distanceKm,
          durationMin: durationMin,
          pickupLatLng: pickup,
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            RoutePreviewMap(pickup: pickup, dropoff: dest, height: 200),
            ColoredBox(
              color: AppColors.white,
              child: RouteSummaryCard(
                pickupAddress: _pickupAddress,
                dropoffAddress: dropoff.name,
                distanceKm: distanceKm,
                durationMin: durationMin,
              ),
            ),
            const SizedBox(height: 12),
            _StaggerFadeIn(
              delay: const Duration(milliseconds: 80),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: RideTypeCard(
                  icon: PhosphorIconsFill.usersThree,
                  title: 'Xe ghép thông minh',
                  etaLabel: 'Đón sau 4-6 phút · Chia sẻ tuyến',
                  price: sharedFare,
                  strikethroughPrice: baseFare,
                  savingBadge: 'Tiết kiệm 38%',
                  selected: selectedType == TripType.shared,
                  onTap: () => ref
                      .read(selectedRideTypeProvider.notifier)
                      .set(TripType.shared),
                ),
              ),
            ),
            _StaggerFadeIn(
              delay: const Duration(milliseconds: 160),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: RideTypeCard(
                  icon: PhosphorIconsFill.car,
                  title: 'Xe 4 chỗ riêng',
                  etaLabel: 'Đón sau 2-3 phút',
                  price: baseFare,
                  selected: selectedType == TripType.private,
                  onTap: () => ref
                      .read(selectedRideTypeProvider.notifier)
                      .set(TripType.private),
                ),
              ),
            ),
            _StaggerFadeIn(
              delay: const Duration(milliseconds: 240),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: RideTypeCard(
                  icon: PhosphorIconsFill.van,
                  title: 'Xe 7 chỗ',
                  etaLabel: 'Đón sau 3-5 phút · Nhiều hành lý',
                  price: sevenSeatFare,
                  selected: false, // Phase 1B: not selectable
                  onTap: () =>
                      WgToast.info(context, 'Xe 7 chỗ sẽ mở ở phiên bản sau'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _BottomRow(
              icon: PhosphorIconsRegular.money,
              label: 'Tiền mặt',
              trailing: const Icon(
                PhosphorIconsRegular.caretRight,
                color: AppColors.ink300,
                size: 18,
              ),
              onTap: () =>
                  WgToast.info(context, 'Đổi PTTT có ở màn Trip Summary'),
            ),
            _BottomRow(
              icon: PhosphorIconsRegular.tag,
              label: 'WEGO50 −${formatVnd(_kPromoDiscount)}',
              labelColor: AppColors.primary500,
              trailing: const Icon(
                PhosphorIconsRegular.caretRight,
                color: AppColors.ink300,
                size: 18,
              ),
              onTap: () => WgToast.info(context, 'Mã đã áp dụng tự động'),
            ),
            const SizedBox(height: 80), // breathing room above sticky CTA
          ],
        ),
      ),
    );
  }

  void _book({
    required Place pickup,
    required Place dropoff,
    required TripType type,
    required int price,
    required double distanceKm,
    required int durationMin,
    required LatLng pickupLatLng,
  }) {
    final extra = <String, Object>{
      'pickupLat': pickupLatLng.latitude,
      'pickupLng': pickupLatLng.longitude,
      'pickupAddress': _pickupAddress,
      'dropoffId': dropoff.id,
      'type': type.name,
      'price': price,
      'distanceKm': distanceKm,
      'durationMin': durationMin,
    };
    context.push('/passenger/matching', extra: extra);
  }
}

class _StickyCta extends StatelessWidget {
  const _StickyCta({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.ink100, width: 0.5)),
      ),
      child: WgButton.primary(
        label: label,
        size: WgButtonSize.lg,
        isFullWidth: true,
        trailingIcon: PhosphorIconsRegular.arrowRight,
        onPressed: onPressed,
      ),
    );
  }
}

class _BottomRow extends StatelessWidget {
  const _BottomRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary500, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTypography.body.copyWith(
                  color: labelColor ?? AppColors.ink900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _MissingDropoff extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn chuyến xe')),
      body: Center(
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
                'Chưa có điểm đến.\nQuay lại trang chủ để chọn nhé.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.ink700),
              ),
              const SizedBox(height: 24),
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

class _StaggerFadeIn extends StatefulWidget {
  const _StaggerFadeIn({required this.delay, required this.child});
  final Duration delay;
  final Widget child;
  @override
  State<_StaggerFadeIn> createState() => _StaggerFadeInState();
}

class _StaggerFadeInState extends State<_StaggerFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic)),
        child: widget.child,
      ),
    );
  }
}
