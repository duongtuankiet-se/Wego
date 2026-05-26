import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_typography.dart';

/// Hero service banner — used in the passenger home for "Đặt xe" /
/// "Đặt đồ ăn" entry tiles. Subtle gradient background with a large
/// corner emoji acting as faux-3D illustration.
class WgServiceCard extends StatelessWidget {
  const WgServiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.gradient,
    required this.onTap,
  });

  /// Shortcut for the primary "Đặt xe" tile.
  factory WgServiceCard.bookRide({required VoidCallback onTap}) =>
      WgServiceCard(
        title: 'Đặt xe',
        subtitle: 'Đi đâu cũng được',
        emoji: '🚗',
        gradient: const [AppColors.primary100, AppColors.primary50],
        onTap: onTap,
      );

  /// Shortcut for the food-delivery teaser tile (mocked).
  factory WgServiceCard.bookFood({required VoidCallback onTap}) =>
      WgServiceCard(
        title: 'Đặt đồ ăn',
        subtitle: 'Giao siêu tốc',
        emoji: '🍜',
        gradient: const [Color(0xFFFEF3C7), Color(0xFFFEFBEA)],
        onTap: onTap,
      );

  final String title;
  final String subtitle;
  final String emoji;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glow = AppShadows.heroGlow(gradient.first);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: AppRadius.heroCard,
        child: Container(
          height: 116,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.heroCard,
            boxShadow: glow,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -6,
                bottom: -10,
                child: Text(emoji, style: const TextStyle(fontSize: 76)),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.ink900,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
