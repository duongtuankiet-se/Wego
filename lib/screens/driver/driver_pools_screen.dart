import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/wg_toast.dart';
import '../../models/trip_pool.dart';
import '../../providers/driver_provider.dart';
import '../../providers/driver_vehicles_provider.dart';
import '../../providers/trip_pools_provider.dart';
import '_widgets/pool_card.dart';
import '_widgets/select_vehicle_sheet.dart';

class DriverPoolsScreen extends ConsumerWidget {
  const DriverPoolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryAsync = ref.watch(driverPrimaryVehicleProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        appBar: AppBar(
          backgroundColor: AppColors.offWhite,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Pool xe ghép',
            style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700),
          ),
          bottom: const TabBar(
            indicatorColor: AppColors.primary500,
            indicatorWeight: 3,
            labelColor: AppColors.primary600,
            unselectedLabelColor: AppColors.ink500,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Sẵn sàng nhận'),
              Tab(text: 'Đang gom'),
            ],
          ),
        ),
        body: primaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Lỗi: $e',
              style: AppTypography.body.copyWith(color: AppColors.ink700),
            ),
          ),
          data: (primary) {
            if (primary == null) {
              return _NoVehicleHint();
            }
            return TabBarView(
              children: [
                _AvailableTab(seats: primary.vehicleSeats),
                _CollectingTab(seats: primary.vehicleSeats),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NoVehicleHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              PhosphorIconsFill.car,
              size: 64,
              color: AppColors.ink300,
            ),
            const SizedBox(height: 14),
            Text(
              'Chưa có xe nào',
              style: AppTypography.h3.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Thêm xe để bắt đầu nhận pool xe ghép.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.ink600),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => context.push('/driver/vehicles'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(PhosphorIconsBold.plus),
              label: const Text('Thêm xe'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailableTab extends ConsumerWidget {
  const _AvailableTab({required this.seats});
  final int seats;

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    TripPool pool,
  ) async {
    final driver = await ref.read(currentDriverProvider.future);
    if (driver == null || !context.mounted) return;
    final vehicle = await SelectVehicleSheet.show(
      context,
      seats: pool.vehicleSeats,
    );
    if (vehicle == null || !context.mounted) return;
    final ok = await ref
        .read(tripPoolServiceProvider)
        .driverAcceptPool(
          poolId: pool.id,
          driverId: driver.id,
          vehicle: vehicle,
        );
    if (!context.mounted) return;
    if (ok) {
      WgToast.success(context, 'Đã nhận pool ${pool.poolCode}');
      ref.invalidate(driverAvailablePoolsProvider);
    } else {
      WgToast.error(context, 'Pool đã được tài xế khác nhận');
      ref.invalidate(driverAvailablePoolsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolsAsync = ref.watch(driverAvailablePoolsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(driverAvailablePoolsProvider);
        await ref.read(driverAvailablePoolsProvider.future);
      },
      child: poolsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Lỗi: $e',
                style: AppTypography.body.copyWith(color: AppColors.ink700),
              ),
            ),
          ],
        ),
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(32),
              children: [
                Column(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.usersThree,
                      size: 56,
                      color: AppColors.ink300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chưa có pool $seats chỗ nào sẵn sàng',
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink600,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => PoolCard(
              pool: list[i],
              onAccept: () => _accept(context, ref, list[i]),
            ),
          );
        },
      ),
    );
  }
}

class _CollectingTab extends ConsumerWidget {
  const _CollectingTab({required this.seats});
  final int seats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolsAsync = ref.watch(driverCollectingPoolsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(driverCollectingPoolsProvider);
        await ref.read(driverCollectingPoolsProvider.future);
      },
      child: poolsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Lỗi: $e',
                style: AppTypography.body.copyWith(color: AppColors.ink700),
              ),
            ),
          ],
        ),
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(32),
              children: [
                Column(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.eye,
                      size: 56,
                      color: AppColors.ink300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chưa có pool $seats chỗ nào đang gom',
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hệ thống sẽ tự thông báo khi pool đủ khách.',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink400,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => PoolCard(pool: list[i]),
          );
        },
      ),
    );
  }
}
