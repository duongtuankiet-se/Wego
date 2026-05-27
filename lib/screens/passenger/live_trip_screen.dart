import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/wg_chip.dart';
import '../../core/widgets/wg_toast.dart';
import '../../core/widgets/wg_trackasia_map.dart';
import '../../models/trip.dart';
import '../../providers/current_trip_provider.dart';
import '../../providers/mongo_provider.dart';
import '../../providers/trip_service_provider.dart';
import '../../services/directions_service.dart';
import '_widgets/driver_info_card.dart';
import '_widgets/route_summary_card.dart';
import '_widgets/trip_status_pill.dart';

class LiveTripScreen extends ConsumerStatefulWidget {
  const LiveTripScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<LiveTripScreen> createState() => _LiveTripScreenState();
}

enum _LivePhase {
  driverArriving, // 0..8s: driver moving toward pickup
  driverArrived, //  8..12s: at pickup
  inTransit, //      12..20s: heading to dropoff
}

class _LiveTripScreenState extends ConsumerState<LiveTripScreen>
    with TickerProviderStateMixin {
  MapLibreMapController? _map;
  late final AnimationController _carAnim;
  Timer? _phaseTimer;
  _LivePhase _phase = _LivePhase.driverArriving;
  bool _navigated = false;

  // Animated car position. Computed from _carAnim.value along the active leg.
  LatLng? _carPos;
  late LatLng _legStart;
  late LatLng _legEnd;

  /// Real-route polyline from Google Directions (pickup → dropoff).
  /// Null until the API call returns; UI falls back to a straight line.
  List<LatLng>? _routePoints;

  /// Driver → pickup route polyline (for the "approaching" phase).
  /// Fetched lazily so we can animate the car along real roads too.
  List<LatLng>? _approachPoints;

  /// Realtime ETA refresh: every 5s we read the driver's latest
  /// `current_lat`/`current_lng` from Mongo (which the driver-nav
  /// screen pushes /3s) and re-ask Directions for the time-to-arrive
  /// at the active phase target. `null` means we haven't gotten a
  /// reading yet — show a spinner.
  Timer? _etaRefreshTimer;
  int? _realtimeEtaMinutes;

  @override
  void initState() {
    super.initState();
    final trip = ref.read(currentTripProvider);
    if (trip == null) return;
    _legStart = LatLng(trip.driver.currentLat, trip.driver.currentLng);
    _legEnd = LatLng(trip.trip.pickupLat, trip.trip.pickupLng);
    _carPos = _legStart;

    _carAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..addListener(_updateCar);
    _carAnim.forward();

    _phaseTimer = Timer(const Duration(seconds: 8), _phaseArrived);
    _fetchRoute(); // pre-compute pickup→dropoff polyline in background
    _startEtaRefresh();
  }

  void _startEtaRefresh() {
    _etaRefreshTimer?.cancel();
    // Kick the first refresh immediately so the spinner doesn't sit on
    // screen for 5s after entering the page.
    _refreshEta();
    _etaRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshEta();
    });
  }

  /// Read latest driver coords from Mongo + ask Directions for the
  /// remaining time to the active phase target. Skipped during the
  /// `driverArrived` interlude — no ETA to show then.
  Future<void> _refreshEta() async {
    if (!mounted) return;
    if (_phase == _LivePhase.driverArrived) return;
    final trip = ref.read(currentTripProvider);
    if (trip == null) return;

    try {
      final drivers = await ref.read(mongoServiceProvider).drivers();
      final driverDoc = await drivers.findOne(
        where.eq('_id', ObjectId.fromHexString(trip.driver.id)),
      );
      if (!mounted) return;
      if (driverDoc == null) return;
      final lat = (driverDoc['current_lat'] as num?)?.toDouble();
      final lng = (driverDoc['current_lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return;

      final target = _phase == _LivePhase.driverArriving
          ? LatLng(trip.trip.pickupLat, trip.trip.pickupLng)
          : LatLng(trip.trip.dropoffLat, trip.trip.dropoffLng);

      final route = await DirectionsService.getRoute(
        origin: LatLng(lat, lng),
        destination: target,
      );
      if (!mounted || route == null) return;
      setState(() => _realtimeEtaMinutes = route.durationMin);
    } catch (_) {
      // Network blip — keep showing the previous ETA.
    }
  }

  void _fitBounds(LatLng pickup, LatLng dropoff, LatLng car) {
    final lats = [pickup.latitude, dropoff.latitude, car.latitude];
    final lngs = [pickup.longitude, dropoff.longitude, car.longitude];
    final bounds = LatLngBounds(
      southwest: LatLng(
        lats.reduce((a, b) => a < b ? a : b),
        lngs.reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        lats.reduce((a, b) => a > b ? a : b),
        lngs.reduce((a, b) => a > b ? a : b),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      _map?.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 80,
          right: 80,
          top: 80,
          bottom: 80,
        ),
      );
    });
  }

  Future<void> _fetchRoute() async {
    final trip = ref.read(currentTripProvider);
    if (trip == null) return;
    // Kick off both legs in parallel so the car always has a real path
    // to walk by the time each phase starts.
    final results = await Future.wait([
      DirectionsService.getRoute(
        origin: LatLng(trip.driver.currentLat, trip.driver.currentLng),
        destination: LatLng(trip.trip.pickupLat, trip.trip.pickupLng),
      ),
      DirectionsService.getRoute(
        origin: LatLng(trip.trip.pickupLat, trip.trip.pickupLng),
        destination: LatLng(trip.trip.dropoffLat, trip.trip.dropoffLng),
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _approachPoints = results[0]?.points;
      _routePoints = results[1]?.points;
    });
  }

  /// Active polyline for the current leg, or null to fall back to linear
  /// interpolation between [_legStart] and [_legEnd].
  List<LatLng>? get _activePoints {
    switch (_phase) {
      case _LivePhase.driverArriving:
        return _approachPoints;
      case _LivePhase.inTransit:
        return _routePoints;
      case _LivePhase.driverArrived:
        return null;
    }
  }

  void _updateCar() {
    final t = _carAnim.value;
    final points = _activePoints;

    if (points == null || points.length < 2) {
      final lat =
          _legStart.latitude + (_legEnd.latitude - _legStart.latitude) * t;
      final lng =
          _legStart.longitude + (_legEnd.longitude - _legStart.longitude) * t;
      setState(() => _carPos = LatLng(lat, lng));
      return;
    }

    // Walk the polyline: spread `t` across N-1 segments, interpolate the
    // active one. Result is a smooth-ish path along real roads.
    final n = points.length - 1;
    final scaled = (t * n).clamp(0.0, n.toDouble());
    final i = scaled.floor().clamp(0, n - 1);
    final segT = scaled - i;
    final a = points[i];
    final b = points[i + 1];
    final lat = a.latitude + (b.latitude - a.latitude) * segT;
    final lng = a.longitude + (b.longitude - a.longitude) * segT;
    setState(() => _carPos = LatLng(lat, lng));
  }

  void _phaseArrived() {
    if (!mounted) return;
    setState(() => _phase = _LivePhase.driverArrived);
    HapticFeedback.lightImpact();
    _updateTripStatus(TripStatus.ongoing);
    _phaseTimer = Timer(const Duration(seconds: 4), _phaseInTransit);
  }

  void _phaseInTransit() {
    if (!mounted) return;
    final trip = ref.read(currentTripProvider);
    if (trip == null) return;
    setState(() {
      _phase = _LivePhase.inTransit;
      _legStart = LatLng(trip.trip.pickupLat, trip.trip.pickupLng);
      _legEnd = LatLng(trip.trip.dropoffLat, trip.trip.dropoffLng);
      _carPos = _legStart;
    });
    _carAnim
      ..duration = const Duration(seconds: 8)
      ..reset()
      ..forward();
    _phaseTimer = Timer(const Duration(seconds: 8), _phaseCompleted);
  }

  Future<void> _phaseCompleted() async {
    if (!mounted || _navigated) return;
    _navigated = true;
    HapticFeedback.mediumImpact();
    context.go('/passenger/trip-summary/${widget.tripId}');
  }

  Future<void> _updateTripStatus(TripStatus status) async {
    try {
      await ref.read(tripServiceProvider).updateStatus(widget.tripId, status);
      if (!mounted) return;
      ref.read(currentTripProvider.notifier).updateStatus(status);
    } catch (_) {
      // Network blip; UI keeps moving regardless.
    }
  }

  Future<void> _cancelTrip() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hủy chuyến?'),
            content: const Text(
              'Bạn có thể bị tính phí nếu tài xế đã đến gần.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Không'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Hủy chuyến'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await ref.read(tripServiceProvider).cancelTrip(widget.tripId);
    if (!mounted) return;
    ref.read(currentTripProvider.notifier).clear();
    context.go('/passenger/home');
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _etaRefreshTimer?.cancel();
    _carAnim
      ..removeListener(_updateCar)
      ..dispose();
    // MapLibreMapController is owned by the widget tree.
    super.dispose();
  }

  ({String label, String emphasis}) get _statusText => switch (_phase) {
    _LivePhase.driverArriving => (
      label: 'Tài xế đến sau ',
      emphasis: '${_etaMinutes()} phút',
    ),
    _LivePhase.driverArrived => (label: 'Tài xế đã đến', emphasis: ' điểm đón'),
    _LivePhase.inTransit => (
      label: 'Đang đến đích ',
      emphasis: '${_etaMinutes()} phút',
    ),
  };

  /// Prefer the realtime Directions ETA when we have one; fall back to
  /// the animation-progress estimate so the UI never shows "—".
  int _etaMinutes() {
    final realtime = _realtimeEtaMinutes;
    if (realtime != null) return realtime;
    final remaining = (1 - _carAnim.value).clamp(0.0, 1.0);
    return (remaining * 8).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(currentTripProvider);
    if (trip == null) {
      // Defensive: navigated here without state.
      return Scaffold(
        appBar: AppBar(title: const Text('Chuyến đi')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  PhosphorIconsRegular.info,
                  color: AppColors.warning,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Không tìm thấy chuyến đang hoạt động',
                  style: AppTypography.body.copyWith(color: AppColors.ink700),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/passenger/home'),
                  child: const Text('Về trang chủ'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final mq = MediaQuery.of(context);
    const panelMin = 320.0;
    final panelMax = mq.size.height * 0.85;
    final pickup = LatLng(trip.trip.pickupLat, trip.trip.pickupLng);
    final dropoff = LatLng(trip.trip.dropoffLat, trip.trip.dropoffLng);
    final carPos = _carPos ?? pickup;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Stack(
        children: [
          SlidingUpPanel(
            minHeight: panelMin,
            maxHeight: panelMax,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            color: AppColors.white,
            backdropEnabled: true,
            backdropOpacity: 0.25,
            boxShadow: const [
              BoxShadow(
                blurRadius: 24,
                color: Color(0x1F000000),
                offset: Offset(0, -4),
              ),
            ],
            panelBuilder: (sc) => _PanelContent(
              scrollController: sc,
              trip: trip,
              onCancel: _cancelTrip,
            ),
            body: _MapBody(
              onMapCreated: (c) {
                _map = c;
                _fitBounds(pickup, dropoff, carPos);
              },
              pickup: pickup,
              dropoff: dropoff,
              carPos: carPos,
              routePoints: _routePoints ?? <LatLng>[pickup, dropoff],
            ),
          ),
          Positioned(
            top: mq.padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: TripStatusPill(
                label: _statusText.label,
                emphasis: _statusText.emphasis,
              ),
            ),
          ),
          Positioned(
            top: mq.padding.top + 16,
            right: 16,
            child: _SosButton(
              onTap: () => WgToast.error(
                context,
                'Đã gửi cảnh báo SOS. Liên hệ 112 nếu khẩn cấp.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// TrackAsia map for the live trip. Pickup/dropoff render as static
/// colored circles; the driver/car circle is tracked + relocated on
/// every animation tick by reading [carPos] from `didUpdateWidget`.
class _MapBody extends StatefulWidget {
  const _MapBody({
    required this.onMapCreated,
    required this.pickup,
    required this.dropoff,
    required this.carPos,
    required this.routePoints,
  });

  final ValueChanged<MapLibreMapController> onMapCreated;
  final LatLng pickup;
  final LatLng dropoff;
  final LatLng carPos;
  final List<LatLng> routePoints;

  @override
  State<_MapBody> createState() => _MapBodyState();
}

class _MapBodyState extends State<_MapBody> {
  MapLibreMapController? _ctrl;
  Circle? _carCircle;
  Line? _routeLine;
  bool _styleReady = false;

  @override
  void didUpdateWidget(_MapBody old) {
    super.didUpdateWidget(old);
    final ctrl = _ctrl;
    if (!_styleReady || ctrl == null) return;
    if (old.carPos != widget.carPos && _carCircle != null) {
      ctrl.updateCircle(_carCircle!, CircleOptions(geometry: widget.carPos));
    }
    if (!_listEqual(old.routePoints, widget.routePoints) &&
        _routeLine != null) {
      ctrl.updateLine(_routeLine!, LineOptions(geometry: widget.routePoints));
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
    final ctrl = _ctrl;
    if (ctrl == null) return;
    _routeLine = await ctrl.addLine(
      LineOptions(
        geometry: widget.routePoints,
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
    _carCircle = await ctrl.addCircle(
      CircleOptions(
        geometry: widget.carPos,
        circleRadius: 9,
        circleColor: '#0FB67E',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3,
      ),
    );
    _styleReady = true;
  }

  @override
  Widget build(BuildContext context) {
    return WgTrackAsiaMap(
      initialCenter: widget.pickup,
      initialZoom: 14,
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

class _SosButton extends StatelessWidget {
  const _SosButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: AppColors.danger,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () {
              HapticFeedback.heavyImpact();
              onTap();
            },
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                PhosphorIconsFill.shield,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'SOS',
          style: TextStyle(
            color: AppColors.danger,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PanelContent extends StatelessWidget {
  const _PanelContent({
    required this.scrollController,
    required this.trip,
    required this.onCancel,
  });

  final ScrollController scrollController;
  final ActiveTrip trip;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.ink300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        DriverInfoCard(driver: trip.driver, tripType: trip.trip.type),
        const SizedBox(height: 14),
        RouteSummaryCard(
          pickupAddress: trip.trip.pickupAddress,
          dropoffAddress: trip.trip.dropoffAddress,
          dense: true,
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              WgChip(
                label: 'Chia sẻ chuyến',
                leadingIcon: PhosphorIconsRegular.shareNetwork,
                onTap: () =>
                    WgToast.info(context, 'Đã copy link chia sẻ (mock)'),
              ),
              WgChip(
                label: 'An toàn',
                leadingIcon: PhosphorIconsRegular.shield,
                onTap: () => WgToast.info(context, 'Số khẩn cấp: 112'),
              ),
              WgChip(
                label: 'Hủy chuyến',
                leadingIcon: PhosphorIconsRegular.x,
                onTap: onCancel,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
