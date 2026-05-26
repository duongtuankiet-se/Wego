import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connector column (origin dot → line → destination square)
          Padding(
            padding: const EdgeInsets.only(top: 18),
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
                Container(width: 1.5, height: 36, color: AppColors.ink300),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pickup row (readonly)
                InkWell(
                  onTap: onPickupTap,
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            pickupLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body.copyWith(
                              color: AppColors.ink900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          PhosphorIconsRegular.pencilSimple,
                          color: AppColors.ink500,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.ink100),
                // Dropoff input (editable)
                SizedBox(
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: dropoffController,
                      autofocus: autofocusDropoff,
                      onChanged: onDropoffChanged,
                      onSubmitted: onDropoffSubmitted,
                      textInputAction: TextInputAction.search,
                      cursorColor: AppColors.primary500,
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink900,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration.collapsed(
                        hintText: 'Nhập điểm đến...',
                        hintStyle: AppTypography.body.copyWith(
                          color: AppColors.ink500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
