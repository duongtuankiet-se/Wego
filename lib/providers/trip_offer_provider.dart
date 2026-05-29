import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/user.dart';
import '../services/trip_offer_service.dart';
import 'auth_provider.dart';
import 'driver_provider.dart';
import 'driver_status_provider.dart';
import 'mongo_provider.dart';
import 'scheduled_trips_provider.dart';

part 'trip_offer_provider.g.dart';

@Riverpod(keepAlive: true)
TripOfferService tripOfferService(Ref ref) =>
    TripOfferService(ref.watch(mongoServiceProvider));

/// Polls the current driver's outstanding offer every 5 seconds. Yields
/// [CurrentOffer.empty] when the driver isn't online or there's no
/// offer in flight, so the listening UI can clear any stale popup state.
@riverpod
Stream<CurrentOffer> driverCurrentOffer(Ref ref) async* {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || user.role != UserRole.driver) {
    yield CurrentOffer.empty;
    return;
  }

  // Driver doc id (NOT user id) — TripOfferService stores
  // current_offer_trip_id on the drivers collection.
  final driver = await ref.watch(currentDriverProvider.future);
  if (driver == null) {
    yield CurrentOffer.empty;
    return;
  }

  // Stop polling when the driver flips offline — saves a query every
  // 5s while they're not even available to accept.
  final statusAsync = ref.watch(currentDriverStatusProvider);
  final isOnline = statusAsync.valueOrNull?.name == 'online';
  if (!isOnline) {
    yield CurrentOffer.empty;
    return;
  }

  final service = ref.watch(tripOfferServiceProvider);
  yield await service.getCurrentOfferForDriver(driver.id);

  await for (final _ in Stream<void>.periodic(const Duration(seconds: 5))) {
    yield await service.getCurrentOfferForDriver(driver.id);
  }
}

/// Background sweep: every 10s the search loop offers pending trips to
/// the next eligible driver, and any trip past its search_timeout_at is
/// flipped to `no_driver_found`. Mirrors the [PoolAutoCancelJob] pattern
/// — keepAlive so it survives across screen navigation.
@Riverpod(keepAlive: true)
class TripSearchJob extends _$TripSearchJob {
  Timer? _timer;

  @override
  void build() {
    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final svc = ref.read(tripOfferServiceProvider);
        // Phase 5R hotfix: sweep expired offers FIRST so the next
        // step sees those trips back in `pending` and can re-offer
        // them. Without this, a trip whose driver never answered
        // stays stuck at `offered` until the driver polls again.
        final stale = await svc.expireStaleOffers();
        final offered = await svc.processSearchingTrips();
        final expired = await svc.autoCancelExpiredSearches();
        if (offered > 0 || expired > 0 || stale > 0) {
          // Force the customer-side polling providers to refresh so
          // the status banner updates without waiting for its own tick.
          ref.invalidate(upcomingScheduledTripsProvider);
        }
      } catch (e, st) {
        developer.log(
          '[search-job] sweep failed: $e',
          name: 'offer',
          error: e,
          stackTrace: st,
        );
      }
    });
    ref.onDispose(() => _timer?.cancel());
  }
}
