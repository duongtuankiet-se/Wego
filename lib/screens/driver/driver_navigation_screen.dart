import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/geohash_util.dart';
import '../../core/widgets/wg_avatar.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_toast.dart';
import '../../data/turn_instructions.dart';
import '../../providers/current_trip_provider.dart';
import '../../providers/driver_provider.dart';
import '../../providers/driver_service_provider.dart';
import '../../services/directions_service.dart';
import '_widgets/navigation_instruction_card.dart';

class DriverNavigationScreen extends ConsumerStatefulWidget {
  const DriverNavigationScreen({super.key, required this.tripId});
  final String tripId;
  @override
  ConsumerState<DriverNavigationScreen> createState() =>
      _DriverNavigationScreenState();
}

enum _Phase { toPickup, arrived, toDropoff }

class _DriverNavigationScreenState extends ConsumerState<DriverNavigationScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _map;
  late final AnimationController _carAnim;
  Timer? _phaseTimer;
  Timer? _instructionTimer;
  Timer? _locationTimer;
  _Phase _phase = _Phase.toPickup;
  int _instructionIdx = 0;
  LatLng? _carPos;
  late LatLng _legStart;
  late LatLng _legEnd;
  bool _navigated = false;
  bool _muted = false;

  /// Real-route data for the active leg (driver→pickup or
  /// pickup→dropoff). Refreshed each phase transition. Contains both
  /// polyline points and turn-by-turn steps.
  DirectionsRoute? _route;
  int _currentStepIndex = 0;

  List<LatLng>? get _routePoints => _route?.points;

  @override
  void initState() {
    super.initState();
    final trip = ref.read(currentTripProvider);
    if (trip == null) return;

    // Spawn driver ~500m offset from pickup for visual "approaching".
    _legStart = LatLng(
      trip.trip.pickupLat - 0.004,
      trip.trip.pickupLng - 0.003,
    );
    _legEnd = LatLng(trip.trip.pickupLat, trip.trip.pickupLng);
    _carPos = _legStart;

    _carAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..addListener(_tickCar);
    _carAnim.forward();

    _phaseTimer = Timer(const Duration(seconds: 8), _onArrived);
    _instructionTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(
        () =>
            _instructionIdx = (_instructionIdx + 1) % kTurnInstructions.length,
      );
    });
    // Push driver location to Mongo every 3s so passengers + dispatch
    // see the car move in near-real-time.
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pushLocation();
    });
  }

  Future<void> _pushLocation() async {
    final pos = _carPos;
    if (pos == null) return;
    try {
      final driver = await ref.read(currentDriverProvider.future);
      if (driver == null) return;
      await ref
          .read(driverServiceProvider)
          .updateDriverLocation(
            driverId: driver.id,
            lat: pos.latitude,
            lng: pos.longitude,
          );
    } catch (_) {
      // Swallow — periodic push, transient failures are non-fatal.
    }
  }

  void _tickCar() {
    final t = _carAnim.value;
    final points = _routePoints;

    LatLng newPos;
    if (points == null || points.length < 2) {
      newPos = LatLng(
        _legStart.latitude + (_legEnd.latitude - _legStart.latitude) * t,
        _legStart.longitude + (_legEnd.longitude - _legStart.longitude) * t,
      );
    } else {
      final n = points.length - 1;
      final scaled = (t * n).clamp(0.0, n.toDouble());
      final i = scaled.floor().clamp(0, n - 1);
      final segT = scaled - i;
      final a = points[i];
      final b = points[i + 1];
      newPos = LatLng(
        a.latitude + (b.latitude - a.latitude) * segT,
        a.longitude + (b.longitude - a.longitude) * segT,
      );
    }

    setState(() => _carPos = newPos);
    _advanceStepIfClose(newPos);
  }

  /// Advance to the next maneuver when the car gets within 50m of the
  /// current step's endpoint. Triggers a haptic so the driver feels the
  /// instruction flip.
  void _advanceStepIfClose(LatLng carPos) {
    final steps = _route?.steps;
    if (steps == null || steps.isEmpty) return;
    if (_currentStepIndex >= steps.length - 1) return;
    final endLat = steps[_currentStepIndex].end.latitude;
    final endLng = steps[_currentStepIndex].end.longitude;
    final distMeters =
        GeohashUtil.distanceKm(
          carPos.latitude,
          carPos.longitude,
          endLat,
          endLng,
        ) *
        1000;
    if (distMeters < 50) {
      setState(() => _currentStepIndex++);
      HapticFeedback.lightImpact();
    }
  }

  void _onArrived() {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _phase = _Phase.arrived);
    WgToast.info(context, 'Bạn đã đến điểm đón');
  }

  Future<void> _markPickedUp() async {
    HapticFeedback.lightImpact();
    try {
      await ref.read(driverServiceProvider).markPickedUp(widget.tripId);
    } catch (_) {
      // Continue UX anyway; surfacing a toast would distract here.
    }
    if (!mounted) return;
    final trip = ref.read(currentTripProvider);
    if (trip == null) return;
    setState(() {
      _phase = _Phase.toDropoff;
      _legStart = LatLng(trip.trip.pickupLat, trip.trip.pickupLng);
      _legEnd = LatLng(trip.trip.dropoffLat, trip.trip.dropoffLng);
      _carPos = _legStart;
      _route = null;
      _currentStepIndex = 0;
    });
    _refreshRoute();
    _fitBounds(_legStart, _legEnd);
    _carAnim
      ..duration = const Duration(seconds: 12)
      ..reset()
      ..forward();
    _phaseTimer = Timer(const Duration(seconds: 12), _onCompleted);
  }

  Future<void> _onCompleted() async {
    if (!mounted || _navigated) return;
    _navigated = true;
    HapticFeedback.mediumImpact();
    final trip = ref.read(currentTripProvider);
    final driver = await ref.read(currentDriverProvider.future);
    if (trip == null || driver == null) return;
    try {
      await ref
          .read(driverServiceProvider)
          .completeAsDriver(
            tripId: widget.tripId,
            driverId: driver.id,
            price: trip.trip.price,
          );
    } catch (_) {}
    if (!mounted) return;
    context.go('/driver/trip-completed/${widget.tripId}');
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _instructionTimer?.cancel();
    _locationTimer?.cancel();
    _carAnim
      ..removeListener(_tickCar)
      ..dispose();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _refreshRoute() async {
    final start = _legStart;
    final end = _legEnd;
    final route = await DirectionsService.getRoute(
      origin: start,
      destination: end,
    );
    if (!mounted) return;
    setState(() {
      _route = route;
      _currentStepIndex = 0;
    });
  }

  /// Either the live Google step at [_currentStepIndex] or the cyclic
  /// mock when directions hasn't loaded yet.
  TurnInstruction _liveInstruction() {
    final steps = _route?.steps;
    if (steps != null && steps.isNotEmpty) {
      final step = steps[_currentStepIndex.clamp(0, steps.length - 1)];
      final nextStep = (_currentStepIndex + 1 < steps.length)
          ? steps[_currentStepIndex + 1]
          : null;
      return _stepToInstruction(step, nextStep);
    }
    return kTurnInstructions[_instructionIdx];
  }

  /// Convert a Google [DirectionsStep] into the shape our UI card expects.
  /// Splits the instruction text into a short verb ("Rẽ phải vào") + the
  /// rest ("Trần Phú") when there's a recognisable comma/space split,
  /// otherwise dumps everything into [streetName].
  TurnInstruction _stepToInstruction(
    DirectionsStep step,
    DirectionsStep? next,
  ) {
    final text = step.instruction.trim();
    String action;
    String street;
    final commaIdx = text.indexOf(' vào ');
    if (commaIdx > 0 && commaIdx < text.length - 5) {
      action = text.substring(0, commaIdx + 4); // include "vào"
      street = text.substring(commaIdx + 5).trim();
    } else {
      action = _maneuverLabel(step.maneuver);
      street = text;
    }
    return TurnInstruction(
      icon: _maneuverIcon(step.maneuver),
      action: action,
      streetName: street,
      distanceMeters: step.distanceMeters,
      nextHint: next?.instruction,
    );
  }

  IconData _maneuverIcon(String? maneuver) {
    switch (maneuver) {
      case 'turn-right':
      case 'turn-slight-right':
        return PhosphorIconsRegular.arrowBendUpRight;
      case 'turn-left':
      case 'turn-slight-left':
        return PhosphorIconsRegular.arrowBendUpLeft;
      case 'turn-sharp-right':
        return PhosphorIconsRegular.arrowUUpRight;
      case 'turn-sharp-left':
        return PhosphorIconsRegular.arrowUUpLeft;
      case 'uturn-right':
      case 'uturn-left':
        return PhosphorIconsRegular.arrowUUpLeft;
      case 'ramp-right':
      case 'ramp-left':
      case 'fork-right':
      case 'fork-left':
        return PhosphorIconsRegular.arrowsSplit;
      case 'merge':
        return PhosphorIconsRegular.arrowsMerge;
      case 'roundabout-right':
        return PhosphorIconsRegular.arrowsClockwise;
      case 'roundabout-left':
        return PhosphorIconsRegular.arrowsCounterClockwise;
      case 'straight':
      default:
        return PhosphorIconsRegular.arrowUp;
    }
  }

  String _maneuverLabel(String? maneuver) {
    switch (maneuver) {
      case 'turn-right':
      case 'turn-slight-right':
        return 'Rẽ phải';
      case 'turn-left':
      case 'turn-slight-left':
        return 'Rẽ trái';
      case 'turn-sharp-right':
        return 'Rẽ gấp phải';
      case 'turn-sharp-left':
        return 'Rẽ gấp trái';
      case 'uturn-right':
      case 'uturn-left':
        return 'Quay đầu';
      case 'merge':
        return 'Nhập làn';
      case 'roundabout-right':
      case 'roundabout-left':
        return 'Vào bùng binh';
      case 'fork-right':
      case 'fork-left':
        return 'Tách làn';
      case 'straight':
      default:
        return 'Tiếp tục';
    }
  }

  void _fitBounds(LatLng a, LatLng b) {
    final bounds = LatLngBounds(
      southwest: LatLng(
        a.latitude < b.latitude ? a.latitude : b.latitude,
        a.longitude < b.longitude ? a.longitude : b.longitude,
      ),
      northeast: LatLng(
        a.latitude > b.latitude ? a.latitude : b.latitude,
        a.longitude > b.longitude ? a.longitude : b.longitude,
      ),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      _map?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    });
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(currentTripProvider);
    if (trip == null) return _missing(context);

    final mq = MediaQuery.of(context);
    final pickup = LatLng(trip.trip.pickupLat, trip.trip.pickupLng);
    final dropoff = LatLng(trip.trip.dropoffLat, trip.trip.dropoffLng);
    final carPos = _carPos ?? pickup;

    final progress = _carAnim.value;
    final polyEnd = _phase == _Phase.toDropoff ? dropoff : pickup;
    final polyPoints = _routePoints ?? <LatLng>[carPos, polyEnd];

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: carPos, zoom: 14),
            onMapCreated: (c) {
              _map = c;
              _fitBounds(carPos, polyEnd);
              _refreshRoute();
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            polylines: <Polyline>{
              Polyline(
                polylineId: const PolylineId('leg'),
                points: polyPoints,
                color: _phase == _Phase.toDropoff
                    ? AppColors.primary500
                    : AppColors.ink500,
                width: 5,
              ),
            },
            markers: <Marker>{
              Marker(
                markerId: const MarkerId('pickup'),
                position: pickup,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
              ),
              Marker(
                markerId: const MarkerId('dropoff'),
                position: dropoff,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
              ),
              Marker(
                markerId: const MarkerId('driver'),
                position: carPos,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
              ),
            },
          ),
          // Top: instruction card
          Positioned(
            top: mq.padding.top + 12,
            left: 16,
            right: 16,
            child: NavigationInstructionCard(instruction: _liveInstruction()),
          ),
          // Speed limit badge
          Positioned(
            top: mq.padding.top + 168,
            left: 16,
            child: _SpeedLimitBadge(),
          ),
          // Floating buttons right
          Positioned(
            top: mq.padding.top + 168,
            right: 16,
            child: Column(
              children: [
                _CircleBtn(
                  icon: _muted
                      ? PhosphorIconsRegular.speakerSlash
                      : PhosphorIconsRegular.speakerHigh,
                  onTap: () {
                    setState(() => _muted = !_muted);
                    WgToast.info(
                      context,
                      _muted ? 'Đã tắt tiếng' : 'Đã bật tiếng',
                    );
                  },
                ),
                const SizedBox(height: 12),
                _CircleBtn(
                  icon: PhosphorIconsFill.crosshair,
                  iconColor: AppColors.primary500,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _map?.animateCamera(CameraUpdate.newLatLngZoom(carPos, 16));
                  },
                ),
              ],
            ),
          ),
          // Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomPanel(
              phase: _phase,
              progress: progress,
              price: trip.trip.price,
              passengerName: trip.driver.name, // mock: passenger label
              passengerRating: trip.driver.rating,
              tripTypeLabel: trip.trip.type.name == 'shared'
                  ? 'Xe ghép'
                  : 'Xe riêng',
              onMarkPickedUp: _markPickedUp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _missing(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Điều hướng')),
    body: Center(
      child: TextButton(
        onPressed: () => context.go('/driver/home'),
        child: const Text('Không có chuyến đang chạy — về trang chủ'),
      ),
    ),
  );
}

