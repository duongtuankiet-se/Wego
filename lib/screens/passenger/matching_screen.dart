import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  Timer? _stepTimer;
  int _activeStep = 0; // 0-3 (0..2 are running, 3 = all done)
  bool _completed = false;
  Object? _error;

  static const _steps = [
    'Phân tích tuyến đường',
    'Tìm hành khách cùng hướng',
    'Chọn tài xế tốt nhất',
  ];

  @override
  void initState() {
    super.initState();
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
    _stepTimer?.cancel();
    _pulse.dispose();
    _orbit.dispose();
    super.dispose();
  }

  void _runFlow() {
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1500), (t) {
      if (!mounted) return;
      setState(() => _activeStep++);
      if (_activeStep >= _steps.length) {
        t.cancel();
        _finalize();
      }
    });
  }

  Future<void> _finalize() async {
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
      final active = await tripService.createTrip(
        passengerId: user.id,
        pickup: pickup,
        dropoff: dropoff,
        type: type,
        price: widget.extra['price'] as int,
        distanceKm: widget.extra['distanceKm'] as double,
        durationMin: widget.extra['durationMin'] as int,
      );

      if (!mounted) return;
      ref.read(currentTripProvider.notifier).set(active);
      setState(() => _completed = true);

      // Brief pause so the user sees the final check before navigating.
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      context.go('/passenger/live-trip/${active.tripId}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      WgToast.error(context, 'Không tạo được chuyến: $e');
    }
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
    _stepTimer?.cancel();
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
                icon: const Icon(Icons.close, color: AppColors.ink700),
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
                        ...List.generate(_steps.length, (i) {
                          final status = i < _activeStep
                              ? _StepStatus.done
                              : i == _activeStep
                              ? _StepStatus.active
                              : _StepStatus.pending;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: _StepRow(label: _steps[i], status: status),
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
            child: const Icon(Icons.check, color: Colors.white, size: 14),
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
                    Icons.directions_car_rounded,
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
