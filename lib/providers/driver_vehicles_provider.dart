import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/driver_vehicle.dart';
import '../services/driver_vehicle_service.dart';
import 'driver_provider.dart';
import 'mongo_provider.dart';

part 'driver_vehicles_provider.g.dart';

@Riverpod(keepAlive: true)
DriverVehicleService driverVehicleService(Ref ref) =>
    DriverVehicleService(ref.watch(mongoServiceProvider));

/// All active vehicles for the currently logged-in driver. Auto-seeds
/// one from the legacy Driver.vehicle* inline fields the first time
/// the list comes back empty so existing accounts can accept pools
/// without having to manually re-enter their car.
@riverpod
Future<List<DriverVehicle>> driverVehiclesList(Ref ref) async {
  final driver = await ref.watch(currentDriverProvider.future);
  if (driver == null) return const [];
  final svc = ref.watch(driverVehicleServiceProvider);
  final list = await svc.getDriverVehicles(driver.id);
  if (list.isNotEmpty) return list;
  await svc.seedFromLegacyDriverIfEmpty(driver);
  return svc.getDriverVehicles(driver.id);
}

@riverpod
Future<DriverVehicle?> driverPrimaryVehicle(Ref ref) async {
  // Reuse the auto-seeding list so primary is always populated for
  // legacy drivers on first access.
  final list = await ref.watch(driverVehiclesListProvider.future);
  if (list.isEmpty) return null;
  return list.firstWhere(
    (v) => v.isPrimary,
    orElse: () => list.first,
  );
}
