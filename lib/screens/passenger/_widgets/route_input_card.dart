import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Pickup (readonly) + dropoff (editable) inputs stacked vertically with
/// a left-side dot→line→square connector. Inputs use a filled subtle
/// ink50 background — no outline / focus ring, matching Xanh SM style.
class RouteInputCard extends StatelessWidget {
  const RouteInputCard({
    super.key,
    required this.pickupLabel,
    required this.dropoffController,
    required this.onDropoffChanged,
    this.onPickupTap,
    this.onDropoffSubmitted,
    this.autofocusDropoff = true,
  });

  final String pickupLabel;
  final TextEditingController dropoffController;
  final ValueChanged<String> onDropoffChanged;
  final VoidCallback? onPickupTap;
  final ValueChanged<String>? onDropoffSubmitted;
  final bool autofocusDropoff;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(width: 2, height: 28, color: AppColors.ink200),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PickupField(label: pickupLabel, onTap: onPickupTap),
                const SizedBox(height: 8),
                _DropoffField(
                  controller: dropoffController,
                  autofocus: autofocusDropoff,
                  onChanged: onDropoffChanged,
                  onSubmitted: onDropoffSubmitted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupField extends StatelessWidget {
  const _PickupField({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.ink50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              PhosphorIconsRegular.pencilSimple,
              size: 16,
              color: AppColors.ink500,
            ),
          ],
        ),
      ),
    );
  }
}

class _DropoffField extends StatelessWidget {
  const _DropoffField({
    required this.controller,
    required this.autofocus,
    required this.onChanged,
    required this.onSubmitted,
  });
  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.ink50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        // VN IME hardening (Phase 5L): Samsung/Xiaomi keyboards + Telex
        // drop the last character when any of autocorrect / suggestions /
        // smart-quotes try to mutate the composing region mid-diacritic.
        // Turn them all off and rely on debounce to read the field.
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        keyboardType: TextInputType.text,
        cursorColor: AppColors.primary500,
        style: AppTypography.body.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.ink900,
        ),
        decoration: InputDecoration(
          hintText: 'Bạn muốn đến đâu?',
          hintStyle: AppTypography.body.copyWith(
            color: AppColors.ink400,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          isDense: true,
        ),
      ),
    );
  }
}
