import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';

/// Floating crosshair button for "snap the map back to a meaningful
/// view" — fitting the polyline bounds on Ride Options, centering on
/// the car on Live Trip, toggling auto-follow on Driver Navigation.
///
/// 48×48 white circle, soft [AppShadows.md], primary-tinted icon.
/// Light haptic on tap so the screen feels reactive even when the
/// camera animation takes a beat to start.
class WgRecenterFab extends StatelessWidget {
  const WgRecenterFab({
    super.key,
    required this.onTap,
    this.icon,
    this.iconColor,
  });

  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppShadows.md,
      ),
      child: ClipOval(
        child: Material(
          color: AppColors.white,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                icon ?? PhosphorIconsFill.crosshair,
                color: iconColor ?? AppColors.primary500,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
