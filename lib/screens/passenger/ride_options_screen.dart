import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/geohash_util.dart';
import '../../core/utils/polyline_fallback.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_draggable_sheet.dart';
import '../../core/widgets/wg_glass.dart';
import '../../core/widgets/wg_recenter_fab.dart';
import '../../core/widgets/wg_toast.dart';
import '../../core/widgets/wg_trackasia_map.dart';
import '../../models/place.dart';
import '../../models/trip.dart';
import '../../providers/custom_pickup_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/selected_destination_provider.dart';
import '../../providers/selected_ride_type_provider.dart';
import '../../services/directions_service.dart';
import '_widgets/ride_type_card.dart';

// Pricing constants for Phase 1B mock fares.
const _kOpenFare = 8000; // VND base fare (cửa)
const _kPerKm = 12000; // VND per km
const _kPromoDiscount = 20000; // WEGO50 fixed discount
const double _kAvgSpeedKmh = 25; // for ETA fallback when API fails
const double _kShareDiscount = 0.62; // 38% off vs private
const double _kSevenSeatMultiplier = 1.45;

// Sheet snap positions. Initial = comfortable view that shows the route
// summary + the selected ride type. Min = peek so the user can drag down
// to see the full map. Max = expanded for scrolling payment + promo.
const _kSheetInitial = 0.55;
const _kSheetMin = 0.30;
const _kSheetMax = 0.85;
const _kSheetSnaps = <double>[_kSheetMin, _kSheetInitial, _kSheetMax];

int _roundToThousand(num v) => (v / 1000).round() * 1000;

class RideOptionsScreen extends ConsumerStatefulWidget {
  const RideOptionsScreen({super.key});

  @override
  ConsumerState<RideOptionsScreen> createState() => _RideOptionsScreenState();
}

class _RideOptionsScreenState extends ConsumerState<RideOptionsScreen> {
  /// Stand-in pickup address when the user hasn't picked a custom one.
  static const _defaultPickupAddress = 'Vị trí hiện tại';

  DirectionsRoute? _route;
  bool _loadingRoute = true;
  LatLng? _lastFetchKey;
  MapLibreMapController? _mapController;

  Future<void> _maybeFetchRoute(LatLng pickup, LatLng dropoff) async {
    // Avoid re-firing on every rebuild — key by destination since the
    // user's GPS pickup only nudges by a few meters between frames.
    final key = LatLng(
      ((dropoff.latitude + pickup.latitude) * 1e4).roundToDouble(),
      ((dropoff.longitude + pickup.longitude) * 1e4).roundToDouble(),
    );
    if (_lastFetchKey == key) return;
    _lastFetchKey = key;

    setState(() => _loadingRoute = true);

    final result = await DirectionsService.getRoute(
      origin: pickup,
      destination: dropoff,
    );

    if (!mounted) return;
    setState(() {
      _route = result;
      _loadingRoute = false;
    });
  }

  void _fitCameraToRoute(LatLng pickup, LatLng dropoff) {
    final ctrl = _mapController;
    if (ctrl == null) return;
    final points = _route?.points ?? [pickup, dropoff];
    if (points.length < 2) return;
    final bounds = _boundsOfPoints(points);
    final mq = MediaQuery.of(context);
    final bottomPad = (mq.size.height * _kSheetInitial).clamp(
      220.0,
      mq.size.height * 0.7,
    );
    ctrl.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        left: 60,
        right: 60,
        top: mq.padding.top + 80,
        bottom: bottomPad.toDouble(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dropoff = ref.watch(selectedDestinationProvider);
    if (dropoff == null) {
      return _MissingDropoff();
    }

    final selectedType = ref.watch(selectedRideTypeProvider);
    final customPickup = ref.watch(customPickupProvider);

    // Custom pickup (from "Đi đón khách") wins over GPS so the trip
    // starts at the friend's location, not the user's phone.
    final LatLng pickup;
    final String pickupAddress;
    if (customPickup != null) {
      pickup = LatLng(customPickup.lat, customPickup.lng);
      pickupAddress = customPickup.name;
    } else {
      final origin =
          ref.watch(currentLocationProvider).valueOrNull ?? kDanangFallback;
      pickup = LatLng(origin.latitude, origin.longitude);
      pickupAddress = _defaultPickupAddress;
    }
    final dest = LatLng(dropoff.lat, dropoff.lng);

    // Kick off the directions fetch once the first frame is laid out so
    // the loading spinner shows immediately instead of after a sync gap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeFetchRoute(pickup, dest);
    });

