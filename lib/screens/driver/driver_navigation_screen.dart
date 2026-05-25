import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/wg_avatar.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_toast.dart';
import '../../data/turn_instructions.dart';
import '../../providers/current_trip_provider.dart';
import '../../providers/driver_provider.dart';
import '../../providers/driver_service_provider.dart';
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
  final MapController _map = MapController();
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
    setState(() {
      _carPos = LatLng(
        _legStart.latitude + (_legEnd.latitude - _legStart.latitude) * t,
        _legStart.longitude + (_legEnd.longitude - _legStart.longitude) * t,
      );
    });
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
    });
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
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(currentTripProvider);
    if (trip == null) return _missing(context);

    final mq = MediaQuery.of(context);
    final pickup = LatLng(trip.trip.pickupLat, trip.trip.pickupLng);
    final dropoff = LatLng(trip.trip.dropoffLat, trip.trip.dropoffLng);
    final carPos = _carPos ?? pickup;
    final fitBounds = _phase == _Phase.toDropoff
        ? LatLngBounds.fromPoints([carPos, dropoff])
        : LatLngBounds.fromPoints([carPos, pickup]);

    final progress = _carAnim.value;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: fitBounds,
                padding: const EdgeInsets.fromLTRB(40, 200, 40, 320),
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
                    points: _phase == _Phase.toDropoff
                        ? [pickup, dropoff]
                        : [carPos, pickup],
                    color: _phase == _Phase.toDropoff
                        ? AppColors.primary500
                        : AppColors.ink500,
                    strokeWidth: 4.5,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: pickup,
                    width: 22,
                    height: 22,
                    child: _Dot(color: AppColors.success, circle: true),
                  ),
                  Marker(
                    point: dropoff,
                    width: 22,
                    height: 22,
                    child: _Dot(color: AppColors.danger, circle: false),
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
                alignment: AttributionAlignment.bottomRight,
                showFlutterMapAttribution: false,
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap',
                    textStyle: AppTypography.micro.copyWith(
                      color: AppColors.ink700,
                    ),
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
          // Top: instruction card
          Positioned(
            top: mq.padding.top + 12,
            left: 16,
            right: 16,
            child: NavigationInstructionCard(
              instruction: kTurnInstructions[_instructionIdx],
            ),
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
                  icon: _muted ? Icons.volume_off : Icons.volume_up_outlined,
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
                  icon: Icons.my_location,
                  iconColor: AppColors.primary500,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _map.move(carPos, 16);
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

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.circle});
  final Color color;
  final bool circle;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(4),
        border: Border.all(color: AppColors.white, width: 3),
      ),
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
            color: AppColors.ink900.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: const Icon(
        Icons.directions_car_rounded,
        color: AppColors.primary500,
        size: 22,
      ),
    );
  }
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
                Icons.access_time,
                '${((1 - progress) * 12).ceil()}p',
                'còn lại',
              ),
              _stat(Icons.straighten, '8.4 km', 'tổng'),
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
                icon: Icons.chat_bubble_outline,
                onTap: () =>
                    WgToast.info(context, 'Chat sẽ có ở phiên bản sau'),
              ),
              const SizedBox(width: 8),
              _PassengerAction(
                bg: AppColors.primary500,
                fg: Colors.white,
                icon: Icons.phone,
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
        leadingIcon: Icons.check_circle_outline,
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
