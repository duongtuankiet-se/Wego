import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/wg_avatar.dart';
import '../../core/widgets/wg_explore_carousel.dart';
import '../../core/widgets/wg_quick_service_tile.dart';
import '../../core/widgets/wg_search_bar.dart';
import '../../core/widgets/wg_service_card.dart';
import '../../core/widgets/wg_toast.dart';
import '../../data/mock_explore_places.dart';
import '../../data/mock_places.dart';
import '../../data/mock_quick_services.dart';
import '../../models/place.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/selected_destination_provider.dart';

/// Hybrid landing dashboard: small Google Map banner pinned at the top,
/// scrollable Xanh SM-style content below (search → carousel → hero
/// banners → quick-services grid → promo).
class PassengerHomeScreen extends ConsumerStatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  ConsumerState<PassengerHomeScreen> createState() =>
      _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends ConsumerState<PassengerHomeScreen> {
  GoogleMapController? _map;

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  void _openSearch() async {
    final picked = await context.push<Place>('/passenger/search');
    if (picked != null && mounted) {
      context.push('/passenger/ride-options');
    }
  }

  void _quickPickPlace(Place place) {
    ref.read(selectedDestinationProvider.notifier).set(place);
    context.push('/passenger/ride-options');
  }

  void _onExploreTap(ExplorePlace ep) {
    // Convert ExplorePlace → Place by reading the matching mock entry
    // when ids overlap, else build a one-shot Place.
    final match = kDanangPlaces.where((p) => p.name == ep.name);
    final place = match.isNotEmpty
        ? match.first
        : Place(
            id: ep.id,
            name: ep.name,
            address: ep.tagline,
            lat: 16.0544 + (ep.distanceKm * 0.001),
            lng: 108.2022,
          );
    _quickPickPlace(place);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final loc =
        ref.watch(currentLocationProvider).valueOrNull ?? kDanangFallback;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary50, AppColors.offWhite],
            stops: [0.0, 0.45],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(user: user)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                  child: WgSearchBar(onTap: _openSearch),
                ),
              ),
              SliverToBoxAdapter(
                child: _MapBanner(
                  center: loc,
                  onMapCreated: (c) => _map = c,
                  onTap: _openSearch,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: WgServiceCard.bookRide(onTap: _openSearch),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: WgServiceCard.bookFood(
                          onTap: () =>
                              WgToast.info(context, 'Đặt đồ ăn sẽ ra mắt sớm'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: WgExploreCarousel(
                    places: generateExplorePlaces(),
                    onPlaceTap: _onExploreTap,
                    onViewAll: _openSearch,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
              SliverToBoxAdapter(
                child: _QuickServicesSection(
                  onTileTap: (svc) => svc.comingSoon
                      ? WgToast.info(context, '${svc.label} sẽ ra mắt sớm')
                      : _openSearch(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: _PromoBanner(
                    onTap: () => context.go('/passenger/promo'),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final name = user?.name as String? ?? 'bạn';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary300, width: 2),
            ),
            padding: const EdgeInsets.all(2),
            child: WgAvatar(name: name, size: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Xin chào,',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                  ),
                ),
                Text(
                  name,
                  style: AppTypography.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppShadows.xs,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  PhosphorIconsRegular.bell,
                  color: AppColors.ink700,
                  size: 22,
                ),
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
        ],
      ),
    );
  }
}

class _MapBanner extends StatelessWidget {
  const _MapBanner({
    required this.center,
    required this.onMapCreated,
    required this.onTap,
  });
  final LatLng center;
  final ValueChanged<GoogleMapController> onMapCreated;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: AppRadius.heroCard,
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: AppRadius.heroCard,
            boxShadow: AppShadows.sm,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: center,
                    zoom: 14,
                  ),
                  onMapCreated: onMapCreated,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  rotateGesturesEnabled: false,
                  scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  liteModeEnabled: false,
                  markers: <Marker>{
                    Marker(
                      markerId: const MarkerId('me'),
                      position: center,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ),
                    ),
                  },
                ),
              ),
              // Tap overlay → go to search (since map gestures are off)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    splashColor: AppColors.primary500.withValues(alpha: 0.08),
                  ),
                ),
              ),
              // Small pill bottom-right showing "Vị trí của bạn"
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: AppShadows.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIconsFill.mapPin,
                        color: AppColors.primary500,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Vị trí của bạn',
                        style: AppTypography.micro.copyWith(
                          color: AppColors.ink900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

class _QuickServicesSection extends StatelessWidget {
  const _QuickServicesSection({required this.onTileTap});
  final ValueChanged<QuickService> onTileTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dịch vụ khác', style: AppTypography.h3),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: AppRadius.card,
              boxShadow: AppShadows.xs,
            ),
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.82,
              children: kQuickServices
                  .map(
                    (s) => WgQuickServiceTile(
                      icon: s.icon,
                      label: s.label,
                      color: s.color,
                      onTap: () => onTileTap(s),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.heroCard,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFEF3C7), Color(0xFFFEFBEA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.heroCard,
            boxShadow: AppShadows.xs,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  PhosphorIconsFill.gift,
                  color: AppColors.warning,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ưu đãi tuần này',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF8B6F47),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Giảm 30% chuyến cuối tuần — xem ngay',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                PhosphorIconsRegular.caretRight,
                color: AppColors.ink400,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
