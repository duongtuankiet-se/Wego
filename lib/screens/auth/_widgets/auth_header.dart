import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Shared headline + subtitle block used at the top of the 3 auth
/// screens (Register / Login / VerifyOtp). Keeps spacing consistent.
class WgAuthHeader extends StatelessWidget {
  const WgAuthHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final Widget subtitle;

  /// Convenience constructor when the subtitle is plain text.
  factory WgAuthHeader.text({
    Key? key,
    required String title,
    required String subtitle,
  }) {
    return WgAuthHeader(
      key: key,
      title: title,
      subtitle: Text(
        subtitle,
        style: AppTypography.body.copyWith(color: AppColors.ink500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          title,
          style: AppTypography.h1.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        subtitle,
      ],
    );
  }
}
