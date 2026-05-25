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
import '../../core/utils/format.dart';
import '../../core/widgets/wg_avatar.dart';
import '../../core/widgets/wg_incentive_card.dart';
import '../../core/widgets/wg_map_pin.dart';
import '../../core/widgets/wg_status_toggle.dart';
import '../../core/widgets/wg_toast.dart';
import '../../data/mock_hotspots.dart';
import '../../models/driver.dart';
import '../../providers/auth_provider.dart';
import '../../providers/current_trip_provider.dart';
import '../../providers/driver_provider.dart';
import '../../providers/driver_status_provider.dart';
import '../../providers/earnings_provider.dart';
import '../../providers/incoming_trip_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/trip_service_provider.dart';
import '_widgets/driver_stats_strip.dart';
import '_widgets/hotspot_card.dart';
import '_widgets/incoming_trip_modal.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  final MapController _map = MapController();
  Timer? _dispatchTimer;
  bool _modalOpen = false;
  bool _initialized = false;

  @override
  void dispose() {
    _dispatchTimer?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _scheduleDispatch(LatLng driverPos) {
    _dispatchTimer?.cancel();
    _dispatchTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      _showOffer(driverPos);
    });
  }

  Future<void> _showOffer(LatLng driverPos) async {
    if (_modalOpen) return;
    final status = ref.read(currentDriverStatusProvider).valueOrNull;
    final activeTrip = ref.read(currentTripProvider);
    if (status != DriverStatus.online || activeTrip != null) return;

    final offer = generateOffer(
      driverLat: driverPos.latitude,
      driverLng: driverPos.longitude,
    );
    ref.read(activeOfferProvider.notifier).set(offer);

    _modalOpen = true;
    final accepted = await showIncomingTripDialog(
      context,
      offer: offer,
      onAccept: () => _acceptOffer(offer),
    );
    _modalOpen = false;
    if (!mounted) return;
    if (!accepted) {
      // User declined → reschedule another offer after a short pause.
      WgToast.info(context, 'Đã từ chối — đang tìm chuyến khác...');
      _scheduleDispatch(driverPos);
    }
  }

  Future<bool> _acceptOffer(IncomingTripOffer offer) async {
    try {
      final driver = await ref.read(currentDriverProvider.future);
      final user = ref.read(authStateProvider).valueOrNull;
      if (driver == null || user == null) {
        throw Exception('Chưa đăng nhập tài xế');
      }
      // Reuse TripService.createTrip — it inserts the trip with status
      // accepted and wires up a mock passenger automatically. Here the
      // "passenger" is our offer's mock data; we still need to persist
      // a passenger doc reference so use the logged-in user as a stand-in.
      final tripService = ref.read(tripServiceProvider);
      final active = await tripService.createTrip(
        passengerId: user.id, // demo stand-in
        pickup: offer.pickup,
        dropoff: offer.dropoff,
        type: offer.type,
        price: offer.price,
        distanceKm: offer.tripDistanceKm,
        durationMin: offer.tripDurationMin,
      );
      ref.read(currentTripProvider.notifier).set(active);
      if (!mounted) return false;
      context.go('/driver/navigation/${active.tripId}');
      return true;
    } catch (e) {
      if (mounted) WgToast.error(context, 'Không nhận được chuyến: $e');
      return false;
    }
  }

  Future<void> _toggleStatus(LatLng pos) async {
    try {
      await ref
          .read(currentDriverStatusProvider.notifier)
          .toggle(lat: pos.latitude, lng: pos.longitude);
      if (!mounted) return;
      final newStatus = ref.read(currentDriverStatusProvider).valueOrNull;
      final isOnline = newStatus == DriverStatus.online;
      WgToast.success(
        context,
        isOnline ? 'Đã bật nhận chuyến' : 'Đã tắt nhận chuyến',
      );
      if (isOnline) {
        _scheduleDispatch(pos);
      } else {
        _dispatchTimer?.cancel();
      }
    } catch (e) {
      if (mounted) WgToast.error(context, 'Lỗi cập nhật trạng thái: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverAsync = ref.watch(currentDriverProvider);
    final statusAsync = ref.watch(currentDriverStatusProvider);
    final locAsync = ref.watch(currentLocationProvider);
    final statsAsync = ref.watch(driverTodayStatsProvider);
    final loc = locAsync.valueOrNull ?? kDanangFallback;

    // Kick off the first dispatch timer once status flips online.
    if (!_initialized && statusAsync.valueOrNull == DriverStatus.online) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scheduleDispatch(loc),
      );
    }

    final mq = MediaQuery.of(context);
    const panelMin = 280.0;
    final panelMax = mq.size.height * 0.78;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Stack(
        children: [
          SlidingUpPanel(
            minHeight: panelMin,
            maxHeight: panelMax,
            color: AppColors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            backdropEnabled: true,
            backdropOpacity: 0.25,
            boxShadow: const [
              BoxShadow(
                blurRadius: 24,
                color: Color(0x1F000000),
                offset: Offset(0, -4),
              ),
            ],
            panelBuilder: (sc) => _Panel(scrollController: sc),
            body: _MapBody(controller: _map, driverPos: loc),
          ),
          // Top header glass
          Positioned(
            top: mq.padding.top + 12,
            left: 16,
            right: 16,
            child: _TopHeader(driver: driverAsync.valueOrNull),
          ),
          // Status toggle below header
          Positioned(
            top: mq.padding.top + 76,
            left: 0,
            right: 0,
            child: Center(
              child: WgStatusToggle(
                online: statusAsync.valueOrNull == DriverStatus.online,
                disabled: driverAsync.valueOrNull == null,
                onToggle: (_) => _toggleStatus(loc),
              ),
            ),
          ),
          // FAB recenter
          Positioned(
            right: 16,
            bottom: panelMin + 88,
            child: _RecenterFab(
              onTap: () {
                HapticFeedback.mediumImpact();
                _map.move(loc, 14);
              },
            ),
          ),
          // Stats strip floating just above panel peek
          Positioned(
            left: 20,
            right: 20,
            bottom: panelMin + 16,
            child: _StatsBridge(stats: statsAsync),
          ),
        ],
      ),
    );
  }
}