    // Prefer Directions API result, fall back to Haversine + speed mock
    // so the price/CTA still works offline.
    final distanceKm =
        _route?.distanceKm ??
        GeohashUtil.distanceKm(
          pickup.latitude,
          pickup.longitude,
          dest.latitude,
          dest.longitude,
        );
    final durationMin =
        _route?.durationMin ??
        (distanceKm / _kAvgSpeedKmh * 60).round().clamp(1, 240);

    final baseFare = _roundToThousand(distanceKm * _kPerKm + _kOpenFare);
    final sharedFare = _roundToThousand(baseFare * _kShareDiscount);
    final sevenSeatFare = _roundToThousand(baseFare * _kSevenSeatMultiplier);

    final selectedFare = switch (selectedType) {
      TripType.shared => sharedFare,
      TripType.private => baseFare,
    };
    final finalFare = (selectedFare - _kPromoDiscount).clamp(0, selectedFare);

    final mq = MediaQuery.of(context);
    // FAB sits just above the sheet's initial size so it never collides
    // with the grabber but stays in thumb reach.
    final fabBottom = mq.size.height * _kSheetInitial + 16;

    final ctaLabel = switch (selectedType) {
      TripType.shared => 'Đặt Xe ghép — ${formatVnd(finalFare)}',
      TripType.private => 'Đặt Xe riêng — ${formatVnd(finalFare)}',
    };

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.offWhite,
      body: Stack(
        children: [
          // Layer 1 — interactive full-screen map.
          _RideMap(
            pickup: pickup,
            dropoff: dest,
            routePoints: _route?.points,
            isLoading: _loadingRoute,
            onMapCreated: (c) => _mapController = c,
            onReady: () => _fitCameraToRoute(pickup, dest),
          ),

          // Layer 2 — floating glass top header.
          Positioned(
            top: mq.padding.top + 12,
            left: 16,
            right: 16,
            child: _TopHeader(
              loadingRoute: _loadingRoute,
              distanceKm: _route?.distanceKm,
            ),
          ),

          // Layer 3 — recenter FAB above the sheet.
          Positioned(
            right: 16,
            bottom: fabBottom,
            child: WgRecenterFab(onTap: () => _fitCameraToRoute(pickup, dest)),
          ),

          // Layer 4 — draggable sheet with route + ride cards.
          WgDraggableSheet(
            initialSize: _kSheetInitial,
            minSize: _kSheetMin,
            maxSize: _kSheetMax,
            snapSizes: _kSheetSnaps,
            builder: (sc) => _SheetContent(
              scrollController: sc,
              pickupAddress: pickupAddress,
              dropoffAddress: dropoff.name,
              distanceKm: distanceKm,
              durationMin: durationMin,
              selectedType: selectedType,
              baseFare: baseFare,
              sharedFare: sharedFare,
              sevenSeatFare: sevenSeatFare,
              onSelectShared: () => ref
                  .read(selectedRideTypeProvider.notifier)
                  .set(TripType.shared),
              onSelectPrivate: () => ref
                  .read(selectedRideTypeProvider.notifier)
                  .set(TripType.private),
              onSevenSeatToast: () =>
                  WgToast.info(context, 'Xe 7 chỗ sẽ mở ở phiên bản sau'),
              onPaymentToast: () =>
                  WgToast.info(context, 'Đổi PTTT có ở màn Trip Summary'),
              onPromoToast: () =>
                  WgToast.info(context, 'Mã đã áp dụng tự động'),
            ),
          ),

          // Layer 5 — sticky bottom CTA.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StickyCta(
              label: ctaLabel,
              onPressed: () => _book(
                pickup: dropoff,
                dropoff: dropoff,
                type: selectedType,
                price: finalFare,
                distanceKm: distanceKm,
                durationMin: durationMin,
                pickupLatLng: pickup,
                pickupAddress: pickupAddress,
              ),
            ),
          ),
        ],
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
    required String pickupAddress,
  }) {
    final extra = <String, Object>{
      'pickupLat': pickupLatLng.latitude,
      'pickupLng': pickupLatLng.longitude,
      'pickupAddress': pickupAddress,
      'dropoffId': dropoff.id,
      'type': type.name,
      'price': price,
      'distanceKm': distanceKm,
      'durationMin': durationMin,
    };
    // One-shot per trip: clear so the next trip defaults back to GPS.
    ref.read(customPickupProvider.notifier).clear();
    context.push('/passenger/matching', extra: extra);
  }
}

