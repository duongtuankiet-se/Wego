import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/wg_button.dart';
import '../../../models/driver_vehicle.dart';
import '../../../providers/driver_provider.dart';
import '../../../providers/driver_vehicles_provider.dart';

/// Bottom sheet that lets the driver pick which of their vehicles to
/// use for an accepted pool. Filters by [seats] so only matching cars
/// are shown — if none match, surfaces an empty state CTA pointing the
/// driver at the Vehicles screen.
class SelectVehicleSheet extends ConsumerStatefulWidget {
  const SelectVehicleSheet({super.key, required this.seats});
  final int seats;

  static Future<DriverVehicle?> show(
    BuildContext context, {
    required int seats,
  }) {
    return showModalBottomSheet<DriverVehicle>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SelectVehicleSheet(seats: seats),
    );
  }

  @override
  ConsumerState<SelectVehicleSheet> createState() => _SelectVehicleSheetState();
}

class _SelectVehicleSheetState extends ConsumerState<SelectVehicleSheet> {
  Future<List<DriverVehicle>> _load() async {
    final driver = await ref.read(currentDriverProvider.future);
    if (driver == null) return const [];
    return ref
        .read(driverVehicleServiceProvider)
        .getVehiclesBySeats(driverId: driver.id, seats: widget.seats);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: FutureBuilder<List<DriverVehicle>>(
        future: _load(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final list = snap.data ?? const <DriverVehicle>[];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ink300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Chọn xe sử dụng',
                style: AppTypography.h2.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Pool cần xe ${widget.seats} chỗ',
                style: AppTypography.caption.copyWith(
                  color: AppColors.ink500,
                ),
              ),
              const SizedBox(height: 18),
              if (list.isEmpty)
                _Empty(seats: widget.seats)
              else
                ...list.map(
                  (v) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _VehicleTile(
                      vehicle: v,
                      onTap: () => Navigator.pop(context, v),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.seats});
  final int seats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          PhosphorIconsFill.carProfile,
          size: 56,
          color: AppColors.ink300,
        ),
        const SizedBox(height: 10),
        Text(
          'Bạn chưa có xe $seats chỗ',
          style: AppTypography.body.copyWith(
            color: AppColors.ink700,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Thêm xe để có thể nhận pool này',
          style: AppTypography.caption.copyWith(color: AppColors.ink500),
        ),
        const SizedBox(height: 16),
        WgButton.primary(
          label: 'Thêm xe ngay',
          leadingIcon: PhosphorIconsBold.plus,
          size: WgButtonSize.lg,
          isFullWidth: true,
          onPressed: () {
            Navigator.pop(context);
            context.push('/driver/vehicles');
          },
        ),
      ],
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({required this.vehicle, required this.onTap});
  final DriverVehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.ink50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: vehicle.isPrimary
                ? AppColors.primary300
                : AppColors.ink200,
            width: vehicle.isPrimary ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              PhosphorIconsFill.car,
              size: 26,
              color: AppColors.primary500,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vehicle.displayName,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink900,
                    ),
                  ),
                  Text(
                    vehicle.vehiclePlate,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                      color: AppColors.ink600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              PhosphorIconsRegular.caretRight,
              size: 16,
              color: AppColors.ink400,
            ),
          ],
        ),
      ),
    );
  }
}
