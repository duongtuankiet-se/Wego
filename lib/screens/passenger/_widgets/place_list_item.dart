import 'package:flutter/material.dart';

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
        return Icons.flight;
      case 'landscape':
        return Icons.landscape;
      case 'location_city':
        return Icons.location_city;
      case 'storefront':
        return Icons.storefront;
      case 'beach_access':
        return Icons.beach_access;
      case 'school':
        return Icons.school;
      case 'store':
        return Icons.store;
      case 'home':
        return Icons.home;
      case 'business':
        return Icons.business;
      default:
        return Icons.location_on;
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