LatLngBounds _boundsOfPoints(List<LatLng> points) {
  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;
  for (final p in points) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }
  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}

/// Stateful MapLibre wrapper that owns the route polyline + pickup /
/// dropoff circle markers. Re-syncs annotations whenever the parent
/// hands down new coords or a new Directions result.
class _RideMap extends StatefulWidget {
  const _RideMap({
    required this.pickup,
    required this.dropoff,
    required this.routePoints,
    required this.isLoading,
    required this.onMapCreated,
    required this.onReady,
  });

  final LatLng pickup;
  final LatLng dropoff;
  final List<LatLng>? routePoints;
  final bool isLoading;
  final ValueChanged<MapLibreMapController> onMapCreated;
  final VoidCallback onReady;

  @override
  State<_RideMap> createState() => _RideMapState();
}

class _RideMapState extends State<_RideMap> {
  MapLibreMapController? _ctrl;
  Line? _routeLine;
  bool _styleReady = false;

  @override
  void didUpdateWidget(_RideMap old) {
    super.didUpdateWidget(old);
    if (!_styleReady) return;
    final endpointsChanged =
        old.pickup != widget.pickup || old.dropoff != widget.dropoff;
    final pointsChanged = !_listEqual(
      old.routePoints ?? const [],
      widget.routePoints ?? const [],
    );
    if (endpointsChanged || pointsChanged) {
      _syncAnnotations();
    }
  }

  bool _listEqual(List<LatLng> a, List<LatLng> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _onStyleLoaded() async {
    _styleReady = true;
    await _syncAnnotations();
    widget.onReady();
  }

  Future<void> _syncAnnotations() async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    await ctrl.clearLines();
    await ctrl.clearCircles();

    final poly =
        widget.routePoints ??
        (widget.isLoading
            ? <LatLng>[widget.pickup, widget.dropoff]
            : PolylineFallback.interpolate(
                origin: widget.pickup,
                destination: widget.dropoff,
              ));
    _routeLine = await ctrl.addLine(
      LineOptions(
        geometry: poly,
        lineColor: '#0FB67E',
        lineWidth: 5,
        lineJoin: 'round',
      ),
    );
    await ctrl.addCircle(
      CircleOptions(
        geometry: widget.pickup,
        circleRadius: 8,
        circleColor: '#10B981',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2.5,
      ),
    );
    await ctrl.addCircle(
      CircleOptions(
        geometry: widget.dropoff,
        circleRadius: 8,
        circleColor: '#EF4444',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2.5,
      ),
    );
    if (!mounted) return;
    setState(() {}); // ignore: invalid_use_of_protected_member
    // _routeLine is held for future updateLine() callers; suppress unused
    // warning if needed.
    if (_routeLine == null) return;
  }

  @override
  Widget build(BuildContext context) {
    final centerLat = (widget.pickup.latitude + widget.dropoff.latitude) / 2;
    final centerLng = (widget.pickup.longitude + widget.dropoff.longitude) / 2;
    return WgTrackAsiaMap(
      initialCenter: LatLng(centerLat, centerLng),
      initialZoom: 13,
      onMapCreated: (c) {
        _ctrl = c;
        widget.onMapCreated(c);
      },
      onStyleLoadedCallback: _onStyleLoaded,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.loadingRoute, required this.distanceKm});