class _SpeedLimitBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.danger, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink900.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '50',
          style: TextStyle(
            color: AppColors.danger,
            fontWeight: FontWeight.w800,
            fontSize: 17,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({
    required this.icon,
    required this.onTap,
    this.iconColor = AppColors.ink700,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: AppColors.ink900.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.phase,
    required this.progress,
    required this.price,
    required this.passengerName,
    required this.passengerRating,
    required this.tripTypeLabel,
    required this.onMarkPickedUp,
  });
  final _Phase phase;
  final double progress;
  final int price;
  final String passengerName;
  final double passengerRating;
  final String tripTypeLabel;
  final VoidCallback onMarkPickedUp;

  String get _title => switch (phase) {
    _Phase.toPickup => 'Đang đến điểm đón',
    _Phase.arrived => 'Đã đến điểm đón',
    _Phase.toDropoff => 'Đang chở khách',
  };

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink900.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 18, 20, inset + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _title,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.ink900,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: AppTypography.body.copyWith(
                  color: AppColors.primary500,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.ink100,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary500),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat(
                PhosphorIconsRegular.clock,
                '${((1 - progress) * 12).ceil()}p',
                'còn lại',
              ),
              _stat(PhosphorIconsRegular.ruler, '8.4 km', 'tổng'),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Thu nhập',
                    style: AppTypography.micro.copyWith(
                      color: AppColors.ink500,
                    ),
                  ),
                  Text(
                    formatVnd(price),
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.primary500,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.ink100),
          const SizedBox(height: 14),
          Row(
            children: [
              WgAvatar(name: passengerName, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passengerName,
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink900,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '⭐ ${passengerRating.toStringAsFixed(2)} · $tripTypeLabel',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink500,
                      ),
                    ),
                  ],
                ),
              ),
              _PassengerAction(
                bg: AppColors.ink100,
                fg: AppColors.ink700,
                icon: PhosphorIconsRegular.chatCircle,
                onTap: () =>
                    WgToast.info(context, 'Chat sẽ có ở phiên bản sau'),
              ),
              const SizedBox(width: 8),
              _PassengerAction(
                bg: AppColors.primary500,
                fg: Colors.white,
                icon: PhosphorIconsFill.phone,
                onTap: () => WgToast.info(context, 'Đang kết nối...'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StateCta(phase: phase, onPickup: onMarkPickedUp),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () =>
                  WgToast.info(context, 'Báo cáo sẽ có ở phiên bản sau'),
              child: Text(
                'Báo cáo sự cố',
                style: AppTypography.caption.copyWith(color: AppColors.ink500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String hint) {
    return Column(
      children: [
        Icon(icon, color: AppColors.ink500, size: 14),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.body.copyWith(
            color: AppColors.ink900,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        ),
        Text(
          hint,
          style: AppTypography.micro.copyWith(color: AppColors.ink500),
        ),
      ],
    );
  }
}

class _PassengerAction extends StatelessWidget {
  const _PassengerAction({
    required this.bg,
    required this.fg,
    required this.icon,
    required this.onTap,
  });
  final Color bg;
  final Color fg;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: fg, size: 18),
        ),
      ),
    );
  }
}

class _StateCta extends StatelessWidget {
  const _StateCta({required this.phase, required this.onPickup});
  final _Phase phase;
  final VoidCallback onPickup;
  @override
  Widget build(BuildContext context) {
    return switch (phase) {
      _Phase.toPickup => WgButton.secondary(
        label: 'Đang đến điểm đón...',
        isFullWidth: true,
        onPressed: null,
      ),
      _Phase.arrived => WgButton.primary(
        label: '✓ Đón khách',
        size: WgButtonSize.lg,
        isFullWidth: true,
        leadingIcon: PhosphorIconsRegular.checkCircle,
        onPressed: onPickup,
      ),
      _Phase.toDropoff => WgButton.secondary(
        label: 'Đang chở khách...',
        isFullWidth: true,
        onPressed: null,
      ),
    };
  }
}