class _MapBody extends StatelessWidget {
  const _MapBody({required this.controller, required this.driverPos});
  final MapController controller;
  final LatLng driverPos;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: driverPos,
        initialZoom: 13,
        minZoom: 4,
        maxZoom: 18,
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
        CircleLayer(
          circles: [
            for (final h in kHotspots)
              CircleMarker(
                point: LatLng(h.lat, h.lng),
                radius: h.heatRadius,
                useRadiusInMeter: false,
                color: h.heatColor.withValues(alpha: 0.25),
                borderColor: h.heatColor.withValues(alpha: 0.55),
                borderStrokeWidth: 1,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: driverPos,
              width: 50,
              height: 50,
              child: const WgMapPin(color: AppColors.info, size: 50),
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

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.driver});
  final Driver? driver;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Driver mini profile (glass pill)
        Flexible(
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink900.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                WgAvatar(name: driver?.name ?? 'WG', size: 36),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        driver?.name ?? 'Tài xế WeGo',
                        style: AppTypography.body.copyWith(
                          color: AppColors.ink900,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        driver?.vehiclePlate ?? '— · —',
                        style: AppTypography.micro.copyWith(
                          color: AppColors.ink500,
                          fontFamily: 'monospace',
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        _GlassIcon(
          icon: Icons.notifications_outlined,
          hasDot: true,
          onTap: () => WgToast.info(context, 'Chưa có thông báo mới'),
        ),
      ],
    );
  }
}

class _GlassIcon extends StatelessWidget {
  const _GlassIcon({
    required this.icon,
    required this.onTap,
    this.hasDot = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool hasDot;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.ink300.withValues(alpha: 0.5),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink900.withValues(alpha: 0.1),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(child: Icon(icon, color: AppColors.ink700, size: 22)),
              if (hasDot)
                Positioned(
                  top: 11,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecenterFab extends StatelessWidget {
  const _RecenterFab({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.ink900.withValues(alpha: 0.14),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.my_location,
            color: AppColors.primary500,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _StatsBridge extends ConsumerWidget {
  const _StatsBridge({required this.stats});
  final AsyncValue stats;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = stats.valueOrNull;
    final earnings = s?.earningsVnd ?? 0;
    final tripCount = s?.tripCount ?? 0;
    final activeMin = s?.activeMinutes ?? 0;
    final rating = s?.ratingAvg ?? 0.0;
    return GestureDetector(
      onTap: () => context.push('/driver/earnings'),
      child: DriverStatsStrip(
        earningsLabel: _short(earnings),
        tripCount: tripCount,
        activeLabel: _duration(activeMin),
        rating: rating,
      ),
    );
  }

  String _short(int vnd) {
    if (vnd == 0) return '0đ';
    if (vnd >= 1000000) return '${(vnd / 1000000).toStringAsFixed(1)}M';
    if (vnd >= 1000) return '${(vnd / 1000).round()}K';
    return formatVnd(vnd);
  }

  String _duration(int minutes) {
    if (minutes == 0) return '0p';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h == 0 ? '${m}p' : '${h}h${m}p';
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({required this.scrollController});
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(driverTodayStatsProvider).valueOrNull;
    final completedToday = stats?.tripCount ?? 0;

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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '🔥 Khu vực đông khách gần bạn',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.ink900,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...kHotspots.asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: HotspotCard(
              hotspot: e.value,
              onTap: () => WgToast.info(
                context,
                'Đang chỉ đường tới ${e.value.shortLabel}',
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: WgIncentiveCard(
            title: 'Thưởng chăm chỉ',
            completed: completedToday,
            target: 20,
            rewardVnd: 200000,
          ),
        ),
        const SizedBox(height: 14),
        _BottomActionsRow(),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _BottomActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Ví',
              onTap: () => context.push('/driver/wallet'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              icon: Icons.trending_up,
              label: 'Hiệu suất',
              onTap: () => context.push('/driver/performance'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary50,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary700, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.body.copyWith(
                  color: AppColors.primary700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
