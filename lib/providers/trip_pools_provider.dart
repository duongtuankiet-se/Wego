import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/trip_pool.dart';
import '../services/trip_pool_service.dart';
import 'driver_vehicles_provider.dart';
import 'mongo_provider.dart';
import 'scheduled_trips_provider.dart';

part 'trip_pools_provider.g.dart';

@Riverpod(keepAlive: true)
TripPoolService tripPoolService(Ref ref) =>
    TripPoolService(ref.watch(mongoServiceProvider));

/// Polls a single pool every 5 seconds so the customer's tracking
/// card stays in sync with the threshold/driver-assigned state without
/// needing a Mongo change stream.
@riverpod
Stream<TripPool?> tripPoolDetail(Ref ref, String poolId) async* {
  final svc = ref.watch(tripPoolServiceProvider);
  yield await svc.getById(poolId);
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 5))) {
    yield await svc.getById(poolId);
  }
}

/// Confirmed pools the current driver can accept right now (filtered
/// by their primary vehicle's seat count).
@riverpod
Future<List<TripPool>> driverAvailablePools(Ref ref) async {
  final primary = await ref.watch(driverPrimaryVehicleProvider.future);
  if (primary == null) return const [];
  return ref
      .watch(tripPoolServiceProvider)
      .getDriverAvailablePools(vehicleSeats: primary.vehicleSeats);
}

/// Pools still gathering passengers — driver can watch but not accept
/// until they hit the threshold.
@riverpod
Future<List<TripPool>> driverCollectingPools(Ref ref) async {
  final primary = await ref.watch(driverPrimaryVehicleProvider.future);
  if (primary == null) return const [];
  return ref
      .watch(tripPoolServiceProvider)
      .getDriverCollectingPools(vehicleSeats: primary.vehicleSeats);
}

/// Background sweeper that flips `collecting` pools past their cancel
/// deadline to `cancelled_no_pool`. Runs every 60s while the app is
/// open — production needs a server-side cron, but this keeps the
/// demo honest for users who leave the app foregrounded.
@Riverpod(keepAlive: true)
class PoolAutoCancelJob extends _$PoolAutoCancelJob {
  Timer? _timer;

  @override
  void build() {
    _timer = Timer.periodic(const Duration(seconds: 60), (_) async {
      try {
        final n = await ref.read(tripPoolServiceProvider).autoCancelExpiredPools();
        if (n > 0) {
          developer.log('[pool-job] cancelled $n pools', name: 'pool');
          ref.invalidate(upcomingScheduledTripsProvider);
          ref.invalidate(driverAvailablePoolsProvider);
          ref.invalidate(driverCollectingPoolsProvider);
        }
      } catch (e) {
        developer.log('[pool-job] sweep failed: $e', name: 'pool');
      }
    });
    ref.onDispose(() => _timer?.cancel());
  }
}
