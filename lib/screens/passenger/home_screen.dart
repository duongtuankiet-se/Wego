import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/geohash_util.dart';
import '../../core/widgets/wg_chip.dart';
import '../../core/widgets/wg_toast.dart';
import '../../data/mock_places.dart';
import '../../models/place.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/recent_destinations_provider.dart';
import '../../providers/selected_destination_provider.dart';

class PassengerHomeScreen extends ConsumerStatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  ConsumerState<PassengerHomeScreen> createState() =>
      _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends ConsumerState<PassengerHomeScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _map;
  late final AnimationController _greetingCtrl;

  @override
  void initState() {
    super.initState();
    _greetingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _greetingCtrl.forward();
    });
  }

  @override
  void dispose() {
    _greetingCtrl.dispose();
    _map?.dispose();
    super.dispose();
  }

  void _recenter(LatLng pos) {
    HapticFeedback.mediumImpact();
    _map?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
  }

  void _openSearch() async {
    final picked = await context.push<Place>('/passenger/search');
    if (picked != null && mounted) {
      // Search screen already sets selectedDestinationProvider — just navigate.
      context.push('/passenger/ride-options');
    }
  }

  void _quickPickShortcut(Place place) {
    HapticFeedback.lightImpact();
    ref.read(selectedDestinationProvider.notifier).set(place);
    ref.read(recentDestinationsProvider.notifier).add(place);
    context.push('/passenger/ride-options');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final locAsync = ref.watch(currentLocationProvider);
    final loc = locAsync.valueOrNull ?? kDanangFallback;
    final recentAsync = ref.watch(recentDestinationsProvider);
    final mq = MediaQuery.of(context);

    const panelMin = 96.0;
    final panelMax = mq.size.height * 0.85;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Stack(
        children: [
          // Sliding panel hosts the map as its body
          SlidingUpPanel(
            minHeight: panelMin,
            maxHeight: panelMax,
            defaultPanelState: PanelState.OPEN,
            snapPoint: 0.55,
            parallaxEnabled: true,
            parallaxOffset: 0.4,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
            panelBuilder: (scrollController) => _PanelContent(
              scrollController: scrollController,
              userName: user?.name ?? 'bạn',
              greetingCtrl: _greetingCtrl,
              recentAsync: recentAsync,
              origin: loc,
              onSearchTap: _openSearch,
              onShortcutTap: _quickPickShortcut,
              onRecentTap: _quickPickShortcut,
            ),
            body: _MapBody(
              onMapCreated: (c) => _map = c,
              center: loc,
            ),
          ),
          // Floating top buttons (above panel + map)
          Positioned(
            top: mq.padding.top + 12,
            left: 16,
            child: _GlassButton(
              icon: Icons.menu,
              onTap: () => WgToast.info(context, 'Menu sẽ có ở phase sau'),
            ),
          ),
          Positioned(
            top: mq.padding.top + 12,
            right: 16,
            child: _GlassButton(
              icon: Icons.notifications_outlined,
              hasDot: true,
              onTap: () => WgToast.info(context, 'Chưa có thông báo mới'),
            ),
          ),
          // FAB recenter (sits above sliding panel peek)
          Positioned(
            right: 16,
            bottom: panelMin + 20,
            child: _RecenterFab(onTap: () => _recenter(loc)),
          ),
        ],
      ),
    );
  }
}

class _MapBody extends StatelessWidget {
  const _MapBody({required this.onMapCreated, required this.center});
  final ValueChanged<GoogleMapController> onMapCreated;
  final LatLng center;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 15),
      onMapCreated: onMapCreated,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      markers: <Marker>{
        Marker(
          markerId: const MarkerId('me'),
          position: center,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      },
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
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
            border: Border.all(color: AppColors.ink300, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink900.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(child: Icon(icon, color: AppColors.ink700, size: 22)),
              if (hasDot)
                Positioned(
                  top: 10,
                  right: 11,
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
                color: AppColors.ink900.withValues(alpha: 0.12),
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

class _PanelContent extends StatelessWidget {
  const _PanelContent({
    required this.scrollController,
    required this.userName,
    required this.greetingCtrl,
    required this.recentAsync,
    required this.origin,
    required this.onSearchTap,
    required this.onShortcutTap,
    required this.onRecentTap,
  });

  final ScrollController scrollController;
  final String userName;
  final AnimationController greetingCtrl;
  final AsyncValue<List<Place>> recentAsync;
  final LatLng origin;
  final VoidCallback onSearchTap;
  final ValueChanged<Place> onShortcutTap;
  final ValueChanged<Place> onRecentTap;

  static const _shortcuts = [
    (Icons.home_outlined, 'Nhà', 'p7'),
    (Icons.business_outlined, 'Công ty', 'p4'),
    (Icons.flight, 'Sân bay', 'p1'),
    (Icons.beach_access, 'Biển Mỹ Khê', 'p6'),
  ];

  @override
  Widget build(BuildContext context) {
    final recent = recentAsync.valueOrNull ?? const <Place>[];
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: _FadeSlide(
            controller: greetingCtrl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, $userName 👋',
                  style: AppTypography.h1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Bạn muốn đi đâu hôm nay?',
                  style: AppTypography.body.copyWith(color: AppColors.ink500),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: onSearchTap,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.ink100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.ink500, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    'Tìm điểm đến',
                    style: AppTypography.body.copyWith(color: AppColors.ink500),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _shortcuts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final (icon, label, placeId) = _shortcuts[i];
              return _StaggerFadeIn(
                delay: Duration(milliseconds: 400 + i * 60),
                child: WgChip(
                  label: label,
                  leadingIcon: icon,
                  onTap: () {
                    final place = _findPlaceById(placeId);
                    if (place != null) onShortcutTap(place);
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'Đã đi gần đây',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.ink900),
          ),
        ),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              'Chưa có chuyến đi. Thử tìm điểm đến phía trên!',
              style: AppTypography.body.copyWith(color: AppColors.ink500),
            ),
          )
        else
          ...List.generate(recent.length.clamp(0, 3), (i) {
            final p = recent[i];
            final dist = GeohashUtil.distanceKm(
              origin.latitude,
              origin.longitude,
              p.lat,
              p.lng,
            );
            return _StaggerFadeIn(
              delay: Duration(milliseconds: 600 + i * 100),
              child: _RecentRow(
                place: p,
                distanceKm: dist,
                onTap: () => onRecentTap(p),
              ),
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.place,
    required this.distanceKm,
    required this.onTap,
  });
  final Place place;
  final double distanceKm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: AppColors.ink500, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      color: AppColors.ink900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    place.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${distanceKm.toStringAsFixed(1)} km',
              style: AppTypography.caption.copyWith(
                color: AppColors.ink500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FadeSlide extends StatelessWidget {
  const _FadeSlide({required this.controller, required this.child});
  final AnimationController controller;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Opacity(
          opacity: controller.value,
          child: Transform.translate(
            offset: Offset(0, (1 - controller.value) * 10),
            child: child,
          ),
        );
      },
    );
  }
}

class _StaggerFadeIn extends StatefulWidget {
  const _StaggerFadeIn({required this.delay, required this.child});
  final Duration delay;
  final Widget child;
  @override
  State<_StaggerFadeIn> createState() => _StaggerFadeInState();
}

class _StaggerFadeInState extends State<_StaggerFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
            ),
        child: widget.child,
      ),
    );
  }
}

Place? _findPlaceById(String id) {
  for (final p in kDanangPlaces) {
    if (p.id == id) return p;
  }
  return null;
}
