import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/driver.dart';
import 'driver_provider.dart';
import 'driver_service_provider.dart';

part 'driver_status_provider.g.dart';

/// Runtime dispatch status. Initialized from the Driver doc; mutations
/// write through to Mongo via [DriverService.setStatus].
@Riverpod(keepAlive: true)
class CurrentDriverStatus extends _$CurrentDriverStatus {
  @override
  Future<DriverStatus> build() async {
    final driver = await ref.watch(currentDriverProvider.future);
    return driver?.status ?? DriverStatus.offline;
  }

  Future<void> toggle({double? lat, double? lng}) async {
    final current = state.valueOrNull ?? DriverStatus.offline;
    final next = current == DriverStatus.online
        ? DriverStatus.offline
        : DriverStatus.online;
    await setStatus(next, lat: lat, lng: lng);
  }

  Future<void> setStatus(DriverStatus next, {double? lat, double? lng}) async {
    state = AsyncData(next);
    try {
      final driver = await ref.read(currentDriverProvider.future);
      if (driver == null) return;
      await ref
          .read(driverServiceProvider)
          .setStatus(driverId: driver.id, status: next, lat: lat, lng: lng);
      ref.invalidate(currentDriverProvider);
    } catch (e) {
      // Rollback UI state on failure.
      state = AsyncData(state.valueOrNull ?? DriverStatus.offline);
      rethrow;
    }
  }
}
