import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/string_utils.dart';
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
import '../../models/trip.dart';
import '../../providers/auth_provider.dart';
import '../../providers/selected_destination_provider.dart';
import '../../providers/selected_ride_type_provider.dart';

/// Xanh SM-style landing dashboard. Compact 16px gutters, no map preview
/// (map only shown when picking a destination / live trip / driver home).
class PassengerHomeScreen extends ConsumerWidget {
  const PassengerHomeScreen({super.key});

  Future<void> _openSearch(BuildContext context) async {
    final picked = await context.push<Place>('/passenger/search');
    if (picked != null && context.mounted) {
      context.push('/passenger/ride-options');
    }
  }

  void _openSearchWithType(BuildContext context, WidgetRef ref, TripType type) {
    ref.read(selectedRideTypeProvider.notifier).set(type);
    _openSearch(context);
  }

  void _quickPickPlace(BuildContext context, WidgetRef ref, Place place) {
    ref.read(selectedDestinationProvider.notifier).set(place);
    context.push('/passenger/ride-options');
  }

  void _onExploreTap(BuildContext context, WidgetRef ref, ExplorePlace ep) {
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
    _quickPickPlace(context, ref, place);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary50, AppColors.offWhite],
            stops: [0.0, 0.35],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(name: user?.name ?? 'bạn')),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: WgSearchBar(onTap: () => _openSearch(context)),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: WgServiceCard.bookRide(
                          onTap: () => _openSearchWithType(
                            context,
                            ref,
                            TripType.private,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: WgServiceCard.bookShared(
                          onTap: () => _openSearchWithType(
                            context,
                            ref,
                            TripType.shared,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              SliverToBoxAdapter(
                child: _QuickServicesGrid(
                  onTileTap: (svc) {
                    if (svc.comingSoon) {
                      WgToast.info(context, '${svc.label} sẽ ra mắt sớm');
                    } else {
                      _openSearch(context);
                    }
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: WgExploreCarousel(
                    places: generateExplorePlaces(),
                    onPlaceTap: (ep) => _onExploreTap(context, ref, ep),
                    onViewAll: () => _openSearch(context),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _PromoStrip(
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
  const _Header({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name.split(' ').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          WgAvatar(name: initials, size: 36),
          const SizedBox(width: 10),
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
                const SizedBox(height: 1),
                Text(
                  toProperCase(name),
                  style: AppTypography.h3.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: AppShadows.xs,
            ),
            child: const Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  PhosphorIconsRegular.bell,
                  color: AppColors.ink700,
                  size: 18,
                ),
                Positioned(top: 9, right: 9, child: _NotificationDot()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationDot extends StatelessWidget {
  const _NotificationDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: AppColors.danger,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 1),
      ),
    );
  }
}

class _QuickServicesGrid extends StatelessWidget {
  const _QuickServicesGrid({required this.onTileTap});
  final ValueChanged<QuickService> onTileTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: AppRadius.card,
          boxShadow: AppShadows.xs,
        ),
        child: Row(
          children: kQuickServices
              .map(
                (s) => Expanded(
                  child: WgQuickServiceTile(
                    icon: s.icon,
                    label: s.label,
                    color: s.color,
                    onTap: () => onTileTap(s),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _PromoStrip extends StatelessWidget {
  const _PromoStrip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const titleColor = Color(0xFF92400E);
    const accent = Color(0xFFD97706);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(PhosphorIconsFill.gift, color: accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ưu đãi tuần này',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Giảm 30% cho 3 chuyến đầu',
                      style: AppTypography.caption.copyWith(color: titleColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                PhosphorIconsRegular.caretRight,
                color: accent,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
