import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../core/widgets/wg_search_bar.dart';
import '../../data/mock_explore_places.dart';
import '../../models/place.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/selected_destination_provider.dart';

/// Phase 5I landing dashboard. Two hero cards drive the two primary
/// flows — instant booking ("Đặt ngay" → /passenger/search) and
/// scheduled ride ("Đặt sau" → /passenger/schedule). The legacy
/// 4-item quick-services grid was removed in 5I.
class PassengerHomeScreen extends ConsumerWidget {
  const PassengerHomeScreen({super.key});

  Future<void> _openSearch(BuildContext context) async {
    final picked = await context.push<Place>('/passenger/search');
    if (picked != null && context.mounted) {
      context.push('/passenger/ride-options');
    }
  }

  void _quickPickPlace(BuildContext context, WidgetRef ref, Place place) {
    ref.read(selectedDestinationProvider.notifier).set(place);
    context.push('/passenger/ride-options');
  }

  void _onExploreTap(BuildContext context, WidgetRef ref, CityExplore city) {
    final place = Place(
      id: city.id,
      name: city.name,
      address: city.tagline,
      lat: city.lat,
      lng: city.lng,
      icon: 'mapPin',
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
              SliverToBoxAdapter(
                child: _Header(
                  name: user?.name ?? 'bạn',
                  unreadCount: ref.watch(unreadNotificationCountProvider),
                  onBellTap: () => context.push('/notifications'),
                ),
              ),
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
                        child: _BookingHeroCard(
                          icon: PhosphorIconsFill.carProfile,
                          title: 'Đặt ngay',
                          subtitle: 'Tài xế tới sau 3-5 phút',
                          gradient: const [
                            AppColors.primary500,
                            AppColors.primary600,
                          ],
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _openSearch(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BookingHeroCard(
                          icon: PhosphorIconsFill.calendarPlus,
                          title: 'Đặt sau',
                          subtitle: 'Hẹn trước 30 phút – 7 ngày',
                          gradient: const [
                            AppColors.sharedAccent,
                            Color(0xFF0EA5E9),
                          ],
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push('/passenger/schedule');
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: WgExploreCarousel(
                    places: kCityExplorePlaces,
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
  const _Header({
    required this.name,
    required this.unreadCount,
    required this.onBellTap,
  });

  final String name;
  final int unreadCount;
  final VoidCallback onBellTap;

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
          _BellButton(unreadCount: unreadCount, onTap: onBellTap),
        ],
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.unreadCount, required this.onTap});

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: AppShadows.xs,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                PhosphorIconsRegular.bell,
                color: AppColors.ink700,
                size: 18,
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 1.5),
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

class _BookingHeroCard extends StatelessWidget {
  const _BookingHeroCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.heroCard,
        child: Container(
          height: 140,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.heroCard,
            boxShadow: AppShadows.heroGlow(gradient.first),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -8,
                bottom: -10,
                child: Icon(
                  icon,
                  size: 90,
                  color: AppColors.white.withValues(alpha: 0.18),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.white, size: 22),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTypography.h3.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
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
