import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_toast.dart';
import '../../data/mock_places.dart';
import '../../models/place.dart';
import '../../models/trip.dart';
import '../../providers/auth_provider.dart';
import '../../providers/current_trip_provider.dart';
import '../../providers/trip_service_provider.dart';

class MatchingScreen extends ConsumerStatefulWidget {
  const MatchingScreen({super.key, required this.extra});
  final Map<String, Object> extra;

  @override
  ConsumerState<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends ConsumerState<MatchingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _orbit;
  int _activeStep = 0;
  bool _completed = false;
  Object? _error;
  String? _carpoolHostName; // populated when a carpool match is found

  late final List<String> _stepLabels;

  @override
  void initState() {
    super.initState();
    _stepLabels = [
      'Phân tích tuyến đường',
      'Tìm hành khách cùng hướng',
      'Chọn tài xế gần nhất',
    ];
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _runFlow();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _orbit.dispose();
    super.dispose();
  }

  /// 4-phase flow tied to real Mongo writes:
  ///   T=0   insert trip status=pending
  ///   T=1.5 try findCarpoolMatch → joinCarpool if hit
  ///   T=3.0 dispatch nearest driver → status=accepted
  ///   T=4.5 navigate to live-trip
  Future<void> _runFlow() async {
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) {
        throw Exception('Phiên đăng nhập đã hết. Vui lòng đăng nhập lại.');
      }
      final dropoffId = widget.extra['dropoffId'] as String;
      final dropoff = kDanangPlaces.firstWhere(
        (p) => p.id == dropoffId,
        orElse: () => throw Exception('Không tìm thấy điểm đến.'),
      );
      final pickup = Place(
        id: 'pickup_now',
        name: widget.extra['pickupAddress'] as String,
        address: widget.extra['pickupAddress'] as String,
        lat: widget.extra['pickupLat'] as double,
        lng: widget.extra['pickupLng'] as double,
      );
      final type = TripType.values.byName(widget.extra['type'] as String);
      final tripService = ref.read(tripServiceProvider);

