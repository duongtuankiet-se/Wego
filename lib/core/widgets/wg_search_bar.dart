import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_typography.dart';

/// Xanh SM-style pill search bar. Tap surface only — actual input lives
/// elsewhere (search screen). 56px tall with soft shadow xs.
class WgSearchBar extends StatelessWidget {
  const WgSearchBar({
    super.key,
    required this.onTap,
    this.hint = 'Bạn muốn đi đâu?',
  });

  final VoidCallback onTap;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: AppRadius.search,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppRadius.search,
            boxShadow: AppShadows.xs,
          ),
          child: Row(
            children: [
              Icon(
                PhosphorIconsRegular.magnifyingGlass,
                color: AppColors.ink400,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hint,
                  style: AppTypography.body.copyWith(color: AppColors.ink400),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                PhosphorIconsRegular.microphone,
                color: AppColors.ink400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
