import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'wg_button.dart';

class WgEmptyState extends StatelessWidget {
  const WgEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = PhosphorIconsRegular.tray,
    this.ctaLabel,
    this.onCta,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.ink300, size: 64),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.ink900,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.ink500),
              ),
            ],
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 20),
              WgButton.primary(label: ctaLabel!, onPressed: onCta),
            ],
          ],
        ),
      ),
    );
  }
}
