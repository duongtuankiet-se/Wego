import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/turn_instructions.dart';

class NavigationInstructionCard extends StatelessWidget {
  const NavigationInstructionCard({super.key, required this.instruction});
  final TurnInstruction instruction;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: (child, anim) {
        final slide = Tween<Offset>(
          begin: const Offset(0, -0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: Container(
        key: ValueKey(
          '${instruction.streetName}-${instruction.distanceMeters}',
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink900.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    instruction.icon,
                    color: AppColors.primary500,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        instruction.action,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.ink500,
                        ),
                      ),
                      Text(
                        instruction.streetName,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.ink900,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatDistance(instruction.distanceMeters),
                              style: AppTypography.micro.copyWith(
                                color: AppColors.primary500,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'tới ngã rẽ',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.ink500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (instruction.nextHint != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.ink100),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.arrowRight,
                    color: AppColors.ink500,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sau đó: ${instruction.nextHint}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDistance(int meters) {
    if (meters < 1000) return '$meters m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
