import 'dart:developer' as developer;

import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where, modify;

import '../core/db/mongo_service.dart';
import '../models/driver_vehicle.dart';
import '../models/scheduled_trip.dart';
import '../models/trip_pool.dart';

/// Core carpool engine (Phase 5N). Lifecycle:
///
///   newTrip → findOrCreatePool → joinPool | createPool
///                                 ↓
///                            collecting / confirmed
///                                 ↓ (driver tap)
///                              assigned → started → completed
///                                 ↓ (deadline)
///                            cancelled_no_pool / cancelled_no_driver
class TripPoolService {
  TripPoolService(this._mongo);
  final MongoService _mongo;

  // ── Pool code ─────────────────────────────────────────────────────

  /// `POOL-YYYYMMDD-NNN`, sequence per scheduled-date.
  Future<String> generatePoolCode(DateTime scheduledAt) async {
    final dateStr =
        '${scheduledAt.year}'
        '${scheduledAt.month.toString().padLeft(2, '0')}'
        '${scheduledAt.day.toString().padLeft(2, '0')}';
    final col = await _mongo.tripPools();
    final count = await col.count(
      where.raw(<String, dynamic>{
        'pool_code': {r'$regex': '^POOL-$dateStr-'},
      }),
    );
    final seq = (count + 1).toString().padLeft(3, '0');
    return 'POOL-$dateStr-$seq';
  }

  // ── Find or create (entry point from ScheduledTripService) ────────

  /// Called right after a scheduled trip is persisted. Looks for an
  /// existing `collecting` pool serving the same dropoff district +
  /// overlapping ±30min window with seats free for [trip.passengerCount];
  /// joins the closest-in-time one if any, otherwise creates a new pool.
  Future<TripPool> findOrCreatePool(ScheduledTrip trip) async {
    final col = await _mongo.tripPools();
    final dropoffParts = _parseAddress(trip.dropoff.address);
    final pickupParts = _parseAddress(trip.pickup.address);
    final scheduledAtUtc = trip.scheduledAt.toUtc();
    const window = Duration(minutes: 30);

    final candidates = await col
        .find(
          where
              .eq('status', TripPoolStatus.collecting.mongoName)
              .eq('dropoff_city', dropoffParts.city)
              .eq('dropoff_district', dropoffParts.district)
              .gte('scheduled_at', scheduledAtUtc.subtract(window))
              .lte('scheduled_at', scheduledAtUtc.add(window)),
        )
        .toList();

    final available = candidates.where((doc) {
      final p = TripPool.fromMongo(doc);
      return p.availableSeats >= trip.passengerCount;
    }).toList();

    if (available.isNotEmpty) {
      available.sort((a, b) {
        final ad = (a['scheduled_at'] as DateTime)
            .difference(scheduledAtUtc)
            .inMinutes
            .abs();
        final bd = (b['scheduled_at'] as DateTime)
            .difference(scheduledAtUtc)
            .inMinutes
            .abs();
        return ad.compareTo(bd);
      });
      final chosen = available.first;
      return _joinPool(
        poolId: (chosen['_id'] as ObjectId).oid,
        trip: trip,
      );
    }

    return _createPool(
      trip: trip,
      pickupParts: pickupParts,
      dropoffParts: dropoffParts,
    );
  }

