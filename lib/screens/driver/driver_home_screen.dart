import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/wg_avatar.dart';
import '../../core/widgets/wg_glass.dart';
import '../../core/widgets/wg_incentive_card.dart';
import '../../core/widgets/wg_toast.dart';
import '../../data/mock_hotspots.dart';
import '../../models/driver.dart';
import '../../models/trip.dart';
import '../../providers/current_trip_provider.dart';
import '../../providers/driver_provider.dart';
import '../../providers/driver_status_provider.dart';
import '../../providers/earnings_provider.dart';
import '../../providers/incoming_trip_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/trip_service_provider.dart';
import '_widgets/driver_stats_strip.dart';
import '_widgets/incoming_trip_modal.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  GoogleMapController? _map;
  bool _modalOpen = false;
  String? _lastHandledOfferId;

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Future<void> _handleIncomingOffer(IncomingTripOffer offer) async {
    if (_modalOpen || offer.offerId == _lastHandledOfferId) return;
    _lastHandledOfferId = offer.offerId;
    _modalOpen = true;
    final accepted = await showIncomingTripDialog(
      context,
      offer: offer,
      onAccept: () => _acceptOffer(offer),
    );
    _modalOpen = false;
    if (!mounted) return;
    if (!accepted) {
      if (offer.tripId != null) {
        try {
          await ref
              .read(tripServiceProvider)
              .updateStatus(offer.tripId!, TripStatus.pending);
        } catch (_) {}
      }
      if (!mounted) return;
      WgToast.info(context, 'Đã từ chối — đang tìm chuyến khác...');
      ref.invalidate(incomingTripPollProvider);
    }
  }

  Future<bool> _acceptOffer(IncomingTripOffer offer) async {
    try {
      if (offer.tripId != null) {
        final tripService = ref.read(tripServiceProvider);
        final active = await tripService.loadActiveTrip(offer.tripId!);
        if (active == null) {
          throw Exception('Không tải được chuyến đi');
        }
        ref.read(currentTripProvider.notifier).set(active);
        if (!mounted) return false;
        context.go('/driver/navigation/${active.tripId}');
        return true;
      }
      throw Exception('Offer không có tripId — cần passenger book trước');
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
        ref.invalidate(incomingTripPollProvider);
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

    ref.listen<AsyncValue<IncomingTripOffer?>>(incomingTripPollProvider, (
      prev,
      next,
    ) {
      final offer = next.valueOrNull;
      if (offer != null && offer.tripId != null) {
        _handleIncomingOffer(offer);
      }
    });

    final mq = MediaQuery.of(context);
    const panelMin = 96.0;
    final panelMax = mq.size.height * 0.72;
    final isOnline = statusAsync.valueOrNull == DriverStatus.online;
    final isDriverLoaded = driverAsync.valueOrNull != null;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Stack(
        children: [
          SlidingUpPanel(
            minHeight: panelMin,
            maxHeight: panelMax,
            defaultPanelState: PanelState.CLOSED,
            snapPoint: 0.5,
            parallaxEnabled: true,
            parallaxOffset: 0.4,
            color: AppColors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            backdropEnabled: true,
            backdropOpacity: 0.2,
            boxShadow: const [
              BoxShadow(
                blurRadius: 24,
                color: Color(0x1F000000),
                offset: Offset(0, -4),
              ),
            ],
            panelBuilder: (sc) =>
                _Panel(scrollController: sc, statsAsync: statsAsync),
            body: _MapBody(onMapCreated: (c) => _map = c, driverPos: loc),
          ),
          Positioned(
            top: mq.padding.top + 12,
            left: 16,
            right: 16,
            child: _TopHeader(driver: driverAsync.valueOrNull),
          ),
          Positioned(
            top: mq.padding.top + 84,
            left: 16,
            right: 16,
            child: _StatusHeroCard(
              isOnline: isOnline,
              disabled: !isDriverLoaded,
              onToggle: () => _toggleStatus(loc),
            ),
          ),
          Positioned(
            right: 16,
            bottom: panelMin + 16,
            child: _RecenterFab(
              onTap: () {
                HapticFeedback.mediumImpact();
                _map?.animateCamera(CameraUpdate.newLatLngZoom(loc, 14));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MapBody extends StatelessWidget {
  const _MapBody({required this.onMapCreated, required this.driverPos});
  final ValueChanged<GoogleMapController> onMapCreated;
  final LatLng driverPos;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: driverPos, zoom: 13),
      onMapCreated: onMapCreated,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      circles: <Circle>{
        for (final h in kHotspots)
          Circle(
            circleId: CircleId(h.id),
            center: LatLng(h.lat, h.lng),
            radius: h.heatRadius * 8,
            fillColor: h.heatColor.withValues(alpha: 0.18),
            strokeColor: h.heatColor.withValues(alpha: 0.55),
            strokeWidth: 1,
          ),
      },
      markers: <Marker>{
        Marker(
          markerId: const MarkerId('driver'),
          position: driverPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      },
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
        Expanded(
          child: WgGlass(
            borderRadius: BorderRadius.circular(999),
            opacity: 0.82,
            padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
            child: Row(
              children: [
                WgAvatar(name: driver?.name ?? 'WG', size: 36),
                const SizedBox(width: 10),
                Expanded(
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _GlassIcon(
          icon: PhosphorIconsRegular.bell,
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
    return WgGlass(
      borderRadius: BorderRadius.circular(20),
      opacity: 0.82,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              children: [
                Center(child: Icon(icon, color: AppColors.ink700, size: 20)),
                if (hasDot)
                  Positioned(
                    top: 10,
                    right: 11,
                    child: Container(
                      width: 7,
                      height: 7,
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
      ),
    );
  }
}

class _StatusHeroCard extends StatelessWidget {
  const _StatusHeroCard({
    required this.isOnline,
    required this.disabled,
    required this.onToggle,
  });

  final bool isOnline;
  final bool disabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.6 : 1.0,
      child: WgGlass(
        blur: 30,
        opacity: 0.92,
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isOnline
                      ? const [AppColors.primary400, AppColors.primary600]
                      : const [AppColors.ink300, AppColors.ink400],
                ),
                boxShadow: isOnline
                    ? AppShadows.heroGlow(AppColors.primary500)
                    : const [],
              ),
              child: Icon(
                isOnline
                    ? PhosphorIconsFill.carProfile
                    : PhosphorIconsFill.power,
                color: AppColors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isOnline ? 'Đang nhận chuyến' : 'Tạm nghỉ',
              style: AppTypography.h2.copyWith(
                color: AppColors.ink900,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              isOnline
                  ? 'Hệ thống sẽ tự động ghép khách cho bạn'
                  : 'Bật để bắt đầu nhận chuyến',
              style: AppTypography.caption.copyWith(color: AppColors.ink500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Transform.scale(
              scale: 1.2,
              child: CupertinoSwitch(
                value: isOnline,
                activeTrackColor: AppColors.primary500,
                onChanged: disabled
                    ? null
                    : (_) {
                        HapticFeedback.mediumImpact();
                        onToggle();
                      },
              ),
            ),
          ],
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppShadows.md,
      ),
      child: ClipOval(
        child: Material(
          color: AppColors.white,
          child: InkWell(
            onTap: onTap,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                PhosphorIconsFill.crosshair,
                color: AppColors.primary500,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({required this.scrollController, required this.statsAsync});
  final ScrollController scrollController;
  final AsyncValue statsAsync;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = statsAsync.valueOrNull;
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () => context.push('/driver/earnings'),
            child: DriverStatsStrip(
              earningsLabel: _short(stats?.earningsVnd ?? 0),
              tripCount: stats?.tripCount ?? 0,
              activeLabel: _duration(stats?.activeMinutes ?? 0),
              rating: stats?.ratingAvg ?? 0.0,
            ),
          ),
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          icon: PhosphorIconsFill.fire,
          iconColor: AppColors.danger,
          title: 'Khu vực đông khách',
          trailing: 'Xem tất cả',
          onTrailing: () =>
              WgToast.info(context, 'Xem hotspot toàn thành phố sắp ra mắt'),
        ),
        const SizedBox(height: 10),
        const _HotspotHorizontalList(),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: WgIncentiveCard(
            title: 'Thưởng chăm chỉ',
            completed: completedToday,
            target: 20,
            rewardVnd: 200000,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: PhosphorIconsRegular.wallet,
                  label: 'Ví',
                  onTap: () => context.push('/driver/wallet'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: PhosphorIconsRegular.trendUp,
                  label: 'Hiệu suất',
                  onTap: () => context.push('/driver/performance'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    this.onTrailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.ink900,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailing,
              child: Text(
                trailing!,
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HotspotHorizontalList extends StatelessWidget {
  const _HotspotHorizontalList();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kHotspots.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _HotspotMiniCard(hotspot: kHotspots[i]),
      ),
    );
  }
}

class _HotspotMiniCard extends StatelessWidget {
  const _HotspotMiniCard({required this.hotspot});
  final Hotspot hotspot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          WgToast.info(context, 'Đang chỉ đường tới ${hotspot.shortLabel}'),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: hotspot.heatColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(hotspot.icon, color: hotspot.heatColor, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hotspot.shortLabel,
                    style: AppTypography.body.copyWith(
                      color: AppColors.ink900,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  '${hotspot.activeRequests}',
                  style: AppTypography.h3.copyWith(
                    color: hotspot.heatColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'yêu cầu',
                  style: AppTypography.micro.copyWith(color: AppColors.ink500),
                ),
                const Spacer(),
                Text(
                  '${hotspot.distanceKm.toStringAsFixed(1)} km',
                  style: AppTypography.micro.copyWith(
                    color: AppColors.ink500,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
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
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.body.copyWith(
                    color: AppColors.primary700,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
