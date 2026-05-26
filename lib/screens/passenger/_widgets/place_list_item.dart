import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/place.dart';

class PlaceListItem extends StatelessWidget {
  const PlaceListItem({
    super.key,
    required this.place,
    this.distanceKm,
    this.onTap,
  });

  final Place place;
  final double? distanceKm;
  final VoidCallback? onTap;

  IconData _iconFor(String? key) {
    switch (key) {
      case 'flight':
        return PhosphorIconsFill.airplane;
      case 'landscape':
        return PhosphorIconsFill.mountains;
      case 'location_city':
        return PhosphorIconsFill.buildings;
      case 'storefront':
        return PhosphorIconsFill.storefront;
      case 'beach_access':
        return PhosphorIconsFill.umbrella;
      case 'school':
        return PhosphorIconsFill.graduationCap;
      case 'store':
        return PhosphorIconsFill.shoppingBag;
      case 'home':
        return PhosphorIconsFill.house;
      case 'business':
        return PhosphorIconsFill.briefcase;
      default:
        return PhosphorIconsFill.mapPin;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.primary100.withValues(alpha: 0.4),
      highlightColor: AppColors.primary50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.ink100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconFor(place.icon),
                color: AppColors.ink500,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 2),
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
            if (distanceKm != null) ...[
              const SizedBox(width: 12),
              Text(
                '${distanceKm!.toStringAsFixed(1)} km',
                style: AppTypography.caption.copyWith(
                  color: AppColors.ink500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