  Future<TripPool> _createPool({
    required ScheduledTrip trip,
    required _AddressParts pickupParts,
    required _AddressParts dropoffParts,
  }) async {
    final col = await _mongo.tripPools();
    final tripsCol = await _mongo.scheduledTrips();
    final now = DateTime.now().toUtc();

    // Option B: lock pool size based on the FIRST booker's headcount.
    // ≤3 pax → 4-seat car (min threshold 3); 4+ pax → 7-seat car (min 4).
    final passCount = trip.passengerCount;
    final vehicleSeats = passCount <= 3 ? 4 : 7;
    final minThreshold = passCount <= 3 ? 3 : 4;

    final scheduledAtUtc = trip.scheduledAt.toUtc();
    final earliestAt = scheduledAtUtc.subtract(const Duration(minutes: 30));
    final latestAt = scheduledAtUtc.add(const Duration(minutes: 30));
    // Hotfix: the schedule screen only requires `scheduledAt > now + 30
    // min`, so the naive "1 hour before scheduledAt" deadline lands in
    // the past for any short-lead booking. The 60-second auto-cancel
    // sweep then nukes the pool the moment it lands. Floor the deadline
    // at "now + 10 min" so every new pool gets at least 10 minutes to
    // gather passengers before it can be cancelled.
    final rawDeadline = scheduledAtUtc.subtract(const Duration(hours: 1));
    final minDeadline = now.add(const Duration(minutes: 10));
    final cancelDeadline =
        rawDeadline.isBefore(minDeadline) ? minDeadline : rawDeadline;

    // Rough estimate: scale the first booker's fare by min_threshold so
    // every passenger pays roughly the same share once full.
    final estimatedTotalFare = trip.estimatedFare;
    final estimatedFarePerPax =
        passCount == 0 ? 0 : (estimatedTotalFare / passCount).round();

    final poolCode = await generatePoolCode(trip.scheduledAt);
    final poolId = ObjectId();
    final initialStatus = passCount >= minThreshold
        ? TripPoolStatus.confirmed
        : TripPoolStatus.collecting;

    final doc = <String, dynamic>{
      '_id': poolId,
      'pool_code': poolCode,
      'pickup_city': pickupParts.city,
      'pickup_district': pickupParts.district,
      'dropoff_city': dropoffParts.city,
      'dropoff_district': dropoffParts.district,
      'dropoff_lat_mean': trip.dropoff.lat,
      'dropoff_lng_mean': trip.dropoff.lng,
      'scheduled_at': scheduledAtUtc,
      'time_window_min': 30,
      'earliest_at': earliestAt,
      'latest_at': latestAt,
      'vehicle_seats': vehicleSeats,
      'min_threshold': minThreshold,
      'current_passengers': passCount,
      'scheduled_trip_ids': <ObjectId>[ObjectId.fromHexString(trip.id)],
      'status': initialStatus.mongoName,
      'driver_id': null,
      'driver_vehicle_id': null,
      'cancel_deadline': cancelDeadline,
      'estimated_total_fare': estimatedTotalFare,
      'estimated_fare_per_pax': estimatedFarePerPax,
      'cancelled_at': null,
      'cancelled_reason': null,
      'created_at': now,
      'updated_at': now,
    };
    await col.insertOne(doc);

    await tripsCol.updateOne(
      where.id(ObjectId.fromHexString(trip.id)),
      modify.set('pool_id', poolId).set('updated_at', now),
    );

    developer.log(
      '[pool] CREATE $poolCode (${vehicleSeats}s $passCount/$minThreshold ${initialStatus.mongoName})',
      name: 'pool',
    );
    return TripPool.fromMongo(doc);
  }

  Future<TripPool> _joinPool({
    required String poolId,
    required ScheduledTrip trip,
  }) async {
    final col = await _mongo.tripPools();
    final tripsCol = await _mongo.scheduledTrips();
    final now = DateTime.now().toUtc();
    final poolObjId = ObjectId.fromHexString(poolId);

    final poolDoc = await col.findOne(where.id(poolObjId));
    if (poolDoc == null) {
      throw StateError('Pool $poolId disappeared between find and join');
    }
    final pool = TripPool.fromMongo(poolDoc);
    final newCount = pool.currentPassengers + trip.passengerCount;
    final newStatus = newCount >= pool.minThreshold
        ? TripPoolStatus.confirmed
        : TripPoolStatus.collecting;

    await col.updateOne(
      where.id(poolObjId),
      modify
          .inc('current_passengers', trip.passengerCount)
          .push('scheduled_trip_ids', ObjectId.fromHexString(trip.id))
          .set('status', newStatus.mongoName)
          .set('updated_at', now),
    );

    await tripsCol.updateOne(
      where.id(ObjectId.fromHexString(trip.id)),
      modify.set('pool_id', poolObjId).set('updated_at', now),
    );

    developer.log(
      '[pool] JOIN ${pool.poolCode} ($newCount/${pool.minThreshold} ${newStatus.mongoName})',
      name: 'pool',
    );

    final updated = await col.findOne(where.id(poolObjId));
    return TripPool.fromMongo(updated!);
  }