      // Phase 1 — analyze (T=0 → 1.5s)
      setState(() => _activeStep = 0);
      final tripId = await tripService.insertPendingTrip(
        passengerId: user.id,
        pickup: pickup,
        dropoff: dropoff,
        type: type,
        price: widget.extra['price'] as int,
        distanceKm: widget.extra['distanceKm'] as double,
        durationMin: widget.extra['durationMin'] as int,
      );
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      // Phase 2 — carpool (T=1.5 → 3s)
      setState(() => _activeStep = 1);
      String activeTripId = tripId;
      bool carpooled = false;
      if (type == TripType.shared) {
        final host = await tripService.findCarpoolMatch(
          pickupLat: pickup.lat,
          pickupLng: pickup.lng,
          dropoffLat: dropoff.lat,
          dropoffLng: dropoff.lng,
          currentPassengerId: user.id,
        );
        if (host != null) {
          await tripService.joinCarpool(
            hostTripId: (host['_id'] as dynamic).oid as String,
            newPassengerId: user.id,
          );
          activeTripId = (host['_id'] as dynamic).oid as String;
          carpooled = true;
          if (mounted) {
            // Step 2 label gets a richer message when matched.
            setState(() {
              _carpoolHostName = 'hành khách khác';
              _stepLabels[1] = '✓ Đã ghép cùng tuyến với ${_carpoolHostName!}';
            });
          }
        }
      }
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      // Phase 3 — dispatch (T=3 → 4.5s) only if NOT carpooled into a
      // host that already has a driver assigned.
      setState(() => _activeStep = 2);
      ActiveTrip? active;
      if (carpooled) {
        // Host trip may already be accepted with a driver. Just load it.
        active = await tripService.loadActiveTrip(activeTripId);
      }
      active ??= await _dispatchOrFallback(
        tripService: tripService,
        tripId: activeTripId,
        pickup: pickup,
        dropoff: dropoff,
        type: type,
        passengerId: user.id,
      );

      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      ref.read(currentTripProvider.notifier).set(active);
      setState(() {
        _activeStep = _stepLabels.length;
        _completed = true;
      });
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      context.go('/passenger/live-trip/${active.tripId}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      WgToast.error(context, 'Không tạo được chuyến: $e');
    }
  }

  /// Tries to assign the nearest online driver. If matching engine returns
  /// nobody, falls back to the Phase 1B mock-driver path so the demo
  /// never dead-ends.
  Future<ActiveTrip> _dispatchOrFallback({
    required dynamic tripService,
    required String tripId,
    required Place pickup,
    required Place dropoff,
    required TripType type,
    required String passengerId,
  }) async {
    final driverDoc = await tripService.dispatchDriverToTrip(
      tripId: tripId,
      pickupLat: pickup.lat,
      pickupLng: pickup.lng,
    );
    if (driverDoc != null) {
      final active = await tripService.loadActiveTrip(tripId);
      if (active != null) return active;
    }
    // Fallback: legacy mock path — cancels the pending trip and creates
    // a fresh accepted trip with a random mock driver.
    await tripService.cancelTrip(tripId);
    return tripService.createTrip(
      passengerId: passengerId,
      pickup: pickup,
      dropoff: dropoff,
      type: type,
      price: widget.extra['price'] as int,
      distanceKm: widget.extra['distanceKm'] as double,
      durationMin: widget.extra['durationMin'] as int,
    );
  }

  Future<void> _cancelFlow() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hủy tìm xe?'),
            content: const Text(
              'Bạn sẽ quay lại trang chủ. Chuyến chưa được đặt.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Tiếp tục tìm'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Hủy'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    context.go('/passenger/home');
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.extra['price'] as int;
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: SafeArea(
        child: Stack(
          children: [
            // Close X top-right
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: _cancelFlow,
                icon: const Icon(
                  PhosphorIconsRegular.x,
                  color: AppColors.ink700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PulseLogo(pulse: _pulse, orbit: _orbit),
                        const SizedBox(height: 32),
                        Text(
                          _error != null
                              ? 'Có lỗi xảy ra'
                              : _completed
                              ? 'Tìm thấy tài xế!'
                              : 'Đang tìm tài xế phù hợp...',
                          style: AppTypography.h1,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error != null
                              ? 'Hãy thử lại sau ít phút'
                              : 'AI WeGo đang ghép bạn với\nhành khách cùng tuyến',
                          textAlign: TextAlign.center,
                          style: AppTypography.body.copyWith(
                            color: AppColors.ink500,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Divider(height: 1, color: AppColors.ink100),
                        const SizedBox(height: 20),
                        ...List.generate(_stepLabels.length, (i) {
                          final status = i < _activeStep
                              ? _StepStatus.done
                              : i == _activeStep
                              ? _StepStatus.active
                              : _StepStatus.pending;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: _StepRow(
                              label: _stepLabels[i],
                              status: status,
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                        const Divider(height: 1, color: AppColors.ink100),
                        const SizedBox(height: 16),
                        Text(
                          'Giá ước tính',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.ink500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatVnd(price),
                          style: AppTypography.h2.copyWith(
                            color: AppColors.primary500,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  WgButton.ghost(
                    label: 'Hủy tìm kiếm',
                    isFullWidth: true,
                    onPressed: _cancelFlow,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StepStatus { pending, active, done }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.status});
  final String label;
  final _StepStatus status;

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Widget child, Color textColor, FontWeight weight}) v =
        switch (status) {
          _StepStatus.done => (
            bg: AppColors.primary500,
            child: const Icon(
              PhosphorIconsBold.check,
              color: Colors.white,
              size: 14,
            ),
            textColor: AppColors.ink900,
            weight: FontWeight.w500,
          ),
          _StepStatus.active => (
            bg: AppColors.primary100,
            child: const _PulseDot(),
            textColor: AppColors.ink900,
            weight: FontWeight.w700,
          ),
          _StepStatus.pending => (
            bg: AppColors.ink100,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.ink300,
                shape: BoxShape.circle,
              ),
            ),
            textColor: AppColors.ink500,
            weight: FontWeight.w500,
          ),
        };

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: v.bg, shape: BoxShape.circle),
          child: Center(child: v.child),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: AppTypography.body.copyWith(
            color: v.textColor,
            fontWeight: v.weight,
          ),
        ),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.7,
        end: 1.1,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.primary500,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _PulseLogo extends StatelessWidget {
  const _PulseLogo({required this.pulse, required this.orbit});
  final AnimationController pulse;
  final AnimationController orbit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: Listenable.merge([pulse, orbit]),
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              _ring(160, 0.0),
              _ring(120, 0.33),
              _ring(80, 0.66),
              ..._orbitDots(),
              // Center icon (rotates with orbit speed for life)
              Transform.rotate(
                angle: orbit.value * 6.283,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primary500,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIconsFill.car,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(double maxSize, double phaseOffset) {
    final t = (pulse.value + phaseOffset) % 1.0;
    final scale = 0.5 + t;
    final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.35;
    final size = maxSize * scale;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary500.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }

  List<Widget> _orbitDots() {
    return List.generate(4, (i) {
      final angle = orbit.value * 6.283 + i * (6.283 / 4);
      const radius = 70.0;
      final dx = radius * math.cos(angle);
      final dy = radius * math.sin(angle);
      return Transform.translate(
        offset: Offset(dx, dy),
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.primary300,
            shape: BoxShape.circle,
          ),
        ),
      );
    });
  }
}
