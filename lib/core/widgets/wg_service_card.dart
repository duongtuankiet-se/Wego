import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_typography.dart';

/// Hero service banner used on the passenger home. Subtle gradient
/// background + large corner Phosphor icon as the focal illustration.
class WgServiceCard extends StatelessWidget {
  const WgServiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.gradient,
    required this.onTap,
  });

  /// Primary "Đặt xe" hero — mint green.
  factory WgServiceCard.bookRide({required VoidCallback onTap}) =>
      WgServiceCard(
        title: 'Đặt xe',
        subtitle: 'Nhanh & tiện',
        icon: PhosphorIconsFill.car,
        iconColor: AppColors.primary700,
        gradient: const [AppColors.primary100, AppColors.primary50],
        onTap: onTap,
      );

  /// Secondary "Xe ghép" hero — cyan tint, savings emphasis.
  factory WgServiceCard.bookShared({required VoidCallback onTap}) =>
      WgServiceCard(
        title: 'Xe ghép',
        subtitle: 'Tiết kiệm 38%',
        icon: PhosphorIconsFill.usersThree,
        iconColor: AppColors.sharedAccent,
        gradient: const [Color(0xFFCFFAFE), Color(0xFFECFEFF)],
        onTap: onTap,
      );

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: AppRadius.heroCard,
        child: Container(
          height: 100,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.heroCard,
            boxShadow: AppShadows.xs,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -4,
                bottom: -6,
                child: Icon(
                  icon,
                  size: 60,
                  color: iconColor.withValues(alpha: 0.85),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.h3.copyWith(
                      color: iconColor,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: iconColor.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