  // ── Driver actions ────────────────────────────────────────────────

  /// Optimistic-lock atomic accept: only flips `confirmed → assigned`,
  /// so a second driver tapping at the same time gets `false` instead
  /// of double-booking the pool. Verifies the vehicle has the matching
  /// seat count first.
  Future<bool> driverAcceptPool({
    required String poolId,
    required String driverId,
    required DriverVehicle vehicle,
  }) async {
    final col = await _mongo.tripPools();
    final poolDoc = await col.findOne(
      where.id(ObjectId.fromHexString(poolId)),
    );
    if (poolDoc == null) return false;
    final pool = TripPool.fromMongo(poolDoc);

    if (vehicle.vehicleSeats != pool.vehicleSeats) {
      developer.log(
        '[pool] REJECT ${pool.poolCode}: vehicle seats ${vehicle.vehicleSeats} ≠ pool ${pool.vehicleSeats}',
        name: 'pool',
      );
      return false;
    }
    if (pool.status != TripPoolStatus.confirmed) {
      developer.log(
        '[pool] REJECT ${pool.poolCode}: status ${pool.status.mongoName} (need confirmed)',
        name: 'pool',
      );
      return false;
    }

    final res = await col.updateOne(
      where
          .id(ObjectId.fromHexString(poolId))
          .eq('status', TripPoolStatus.confirmed.mongoName),
      modify
          .set('driver_id', ObjectId.fromHexString(driverId))
          .set('driver_vehicle_id', ObjectId.fromHexString(vehicle.id))
          .set('status', TripPoolStatus.assigned.mongoName)
          .set('updated_at', DateTime.now().toUtc()),
    );
    final ok = res.isSuccess && res.nModified > 0;
    developer.log(
      ok
          ? '[pool] ASSIGN ${pool.poolCode} → driver=$driverId vehicle=${vehicle.vehiclePlate}'
          : '[pool] LOST ${pool.poolCode} — another driver grabbed it',
      name: 'pool',
    );
    return ok;
  }

  // ── Auto-cancel job ───────────────────────────────────────────────

  /// Sweeps `collecting` pools past their [TripPool.cancelDeadline] and
  /// flips them to `cancelled_no_pool`, simultaneously cancelling every
  /// member scheduled trip with a system-attributed reason.
  ///
  /// Returns the number of pools cancelled.
  Future<int> autoCancelExpiredPools() async {
    final col = await _mongo.tripPools();
    final tripsCol = await _mongo.scheduledTrips();
    final now = DateTime.now().toUtc();

    final cursor = col.find(
      where
          .eq('status', TripPoolStatus.collecting.mongoName)
          .lte('cancel_deadline', now),
    );
    final docs = await cursor.toList();

    var cancelled = 0;
    for (final doc in docs) {
      final pool = TripPool.fromMongo(doc);
      // Hotfix: don't cancel pools that were just created — gives the
      // pool a 5-minute grace window even if the deadline check above
      // matched (e.g. clock skew or stale documents).
      if (now.difference(pool.createdAt.toUtc()) <
          const Duration(minutes: 5)) {
        developer.log(
          '[pool] SKIP ${pool.poolCode}: within 5-min grace period',
          name: 'pool',
        );
        continue;
      }
      await col.updateOne(
        where.id(ObjectId.fromHexString(pool.id)),
        modify
            .set('status', TripPoolStatus.cancelledNoPool.mongoName)
            .set('cancelled_at', now)
            .set('cancelled_reason', 'Không đủ khách trước giờ khởi hành')
            .set('updated_at', now),
      );
      for (final tripId in pool.scheduledTripIds) {
        // Hotfix safety: only cancel trips that are still pending. A
        // trip that has already been picked up / completed shouldn't be
        // reverted by a stale pool sweep.
        await tripsCol.updateOne(
          where
              .id(ObjectId.fromHexString(tripId))
              .eq('status', ScheduledTripStatus.pending.mongoName),
          modify
              .set('status', ScheduledTripStatus.cancelled.mongoName)
              .set('cancelled_at', now)
              .set('cancelled_by', 'system')
              .set('cancel_reason', 'Pool ${pool.poolCode} không đủ khách')
              .set('updated_at', now),
        );
      }
      cancelled++;
      developer.log('[pool] AUTO-CANCEL ${pool.poolCode}', name: 'pool');
    }
    return cancelled;
  }

