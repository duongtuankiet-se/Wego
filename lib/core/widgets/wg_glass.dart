import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';

/// iOS 26-style frosted-glass container. Wrap any widget to give it a
/// blurred translucent backdrop with soft border + drop shadow.
///
/// Always clip-rrected internally so the [BackdropFilter] doesn't bleed
/// outside the rounded shape.
class WgGlass extends StatelessWidget {
  const WgGlass({
    super.key,
    required this.child,
    this.blur = 24,
    this.opacity = 0.75,
    this.borderRadius,
    this.padding,
    this.tint,
    this.border = true,
    this.shadow = true,
  });

  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final bool border;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(20);
    final color = (tint ?? AppColors.white).withValues(alpha: opacity);

    Widget content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            borderRadius: radius,
            border: border
                ? Border.all(color: AppColors.glassBorder, width: 0.5)
                : null,
          ),
          child: child,
        ),
      ),
    );

    if (shadow) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: AppShadows.md,
        ),
        child: content,
      );
    }
    return content;
  }
}
