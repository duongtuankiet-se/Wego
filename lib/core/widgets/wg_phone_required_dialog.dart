import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'wg_button.dart';

/// Phase 5P: returns `true` if the user has a phone on file and the
/// caller is free to proceed with the action (e.g. booking a ride).
/// Otherwise pops a soft alert dialog explaining why the phone is
/// required, with a "Thêm ngay" CTA that navigates to
/// `/complete-profile`. The action is short-circuited in both cases —
/// the user comes back to the original screen on their own time.
Future<bool> ensurePhoneOrPrompt(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authStateProvider).valueOrNull;
  final hasPhone = user?.phone != null && user!.phone!.trim().isNotEmpty;
  if (hasPhone) return true;

  final addNow = await showDialog<bool>(
    context: context,
    builder: (dctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(
            PhosphorIconsFill.phone,
            color: AppColors.primary500,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            'Cần số điện thoại',
            style: AppTypography.h3.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
      content: Text(
        'Bạn chưa có số điện thoại. Vui lòng thêm để tài xế có thể '
        'liên hệ khi đặt chuyến.',
        style: AppTypography.body.copyWith(color: AppColors.ink700),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dctx, false),
          child: Text(
            'Để sau',
            style: AppTypography.body.copyWith(color: AppColors.ink500),
          ),
        ),
        WgButton.primary(
          label: 'Thêm ngay',
          size: WgButtonSize.md,
          onPressed: () => Navigator.pop(dctx, true),
        ),
      ],
    ),
  );

  if (addNow == true && context.mounted) {
    context.push('/complete-profile');
  }
  return false;
}
