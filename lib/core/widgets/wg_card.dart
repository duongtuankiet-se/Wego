import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class WgCard extends StatelessWidget {
  const WgCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppSpacing.cardPadding,
    this.elevated = false,
    this.backgroundColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool elevated;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: backgroundColor ?? AppColors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: elevated ? 6 : 0,
      shadowColor: elevated ? Colors.black.withValues(alpha: 0.08) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(padding: padding, child: child),
      ),
    );
    return card;
  }
}
