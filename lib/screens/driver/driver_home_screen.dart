import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/wg_avatar.dart';
import '../../core/widgets/wg_glass.dart';
import '../../core/widgets/wg_trackasia_map.dart';
import '../../core/widgets/wg_incentive_card.dart';
import '../../core/widgets/wg_toast.dart';
import '../../data/mock_hotspots.dart';
import '../../models/driver.dart';
import '../../models/scheduled_trip.dart';
import '../../models/trip.dart';
import '../../providers/current_trip_provider.dart';
import '../../providers/driver_provider.dart';
import '../../providers/driver_status_provider.dart';
import '../../providers/earnings_provider.dart';
import '../../providers/incoming_trip_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/scheduled_trips_provider.dart';
import '../../providers/trip_offer_provider.dart';
import '../../providers/trip_service_provider.dart';
import '../../services/trip_offer_service.dart';
import '_widgets/driver_stats_strip.dart';
import '_widgets/incoming_trip_modal.dart';
import '_widgets/trip_offer_popup.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  MapLibreMapController? _map;
  bool _modalOpen = false;
  String? _lastHandledOfferId;
  // Phase 5R: dedupe popup across rapid 5s poll ticks so we don't stack
  // dialogs on top of each other while the driver is still answering.
  bool _offerPopupOpen = false;
  String? _lastOfferedTripId;

  @override
  void dispose() {
    // MapLibreMapController is owned by the widget.
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

  Future<void> _handleScheduledOffer(
    ScheduledTrip trip,
    int secondsLeft,
  ) async {
    if (_offerPopupOpen || _lastOfferedTripId == trip.id) return;
    _lastOfferedTripId = trip.id;
    _offerPopupOpen = true;
    final accepted = await TripOfferPopup.show(
      context,
      trip: trip,
      initialSecondsLeft: secondsLeft,
    );
    _offerPopupOpen = false;
    if (!mounted) return;
    if (!accepted) {
      // Re-arm the dedup key so a re-offer of the same trip after the
      // driver has fully cleared their queue can still show.
      _lastOfferedTripId = null;
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
    } on WalletGateException catch (e) {
      // Phase 5Q wallet gate: route the user to the wallet screen so
      // they can top up. Specific Vietnamese copy via [e.message].
      if (!mounted) return;
      WgToast.error(context, e.message);
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

    // Phase 5R: scheduled-trip offer popup. Fires whenever the polling
    // provider yields a non-empty offer that we haven't already shown.
    ref.listen<AsyncValue<CurrentOffer>>(driverCurrentOfferProvider, (
      prev,
      next,
    ) {
      final offer = next.valueOrNull;
      final trip = offer?.trip;
      if (trip != null) {
        _handleScheduledOffer(trip, offer!.secondsLeft);
      }
    });

    final mq = MediaQuery.of(context);
    final isOnline = statusAsync.valueOrNull == DriverStatus.online;
    final isDriverLoaded = driverAsync.valueOrNull != null;

    // Snap positions are fractions of screen height — peek (25%) keeps
    // the map nearly full-screen, the comfortable stop (55%) reveals
    // earnings + hotspots, and 85% expands the full scroll content.
    const minSize = 0.25;
    const initialSize = 0.3;
    const snapSizes = <double>[minSize, initialSize, 0.55, 0.85];
    const maxSize = 0.85;

    final peekPx = mq.size.height * initialSize;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Stack(
        children: [
          _MapBody(onMapCreated: (c) => _map = c, driverPos: loc),
          Positioned(
            top: mq.padding.top + 12,
            left: 16,
            right: 16,
            child: _TopHeader(
              driver: driverAsync.valueOrNull,
              unreadNotifications: ref.watch(unreadNotificationCountProvider),
              onBellTap: () => context.push('/notifications'),
            ),
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
            bottom: peekPx + 16,
            child: _RecenterFab(
              onTap: () {
                HapticFeedback.mediumImpact();
                _map?.animateCamera(CameraUpdate.newLatLngZoom(loc, 14));
              },
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: initialSize,
            minChildSize: minSize,
            maxChildSize: maxSize,
            snap: true,
            snapSizes: snapSizes,
            builder: (context, sc) => _Panel(
              scrollController: sc,
              statsAsync: statsAsync,
              driverId: driverAsync.valueOrNull?.id,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapBody extends StatefulWidget {
  const _MapBody({required this.onMapCreated, required this.driverPos});
  final ValueChanged<MapLibreMapController> onMapCreated;
  final LatLng driverPos;

  @override
  State<_MapBody> createState() => _MapBodyState();
}

class _MapBodyState extends State<_MapBody> {
  MapLibreMapController? _ctrl;
  Circle? _driverCircle;
  bool _styleReady = false;

  @override
  void didUpdateWidget(_MapBody old) {
    super.didUpdateWidget(old);
    if (_styleReady &&
        old.driverPos != widget.driverPos &&
        _driverCircle != null) {
      _ctrl?.updateCircle(
        _driverCircle!,
        CircleOptions(geometry: widget.driverPos),
      );
    }
  }

  Future<void> _onStyleLoaded() async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    // Hotspot demand zones — each gets two stacked circles for the
    // soft "heat" look (translucent outer + solid inner).
    for (final h in kHotspots) {
      final hex = '#${h.heatColor.toARGB32().toRadixString(16).substring(2)}';
      await ctrl.addCircle(
        CircleOptions(
          geometry: LatLng(h.lat, h.lng),
          circleRadius: h.heatRadius * 0.6,
          circleColor: hex,
          circleOpacity: 0.18,
          circleStrokeColor: hex,
          circleStrokeWidth: 1,
          circleStrokeOpacity: 0.55,
        ),
      );
    }
    _driverCircle = await ctrl.addCircle(
      CircleOptions(
        geometry: widget.driverPos,
        circleRadius: 10,
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
      initialCenter: widget.driverPos,
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
  const _TopHeader({
    required this.driver,
    required this.unreadNotifications,
    required this.onBellTap,
  });
  final Driver? driver;
  final int unreadNotifications;
  final VoidCallback onBellTap;

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
          hasDot: unreadNotifications > 0,
          onTap: onBellTap,
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
        borderRadius: BorderRadius.circular(20),
        // Phase 5O: horizontal layout (was a tall Column hero ~230px
        // that swallowed ~40% of the visible map). Same controls, ~80px.
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              width: 48,
              height: 48,
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
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isOnline ? 'Đang nhận chuyến' : 'Tạm nghỉ',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.ink900,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOnline
                        ? 'Hệ thống tự động ghép khách'
                        : 'Bật để bắt đầu nhận chuyến',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            CupertinoSwitch(
              value: isOnline,
              activeTrackColor: AppColors.primary500,
              onChanged: disabled
                  ? null
                  : (_) {
                      HapticFeedback.mediumImpact();
                      onToggle();
                    },
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
  const _Panel({
    required this.scrollController,
    required this.statsAsync,
    required this.driverId,
  });
  final ScrollController scrollController;
  final AsyncValue statsAsync;
  final String? driverId;

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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink900.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView(
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
          _SectionHeader(
            icon: PhosphorIconsFill.calendarPlus,
            iconColor: AppColors.sharedAccent,
            title: 'Chuyến sắp tới',
          ),
          const SizedBox(height: 10),
          _ScheduledTripsList(driverId: driverId),
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
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: PhosphorIconsRegular.usersThree,
                    label: 'Pool xe ghép',
                    onTap: () => context.push('/driver/pools'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: PhosphorIconsRegular.car,
                    label: 'Phương tiện',
                    onTap: () => context.push('/driver/vehicles'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
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
                    // Phase 5J: w700 + maxLines:1 caused VN diacritics (e.g.
                    // "Sân bay") to drop the â accent on Android system-font
                    // fallback. Cap at w600 + allow 2 lines so the accent
                    // never sits flush against the maxWidth boundary.
                    style: AppTypography.body.copyWith(
                      color: AppColors.ink900,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
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
                    fontWeight: FontWeight.w700,
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

class _ScheduledTripsList extends ConsumerWidget {
  const _ScheduledTripsList({required this.driverId});
  final String? driverId;

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    ScheduledTrip trip,
  ) async {
    if (driverId == null) {
      WgToast.error(context, 'Đang tải thông tin tài xế…');
      return;
    }
    final svc = ref.read(scheduledTripServiceProvider);
    final result = await svc.acceptScheduledTrip(
      tripId: trip.id,
      driverId: driverId!,
    );
    if (!context.mounted) return;
    // Hotfix: surface the specific reason now that acceptScheduledTrip
    // returns a record. The old blanket "tài xế khác đã nhận" toast
    // misfired any time a search-loop offer was in flight for the same
    // trip, even though no driver had actually accepted yet.
    //
    // Hotfix v2: `ref.invalidate` was fire-and-forget — the list still
    // rendered the just-accepted trip for the few hundred ms it took
    // the re-fetch to land. Use `ref.refresh(...).future` so we hold
    // the toast until the list is actually fresh.
    ref.invalidate(driverUpcomingTripsProvider);
    await ref.read(driverUpcomingTripsProvider.future);
    if (!context.mounted) return;
    if (result.success) {
      WgToast.success(context, 'Đã nhận chuyến ${trip.tripCode}');
    } else {
      WgToast.error(context, result.reason ?? 'Không thể nhận chuyến này');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(driverUpcomingTripsProvider);
    return tripsAsync.when(
      loading: () => const SizedBox(
        height: 124,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Không tải được danh sách chuyến đặt trước',
          style: AppTypography.caption.copyWith(color: AppColors.ink500),
        ),
      ),
      data: (trips) {
        if (trips.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.ink50,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.ink200, style: BorderStyle.solid),
              ),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.calendarBlank,
                    size: 22,
                    color: AppColors.ink400,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chưa có chuyến nào sắp tới — quay lại sau nhé!',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: trips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _ScheduledTripMiniCard(
              trip: trips[i],
              onAccept: () => _accept(context, ref, trips[i]),
            ),
          ),
        );
      },
    );
  }
}

class _ScheduledTripMiniCard extends StatelessWidget {
  const _ScheduledTripMiniCard({required this.trip, required this.onAccept});
  final ScheduledTrip trip;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sharedAccent.withValues(alpha: 0.2)),
        boxShadow: AppShadows.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.sharedAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trip.rideType == 'shared' ? 'XE GHÉP' : 'XE RIÊNG',
                  style: AppTypography.micro.copyWith(
                    color: AppColors.sharedAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                trip.countdownText,
                style: AppTypography.micro.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            trip.scheduledAtVN,
            style: AppTypography.caption.copyWith(
              color: AppColors.ink900,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${trip.pickup.name} → ${trip.dropoff.name}',
            style: AppTypography.micro.copyWith(
              color: AppColors.ink600,
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                formatVnd(trip.estimatedFare),
                style: AppTypography.body.copyWith(
                  color: AppColors.primary600,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 32,
                child: Material(
                  color: AppColors.primary500,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onAccept();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Nhận',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            PhosphorIconsRegular.arrowRight,
                            color: AppColors.white,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
