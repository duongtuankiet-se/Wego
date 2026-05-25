import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/wg_chip.dart';
import '../../core/widgets/wg_map_pin.dart';
import '../../core/widgets/wg_toast.dart';
import '../../models/trip.dart';
import '../../providers/current_trip_provider.dart';
import '../../providers/trip_service_provider.dart';
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
  final MapController _map = MapController();
  late final AnimationController _carAnim;
  Timer? _phaseTimer;
  _LivePhase _phase = _LivePhase.driverArriving;
  bool _navigated = false;

  // Animated car position. Computed from _carAnim.value along the active leg.
  LatLng? _carPos;
  late LatLng _legStart;
  late LatLng _legEnd;

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
  }

  void _updateCar() {
    final t = _carAnim.value;
    final lat =
        _legStart.latitude + (_legEnd.latitude - _legStart.latitude) * t;
    final lng =
        _legStart.longitude + (_legEnd.longitude - _legStart.longitude) * t;
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
    _carAnim
      ..removeListener(_updateCar)
      ..dispose();
    _map.dispose();
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

  int _etaMinutes() {
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
                  Icons.info_outline,
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
              mapController: _map,
              pickup: pickup,
              dropoff: dropoff,
              carPos: carPos,
              showPickupPulse: _phase != _LivePhase.inTransit,
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

class _MapBody extends StatelessWidget {
  const _MapBody({
    required this.mapController,
    required this.pickup,
    required this.dropoff,
    required this.carPos,
    required this.showPickupPulse,
  });

  final MapController mapController;
  final LatLng pickup;
  final LatLng dropoff;
  final LatLng carPos;
  final bool showPickupPulse;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([pickup, dropoff, carPos]),
          padding: const EdgeInsets.fromLTRB(40, 100, 40, 360),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'vn.exe.wego',
          maxZoom: 19,
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: [pickup, dropoff],
              color: AppColors.primary500,
              strokeWidth: 4.5,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            if (showPickupPulse)
              Marker(
                point: pickup,
                width: 60,
                height: 60,
                child: const WgMapPin(),
              )
            else
              Marker(point: pickup, width: 22, height: 22, child: _OriginDot()),
            Marker(
              point: dropoff,
              width: 22,
              height: 22,
              child: _DestinationDot(),
            ),
            Marker(
              point: carPos,
              width: 44,
              height: 44,
              child: const _CarMarker(),
            ),
          ],
        ),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          showFlutterMapAttribution: false,
          attributions: [
            TextSourceAttribution(
              '© OpenStreetMap',
              textStyle: AppTypography.micro.copyWith(color: AppColors.ink700),
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }
}

class _CarMarker extends StatelessWidget {
  const _CarMarker();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary500, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink900.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: const Icon(
        Icons.directions_car_rounded,
        color: AppColors.primary500,
        size: 22,
      ),
    );
  }
}

class _OriginDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 3),
      ),
    );
  }
}

class _DestinationDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.white, width: 3),
      ),
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
              child: Icon(Icons.shield, color: Colors.white, size: 22),
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
                leadingIcon: Icons.share_outlined,
                onTap: () =>
                    WgToast.info(context, 'Đã copy link chia sẻ (mock)'),
              ),
              WgChip(
                label: 'An toàn',
                leadingIcon: Icons.shield_outlined,
                onTap: () => WgToast.info(context, 'Số khẩn cấp: 112'),
              ),
              WgChip(
                label: 'Hủy chuyến',
                leadingIcon: Icons.close,
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
