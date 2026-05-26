import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'wg_button.dart';

class WgErrorState extends StatelessWidget {
  const WgErrorState({
    super.key,
    this.title = 'Đã xảy ra lỗi',
    this.message,
    this.onRetry,
    this.retryLabel = 'Thử lại',
    this.icon = PhosphorIconsRegular.warningCircle,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

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
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.ink500),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              WgButton.secondary(
                label: retryLabel,
                leadingIcon: PhosphorIconsRegular.arrowsClockwise,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
