import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

enum WgButtonVariant { primary, secondary, ghost }

enum WgButtonSize { sm, md, lg }

class WgButton extends StatelessWidget {
  const WgButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = WgButtonVariant.primary,
    this.size = WgButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  const WgButton.primary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    WgButtonSize size = WgButtonSize.md,
    IconData? leadingIcon,
    IconData? trailingIcon,
    bool isLoading = false,
    bool isFullWidth = false,
  }) : this(
         key: key,
         label: label,
         onPressed: onPressed,
         variant: WgButtonVariant.primary,
         size: size,
         leadingIcon: leadingIcon,
         trailingIcon: trailingIcon,
         isLoading: isLoading,
         isFullWidth: isFullWidth,
       );

  const WgButton.secondary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    WgButtonSize size = WgButtonSize.md,
    IconData? leadingIcon,
    IconData? trailingIcon,
    bool isLoading = false,
    bool isFullWidth = false,
  }) : this(
         key: key,
         label: label,
         onPressed: onPressed,
         variant: WgButtonVariant.secondary,
         size: size,
         leadingIcon: leadingIcon,
         trailingIcon: trailingIcon,
         isLoading: isLoading,
         isFullWidth: isFullWidth,
       );

  const WgButton.ghost({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    WgButtonSize size = WgButtonSize.md,
    IconData? leadingIcon,
    IconData? trailingIcon,
    bool isLoading = false,
    bool isFullWidth = false,
  }) : this(
         key: key,
         label: label,
         onPressed: onPressed,
         variant: WgButtonVariant.ghost,
         size: size,
         leadingIcon: leadingIcon,
         trailingIcon: trailingIcon,
         isLoading: isLoading,
         isFullWidth: isFullWidth,
       );

  final String label;
  final VoidCallback? onPressed;
  final WgButtonVariant variant;
  final WgButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;

  double get _height => switch (size) {
    WgButtonSize.sm => 40,
    WgButtonSize.md => 48,
    WgButtonSize.lg => 56,
  };

  double get _fontSize => switch (size) {
    WgButtonSize.sm => 14,
    WgButtonSize.md => 15,
    WgButtonSize.lg => 17,
  };

  EdgeInsets get _padding => switch (size) {
    WgButtonSize.sm => const EdgeInsets.symmetric(horizontal: 14),
    WgButtonSize.md => const EdgeInsets.symmetric(horizontal: 18),
    WgButtonSize.lg => const EdgeInsets.symmetric(horizontal: 22),
  };

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;

    final ({Color bg, Color fg, BorderSide border}) style = switch (variant) {
      WgButtonVariant.primary => (
        bg: AppColors.primary500,
        fg: AppColors.white,
        border: BorderSide.none,
      ),
      WgButtonVariant.secondary => (
        bg: AppColors.primary50,
        fg: AppColors.primary700,
        border: BorderSide.none,
      ),
      WgButtonVariant.ghost => (
        bg: Colors.transparent,
        fg: AppColors.primary500,
        border: const BorderSide(color: AppColors.ink300, width: 1),
      ),
    };

    final child = SizedBox(
      height: _height,
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Material(
          color: style.bg,
          shape: RoundedRectangleBorder(
            side: style.border,
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: disabled
                ? null
                : () {
                    if (variant == WgButtonVariant.primary) {
                      HapticFeedback.lightImpact();
                    }
                    onPressed?.call();
                  },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: _padding,
              child: Row(
                mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: _fontSize + 2,
                      height: _fontSize + 2,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(style.fg),
                      ),
                    )
                  else ...[
                    if (leadingIcon != null) ...[
                      Icon(leadingIcon, size: _fontSize + 4, color: style.fg),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: style.fg,
                        fontSize: _fontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 8),
                      Icon(trailingIcon, size: _fontSize + 4, color: style.fg),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (isFullWidth) return SizedBox(width: double.infinity, child: child);
    return child;
  }
}
