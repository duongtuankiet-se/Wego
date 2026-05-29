import 'dart:developer' as developer;

import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where, modify;

import '../core/db/mongo_service.dart';
import '../models/scheduled_trip.dart';
import '../models/wallet.dart';

/// Outcome of a polling read for the driver's current offer.
class CurrentOffer {
  final ScheduledTrip? trip;
  final int secondsLeft;
  const CurrentOffer({this.trip, this.secondsLeft = 0});

  static const empty = CurrentOffer();
}

/// Phase 5R hotfix: result of [TripOfferService.acceptOffer]. `success`
/// = the trip was successfully transitioned to driverAssigned; `reason`
/// carries a Vietnamese explanation when not — used by the popup to
/// show why instead of the previous generic "không khả dụng".
typedef AcceptOfferResult = ({bool success, String? reason});

/// Phase 5R driver offer/acceptance engine.
///
/// Scoped to free-point scheduled trips only — fixed-route trips go
/// through [TripPoolService] which has its own (different) acceptance
/// flow. Status transitions enforced via optimistic locks so two
/// drivers tapping the same trip can never both succeed.
class TripOfferService {
  TripOfferService(this._mongo);
  final MongoService _mongo;

  /// How long a driver has to answer an offer before it auto-rejects.
  static const Duration offerWindow = Duration(seconds: 15);

  /// Only fire offers for trips whose pickup is at most this far in the
  /// future. A trip scheduled 3 days out shouldn't pop a 15s decision
  /// dialog right now — wait until it's close to departure.
  static const Duration eagerWindow = Duration(minutes: 60);

  // ─────────────────────────────────────────────────────────────────
  // Driver selection
  // ─────────────────────────────────────────────────────────────────