  // ── Queries ───────────────────────────────────────────────────────

  Future<TripPool?> getById(String poolId) async {
    final col = await _mongo.tripPools();
    final doc = await col.findOne(where.id(ObjectId.fromHexString(poolId)));
    return doc == null ? null : TripPool.fromMongo(doc);
  }

  /// Pools the driver can accept right now — confirmed + matching the
  /// driver's vehicle seat count + still in the future.
  Future<List<TripPool>> getDriverAvailablePools({
    required int vehicleSeats,
  }) async {
    final col = await _mongo.tripPools();
    final now = DateTime.now().toUtc();
    final cursor = col.find(
      where
          .eq('status', TripPoolStatus.confirmed.mongoName)
          .eq('vehicle_seats', vehicleSeats)
          .gte('scheduled_at', now)
          .sortBy('scheduled_at')
          .limit(50),
    );
    final docs = await cursor.toList();
    return docs.map(TripPool.fromMongo).toList(growable: false);
  }

  /// Pools still gathering passengers — drivers can watch but not yet
  /// accept (these become available once they hit the threshold).
  Future<List<TripPool>> getDriverCollectingPools({
    required int vehicleSeats,
  }) async {
    final col = await _mongo.tripPools();
    final now = DateTime.now().toUtc();
    final cursor = col.find(
      where
          .eq('status', TripPoolStatus.collecting.mongoName)
          .eq('vehicle_seats', vehicleSeats)
          .gte('scheduled_at', now)
          .sortBy('scheduled_at')
          .limit(20),
    );
    final docs = await cursor.toList();
    return docs.map(TripPool.fromMongo).toList(growable: false);
  }

  // ── Address parsing ──────────────────────────────────────────────

  /// Cheap split-on-comma + Vietnamese-aware district detection. Good
  /// enough for the demo; production should switch to geohash bucketing
  /// because reverse-geocoder address formats are not stable.
  _AddressParts _parseAddress(String address) {
    final parts = address.split(',').map((p) => p.trim()).toList();
    if (parts.isEmpty) return const _AddressParts(city: '', district: '');
    if (parts.length == 1) {
      return _AddressParts(city: _normalizeVN(parts.first), district: '');
    }
    final city = _normalizeVN(parts.last);
    String district = '';
    for (var i = parts.length - 2; i >= 0; i--) {
      final p = parts[i];
      if (p.contains('Phường') ||
          p.contains('Quận') ||
          p.contains('Huyện') ||
          p.contains('Thị xã') ||
          p.contains('P.') ||
          p.contains('Q.')) {
        district = _normalizeVN(
          p
              .replaceAll('Phường', '')
              .replaceAll('Quận', '')
              .replaceAll('Huyện', '')
              .replaceAll('Thị xã', '')
              .replaceAll('P.', '')
              .replaceAll('Q.', '')
              .trim(),
        );
        break;
      }
    }
    district = district.isEmpty
        ? _normalizeVN(parts[parts.length - 2])
        : district;
    return _AddressParts(city: city, district: district);
  }

  String _normalizeVN(String s) {
    const diacritic =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const plain =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    final buf = StringBuffer();
    for (final ch in s.runes) {
      final str = String.fromCharCode(ch);
      final idx = diacritic.indexOf(str);
      buf.write(idx >= 0 ? plain[idx] : str);
    }
    return buf.toString().trim().toLowerCase();
  }
}

class _AddressParts {
  final String city;
  final String district;
  const _AddressParts({required this.city, required this.district});
}
