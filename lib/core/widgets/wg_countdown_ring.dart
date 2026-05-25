import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Circular countdown indicator. Displays remaining seconds and animates
/// a stroke around the perimeter as time runs out.
class WgCountdownRing extends StatelessWidget {
  const WgCountdownRing({
    super.key,
    required this.secondsLeft,
    required this.totalSeconds,
    this.size = 40,
    this.color = AppColors.primary500,
    this.bgColor = AppColors.ink100,
  });

  final int secondsLeft;
  final int totalSeconds;
  final double size;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds == 0
        ? 0.0
        : (1.0 - secondsLeft / totalSeconds).clamp(0.0, 1.0);
    final urgent = secondsLeft <= 5;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: progress, end: progress),
              duration: const Duration(milliseconds: 250),
              builder: (_, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 3,
                backgroundColor: bgColor,
                valueColor: AlwaysStoppedAnimation(
                  urgent ? AppColors.danger : color,
                ),
              ),
            ),
          ),
          Text(
            '$secondsLeft',
            style: AppTypography.body.copyWith(
              color: urgent ? AppColors.danger : color,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