  /// Pick the next driver to receive an offer for [trip]. Filters:
  ///   * status = online
  ///   * not in `offered_to_drivers` or `rejected_by_drivers`
  ///   * `current_offer_trip_id` is null (not already considering one)
  ///   * wallet passes [Wallet.canAcceptTrips]
  ///
  /// MVP picks the first match (Mongo's natural order). Production
  /// would sort by pickup distance + rating + accept-rate; out of scope
  /// for the demo.
  Future<String?> findNextDriverForTrip(ScheduledTrip trip) async {
    final driversCol = await _mongo.drivers();
    final walletsCol = await _mongo.wallets();

    final excluded = <ObjectId>[
      ...trip.offeredToDrivers.map(ObjectId.fromHexString),
      ...trip.rejectedByDrivers.map(ObjectId.fromHexString),
    ];

    final selector = where.raw(<String, dynamic>{
      'status': 'online',
      if (excluded.isNotEmpty)
        '_id': {r'$nin': excluded},
      'current_offer_trip_id': null,
    });

    final candidates = await driversCol.find(selector).toList();
    if (candidates.isEmpty) return null;

    for (final doc in candidates) {
      final driverId = (doc['_id'] as ObjectId).oid;
      final walletDoc = await walletsCol.findOne(
        where.eq('user_id', doc['user_id']),
      );
      if (walletDoc == null) continue;
      final wallet = Wallet.fromMongo(walletDoc);
      if (wallet.canAcceptTrips) return driverId;
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  // Offer lifecycle
  // ─────────────────────────────────────────────────────────────────

  /// Atomically flip trip pending → offered and stamp the driver row
  /// with the offer expiry. Returns false if the trip moved out of
  /// pending state between selection and write (another search-loop
  /// tick beat us to it, or the customer cancelled).
  Future<bool> offerTripToDriver({
    required String tripId,
    required String driverId,
  }) async {
    final tripsCol = await _mongo.scheduledTrips();
    final driversCol = await _mongo.drivers();
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(offerWindow);
    final tripObjId = ObjectId.fromHexString(tripId);
    final driverObjId = ObjectId.fromHexString(driverId);

    final tripRes = await tripsCol.updateOne(
      where.eq('_id', tripObjId).eq('status', 'pending'),
      modify
          .set('status', ScheduledTripStatus.offered.mongoName)
          // Phase 5R hotfix: stamp the current offer holder + expiry
          // directly on the trip so [acceptOffer] can guard atomically
          // without a second round-trip.
          .set('current_offered_driver_id', driverObjId)
          .set('current_offer_expires_at', expiresAt)
          .push('offered_to_drivers', driverObjId)
          .inc('offer_attempts', 1)
          .set('updated_at', now),
    );
    if (!tripRes.isSuccess || tripRes.nModified == 0) {
      developer.log('[offer] offer skipped: trip $tripId not pending',
          name: 'offer');
      return false;
    }

    await driversCol.updateOne(
      where.eq('_id', driverObjId),
      modify
          .set('current_offer_trip_id', tripObjId)
          .set('current_offer_expires_at', expiresAt)
          .set('updated_at', now),
    );

    developer.log('[offer] offered $tripId → $driverId',
        name: 'offer');
    return true;
  }

  /// Driver tapped "Nhận chuyến". Phase 5R hotfix: atomic where-clause
  /// guards 3 conditions in one query — status=offered, current offer
  /// holder is this driver, expiry hasn't passed. When the update
  /// matches nothing, we re-read the trip and map the actual failure
  /// to one of 5 Vietnamese reasons so the popup can tell the driver
  /// what really happened instead of the previous generic "không
  /// khả dụng" that masked timeouts as race-losses.
  Future<AcceptOfferResult> acceptOffer({
    required String tripId,
    required String driverId,
  }) async {
    final tripsCol = await _mongo.scheduledTrips();
    final driversCol = await _mongo.drivers();
    final now = DateTime.now().toUtc();
    final tripObjId = ObjectId.fromHexString(tripId);
    final driverObjId = ObjectId.fromHexString(driverId);

    final res = await tripsCol.updateOne(
      where
          .eq('_id', tripObjId)
          .eq('status', ScheduledTripStatus.offered.mongoName)
          .eq('current_offered_driver_id', driverObjId)
          .gt('current_offer_expires_at', now),
      modify
          .set('status', ScheduledTripStatus.driverAssigned.mongoName)
          .set('driver_id', driverObjId)
          .set('current_offered_driver_id', null)
          .set('current_offer_expires_at', null)
          .set('updated_at', now),
    );

    // Always clear driver state, whether we won the race or not, so a
    // lost race doesn't leave the driver flagged busy with a phantom
    // offer that the next poll would auto-reject anyway.
    await driversCol.updateOne(
      where.eq('_id', driverObjId),
      modify
          .set('current_offer_trip_id', null)
          .set('current_offer_expires_at', null)
          .set('updated_at', now),
    );

    if (res.isSuccess && res.nModified > 0) {
      developer.log('[offer] ACCEPT $tripId → $driverId', name: 'offer');
      return (success: true, reason: null);
    }

    // Atomic update matched nothing — re-read so we can tell the driver
    // exactly why ("đã hết hạn" reads very differently from "đã được
    // tài xế khác nhận").
    final tripDoc = await tripsCol.findOne(where.eq('_id', tripObjId));
    if (tripDoc == null) {
      developer.log('[offer] LOST $tripId — trip vanished', name: 'offer');
      return (success: false, reason: 'Chuyến không còn tồn tại');
    }
    final trip = ScheduledTrip.fromMongo(tripDoc);
    final reason = _diagnoseAcceptFailure(trip: trip, driverId: driverId);
    developer.log('[offer] LOST $tripId — $reason', name: 'offer');
    return (success: false, reason: reason);
  }

  String _diagnoseAcceptFailure({
    required ScheduledTrip trip,
    required String driverId,
  }) {
    switch (trip.status) {
      case ScheduledTripStatus.cancelled:
        return 'Chuyến đã bị huỷ';
      case ScheduledTripStatus.driverAssigned:
      case ScheduledTripStatus.matched:
      case ScheduledTripStatus.started:
      case ScheduledTripStatus.completed:
        return trip.driverId == driverId
            // Edge: trip already assigned to ME but the where-clause
            // missed because the offer fields had been cleared in a
            // concurrent path. Treat as success-ish.
            ? 'Chuyến đã thuộc về bạn'
            : 'Chuyến đã được tài xế khác nhận';
      case ScheduledTripStatus.noDriverFound:
      case ScheduledTripStatus.expired:
        return 'Chuyến đã hết hạn tìm tài xế';
      case ScheduledTripStatus.pending:
        // Offer reverted to pending — most likely auto-expired by the
        // search-job sweep right under us.
        return 'Offer đã hết hạn, vui lòng chờ chuyến tiếp theo';
      case ScheduledTripStatus.offered:
        if (trip.currentOfferedDriverId != driverId) {
          return 'Offer này không dành cho bạn';
        }
        return 'Offer đã hết hạn, vui lòng chờ chuyến tiếp theo';
    }
  }

  /// Driver tapped "Từ chối" or their offer window elapsed. Reverts
  /// the trip to pending, pushes this driver into the reject list so
  /// they won't get re-offered the same trip, and clears the driver
  /// busy state.
  Future<void> rejectOffer({
    required String tripId,
    required String driverId,
    bool isTimeout = false,
  }) async {
    final tripsCol = await _mongo.scheduledTrips();
    final driversCol = await _mongo.drivers();
    final now = DateTime.now().toUtc();
    final tripObjId = ObjectId.fromHexString(tripId);
    final driverObjId = ObjectId.fromHexString(driverId);

    await tripsCol.updateOne(
      where.eq('_id', tripObjId).eq('status', 'offered'),
      modify
          .set('status', ScheduledTripStatus.pending.mongoName)
          .set('current_offered_driver_id', null)
          .set('current_offer_expires_at', null)
          .push('rejected_by_drivers', driverObjId)
          .set('updated_at', now),
    );
    await driversCol.updateOne(
      where.eq('_id', driverObjId),
      modify
          .set('current_offer_trip_id', null)
          .set('current_offer_expires_at', null)
          .set('updated_at', now),
    );
    developer.log(
      '[offer] ${isTimeout ? "TIMEOUT" : "REJECT"} $tripId by $driverId',
      name: 'offer',
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Background sweeps
  // ─────────────────────────────────────────────────────────────────

  /// Phase 5R hotfix: pre-step for the search loop. Sweeps any trip
  /// whose `current_offer_expires_at` lapsed but the driver never
  /// answered (no poll fired → no auto-reject ran). Reverts status
  /// back to pending and clears both sides of the offer marker so the
  /// next [processSearchingTrips] tick can re-offer cleanly. Returns
  /// the number of trips swept.
  Future<int> expireStaleOffers() async {
    final tripsCol = await _mongo.scheduledTrips();
    final driversCol = await _mongo.drivers();
    final now = DateTime.now().toUtc();

    final cursor = tripsCol.find(
      where.raw(<String, dynamic>{
        'status': ScheduledTripStatus.offered.mongoName,
        'current_offer_expires_at': {r'$lte': now},
      }),
    );
    final docs = await cursor.toList();
    if (docs.isEmpty) return 0;

    for (final doc in docs) {
      final tripObjId = doc['_id'] as ObjectId;
      final driverObjId = doc['current_offered_driver_id'] as ObjectId?;

      await tripsCol.updateOne(
        where
            .eq('_id', tripObjId)
            .eq('status', ScheduledTripStatus.offered.mongoName),
        modify
            .set('status', ScheduledTripStatus.pending.mongoName)
            .set('current_offered_driver_id', null)
            .set('current_offer_expires_at', null)
            // Push the lapsed driver into the reject list — same as
            // an explicit timeout reject — so the next offer cycle
            // doesn't immediately re-pick them.
            .push('rejected_by_drivers', driverObjId)
            .set('updated_at', now),
      );
      if (driverObjId != null) {
        await driversCol.updateOne(
          where.eq('_id', driverObjId),
          modify
              .set('current_offer_trip_id', null)
              .set('current_offer_expires_at', null)
              .set('updated_at', now),
        );
      }
      developer.log(
        '[offer] AUTO-EXPIRE ${tripObjId.oid} (no answer)',
        name: 'offer',
      );
    }
    return docs.length;
  }

  /// Find pending free-point trips near departure and offer each to
  /// the next eligible driver. Returns number of offers fired.
  Future<int> processSearchingTrips() async {
    final tripsCol = await _mongo.scheduledTrips();
    final now = DateTime.now().toUtc();
    final cutoff = now.add(eagerWindow);

    final docs = await tripsCol
        .find(
          where
              .raw(<String, dynamic>{
                'status': 'pending',
                'pool_id': null,
                'scheduled_at': {r'$lte': cutoff},
                'search_timeout_at': {r'$gt': now},
              })
              .sortBy('scheduled_at')
              .limit(20),
        )
        .toList();

    var offered = 0;
    for (final doc in docs) {
      final trip = ScheduledTrip.fromMongo(doc);
      final driverId = await findNextDriverForTrip(trip);
      if (driverId == null) continue;
      if (await offerTripToDriver(tripId: trip.id, driverId: driverId)) {
        offered++;
      }
    }
    if (offered > 0) {
      developer.log('[search-job] offered $offered trips', name: 'offer');
    }
    return offered;
  }

  /// Flip trips past `search_timeout_at` (any pending/offered state)
  /// to `no_driver_found`. Best-effort cleanup of any orphaned driver
  /// state attached to those trips happens inline.
  Future<int> autoCancelExpiredSearches() async {
    final tripsCol = await _mongo.scheduledTrips();
    final driversCol = await _mongo.drivers();
    final now = DateTime.now().toUtc();

    final docs = await tripsCol
        .find(
          where.raw(<String, dynamic>{
            'status': {
              r'$in': ['pending', 'offered'],
            },
            'pool_id': null,
            'search_timeout_at': {r'$lte': now},
          }),
        )
        .toList();

    for (final doc in docs) {
      final tripObjId = doc['_id'] as ObjectId;
      // Hotfix: was unconditional set-to-noDriverFound — between the
      // initial find() and this updateOne(), a driver could accept
      // (status → driver_assigned) and we'd overwrite it. Lock the
      // where-clause to status IN [pending, offered] so the cascade
      // only fires when the trip is still genuinely unassigned. This
      // is why the customer was seeing "Không tìm được tài xế" on
      // trips a driver had actually picked up.
      await tripsCol.updateOne(
        where.raw(<String, dynamic>{
          '_id': tripObjId,
          'status': {
            r'$in': ['pending', 'offered'],
          },
        }),
        modify
            .set('status', ScheduledTripStatus.noDriverFound.mongoName)
            .set('current_offered_driver_id', null)
            .set('current_offer_expires_at', null)
            .set('cancelled_at', now)
            .set('cancelled_by', 'system')
            .set('cancel_reason', 'Không tìm được tài xế phù hợp')
            .set('updated_at', now),
      );
      // Unstick any driver that was holding this offer.
      await driversCol.updateMany(
        where.eq('current_offer_trip_id', tripObjId),
        modify
            .set('current_offer_trip_id', null)
            .set('current_offer_expires_at', null)
            .set('updated_at', now),
      );
    }
    if (docs.isNotEmpty) {
      developer.log('[search-job] expired ${docs.length} trips',
          name: 'offer');
    }
    return docs.length;
  }

  // ─────────────────────────────────────────────────────────────────
  // Driver polling
  // ─────────────────────────────────────────────────────────────────

  /// What [driverId] is currently being offered, or `CurrentOffer.empty`.
  /// If the held offer has expired, auto-rejects it as a side-effect so
  /// the next poll returns empty and the driver is unstuck.
  Future<CurrentOffer> getCurrentOfferForDriver(String driverId) async {
    final driversCol = await _mongo.drivers();
    final tripsCol = await _mongo.scheduledTrips();

    final driverDoc = await driversCol.findOne(
      where.eq('_id', ObjectId.fromHexString(driverId)),
    );
    if (driverDoc == null) return CurrentOffer.empty;

    final offerTripId = driverDoc['current_offer_trip_id'] as ObjectId?;
    final expiresAt = driverDoc['current_offer_expires_at'] as DateTime?;
    if (offerTripId == null || expiresAt == null) return CurrentOffer.empty;

    final now = DateTime.now().toUtc();
    if (now.isAfter(expiresAt)) {
      await rejectOffer(
        tripId: offerTripId.oid,
        driverId: driverId,
        isTimeout: true,
      );
      return CurrentOffer.empty;
    }

    final tripDoc = await tripsCol.findOne(where.eq('_id', offerTripId));
    if (tripDoc == null) return CurrentOffer.empty;

    return CurrentOffer(
      trip: ScheduledTrip.fromMongo(tripDoc),
      secondsLeft: expiresAt.difference(now).inSeconds,
    );
  }
}
