import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// iOS-style switch for the driver online/offline status. Wide enough
/// to host a label between the knob and the edge.
class WgStatusToggle extends StatelessWidget {
  const WgStatusToggle({
    super.key,
    required this.online,
    required this.onToggle,
    this.disabled = false,
  });

  final bool online;
  final ValueChanged<bool> onToggle;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final bg = online
        ? AppColors.success.withValues(alpha: 0.15)
        : AppColors.ink100;
    final label = online ? 'Đang nhận chuyến' : 'Tạm nghỉ';
    final labelColor = online ? AppColors.success : AppColors.ink700;

    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: disabled
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onToggle(!online);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          height: 56,
          padding: const EdgeInsets.fromLTRB(6, 6, 18, 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: (online ? AppColors.success : AppColors.ink900)
                    .withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                alignment: online
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: online ? AppColors.success : AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink900.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    online ? Icons.power_settings_new : Icons.power_off,
                    color: online ? AppColors.white : AppColors.ink500,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (c, a) =>
                    FadeTransition(opacity: a, child: c),
                child: Text(
                  label,
                  key: ValueKey(label),
                  style: AppTypography.body.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
