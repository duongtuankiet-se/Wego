import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_typography.dart';
import '../../data/mock_explore_places.dart';

/// "Khám phá điểm đến hôm nay" horizontal carousel. Auto-rotates every
/// 4s but pauses on user interaction. Each card is tappable.
class WgExploreCarousel extends StatelessWidget {
  const WgExploreCarousel({
    super.key,
    required this.places,
    required this.onPlaceTap,
    this.onViewAll,
  });

  final List<CityExplore> places;
  final ValueChanged<CityExplore> onPlaceTap;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text('✨ Hôm nay đi đâu nhỉ?', style: AppTypography.h3),
              const Spacer(),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(
                    'Xem tất cả',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CarouselSlider(
          options: CarouselOptions(
            height: 180,
            viewportFraction: 0.62,
            enableInfiniteScroll: true,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayAnimationDuration: const Duration(milliseconds: 900),
            autoPlayCurve: Curves.easeOutCubic,
            pauseAutoPlayOnTouch: true,
            padEnds: false,
          ),
          items: places
              .map(
                (p) => Builder(
                  builder: (_) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _ExploreCard(
                      place: p,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onPlaceTap(p);
                      },
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({required this.place, required this.onTap});
  final CityExplore place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: AppRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppRadius.card,
            boxShadow: AppShadows.xs,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: place.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    place.icon,
                    color: Colors.white.withValues(alpha: 0.92),
                    size: 56,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        place.name,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(
                            PhosphorIconsFill.star,
                            color: AppColors.warning,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${place.distanceKm.toStringAsFixed(1)} km',
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