  final bool loadingRoute;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    return WgGlass(
      blur: 24,
      opacity: 0.92,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft, size: 22),
            onPressed: () => context.pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Chọn chuyến xe',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink900,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (loadingRoute)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primary500,
                  ),
                ),
              ),
            )
          else if (distanceKm != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary100,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${distanceKm!.toStringAsFixed(1)} km',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetContent extends StatelessWidget {
  const _SheetContent({
    required this.scrollController,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.distanceKm,
    required this.durationMin,
    required this.selectedType,
    required this.baseFare,
    required this.sharedFare,
    required this.sevenSeatFare,
    required this.onSelectShared,
    required this.onSelectPrivate,
    required this.onSevenSeatToast,
    required this.onPaymentToast,
    required this.onPromoToast,
  });

  final ScrollController scrollController;
  final String pickupAddress;
  final String dropoffAddress;
  final double distanceKm;
  final int durationMin;
  final TripType selectedType;
  final int baseFare;
  final int sharedFare;
  final int sevenSeatFare;
  final VoidCallback onSelectShared;
  final VoidCallback onSelectPrivate;
  final VoidCallback onSevenSeatToast;
  final VoidCallback onPaymentToast;
  final VoidCallback onPromoToast;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: [
        _RouteSummary(
          pickup: pickupAddress,
          dropoff: dropoffAddress,
          distanceKm: distanceKm,
          durationMin: durationMin,
        ),
        const SizedBox(height: 16),
        Text(
          'Loại xe',
          style: AppTypography.h3.copyWith(color: AppColors.ink900),
        ),
        const SizedBox(height: 12),
        RideTypeCard(
          icon: PhosphorIconsFill.usersThree,
          title: 'Xe ghép thông minh',
          etaLabel: 'Đón sau 4-6 phút · Chia sẻ tuyến',
          price: sharedFare,
          strikethroughPrice: baseFare,
          savingBadge: 'Tiết kiệm 38%',
          selected: selectedType == TripType.shared,
          onTap: onSelectShared,
        ),
        const SizedBox(height: 12),
        RideTypeCard(
          icon: PhosphorIconsFill.car,
          title: 'Xe 4 chỗ riêng',
          etaLabel: 'Đón sau 2-3 phút',
          price: baseFare,
          selected: selectedType == TripType.private,
          onTap: onSelectPrivate,
        ),
        const SizedBox(height: 12),
        RideTypeCard(
          icon: PhosphorIconsFill.van,
          title: 'Xe 7 chỗ',
          etaLabel: 'Đón sau 3-5 phút · Nhiều hành lý',
          price: sevenSeatFare,
          selected: false,
          onTap: onSevenSeatToast,
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
          onTap: onPaymentToast,
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
          onTap: onPromoToast,
        ),
      ],
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({
    required this.pickup,
    required this.dropoff,
    required this.distanceKm,
    required this.durationMin,
  });

  final String pickup;
  final String dropoff;
  final double distanceKm;
  final int durationMin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.ink50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    Container(width: 2, height: 22, color: AppColors.ink200),
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
                      pickup,
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink900,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      dropoff,
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink900,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                PhosphorIconsRegular.path,
                size: 14,
                color: AppColors.ink500,
              ),
              const SizedBox(width: 4),
              Text(
                '${distanceKm.toStringAsFixed(1)} km',
                style: AppTypography.caption.copyWith(color: AppColors.ink600),
              ),
              const SizedBox(width: 12),
              const Icon(
                PhosphorIconsRegular.clock,
                size: 14,
                color: AppColors.ink500,
              ),
              const SizedBox(width: 4),
              Text(
                '$durationMin phút',
                style: AppTypography.caption.copyWith(color: AppColors.ink600),
              ),
            ],
          ),
        ],
      ),
    );
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
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 14),
      decoration: const BoxDecoration(
        color: AppColors.white,
        boxShadow: AppShadows.lg,
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary500, size: 20),
            const SizedBox(width: 12),
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
