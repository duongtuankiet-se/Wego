import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/route.dart';
import '../../../providers/routes_provider.dart';

/// Bottom sheet route picker for the "Chọn tuyến có sẵn" mode. Pops
/// the chosen [RoutePreset] back to the caller; null on dismiss.
class RoutePickerSheet extends ConsumerWidget {
  const RoutePickerSheet({super.key});

  static Future<RoutePreset?> show(BuildContext context) {
    return showModalBottomSheet<RoutePreset>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const RoutePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(activeRoutesProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.ink300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Text(
                  'Chọn tuyến đường',
                  style: AppTypography.h2.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text(
              'Giá cố định theo tuyến · Miền Trung',
              style: AppTypography.caption.copyWith(color: AppColors.ink500),
            ),
          ),
          Expanded(
            child: routesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không tải được tuyến: $e',
                  style: AppTypography.body.copyWith(color: AppColors.danger),
                ),
              ),
              data: (routes) {
                if (routes.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Chưa có tuyến nào',
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink500,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  itemCount: routes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _RouteTile(route: routes[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({required this.route});
  final RoutePreset route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context, route),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.ink100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    route.name,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (route.isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'HOT',
                      style: AppTypography.micro.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.path,
                  size: 14,
                  color: AppColors.ink500,
                ),
                const SizedBox(width: 4),
                Text(
                  '${route.distanceKm}km',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink600,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  PhosphorIconsRegular.clock,
                  size: 14,
                  color: AppColors.ink500,
                ),
                const SizedBox(width: 4),
                Text(
                  '${route.durationMin} phút',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    route.fareLabel,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
