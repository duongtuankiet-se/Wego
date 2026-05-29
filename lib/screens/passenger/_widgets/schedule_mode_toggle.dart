import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/scheduled_trip.dart';
import '../../../providers/scheduled_trips_provider.dart';

/// Phase 5Q: header pill toggle for the Schedule form. Flipping it
/// goes through `ScheduleRideForm.setMode` which resets pickup/dropoff
/// + fare, so the two modes can't leak data into each other.
class ScheduleModeToggle extends ConsumerWidget {
  const ScheduleModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      scheduleRideFormProvider.select((s) => s.mode),
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.ink100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Option(
              icon: PhosphorIconsFill.mapPin,
              label: 'Tự chọn điểm',
              selected: mode == ScheduleMode.freePoint,
              onTap: () => ref
                  .read(scheduleRideFormProvider.notifier)
                  .setMode(ScheduleMode.freePoint),
            ),
          ),
          Expanded(
            child: _Option(
              icon: PhosphorIconsFill.path,
              label: 'Chọn tuyến có sẵn',
              selected: mode == ScheduleMode.fixedRoute,
              onTap: () => ref
                  .read(scheduleRideFormProvider.notifier)
                  .setMode(ScheduleMode.fixedRoute),
            ),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? AppShadows.xs : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.primary500 : AppColors.ink500,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: selected ? AppColors.ink900 : AppColors.ink600,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
