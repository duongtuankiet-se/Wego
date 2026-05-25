import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/wg_avatar.dart';
import '../../../core/widgets/wg_badge.dart';
import '../../../core/widgets/wg_toast.dart';
import '../../../models/trip.dart';
import '../../../providers/current_trip_provider.dart';

class DriverInfoCard extends StatelessWidget {
  const DriverInfoCard({
    super.key,
    required this.driver,
    required this.tripType,
  });

  final ActiveDriver driver;
  final TripType tripType;

  void _call(BuildContext context) {
    HapticFeedback.mediumImpact();
    WgToast.info(context, 'Đang kết nối với ${driver.name}...');
  }

  void _chat(BuildContext context) {
    HapticFeedback.lightImpact();
    WgToast.info(context, 'Chat sẽ có ở phiên bản sau');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              WgAvatar(name: driver.name, size: 52, rating: driver.rating),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.ink900,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.warning,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${driver.rating.toStringAsFixed(2)} · ${driver.totalTrips} chuyến',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.ink500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _IconButton(
                icon: Icons.chat_bubble_outline,
                bg: AppColors.ink100,
                fg: AppColors.ink700,
                onTap: () => _chat(context),
              ),
              const SizedBox(width: 8),
              _IconButton(
                icon: Icons.phone,
                bg: AppColors.primary500,
                fg: Colors.white,
                onTap: () => _call(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.ink100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${driver.vehicleModel} · ${driver.vehicleColor}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.ink500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        driver.vehiclePlate,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.ink900,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                WgBadge(
                  label: tripType == TripType.shared ? 'XE GHÉP' : 'XE RIÊNG',
                  variant: tripType == TripType.shared
                      ? WgBadgeVariant.shared
                      : WgBadgeVariant.info,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: fg, size: 20),
        ),
      ),
    );
  }
}
