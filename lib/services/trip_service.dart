import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where, modify;

import '../core/db/mongo_service.dart';
import '../core/utils/geohash_util.dart';
import '../data/mock_drivers.dart';
import '../models/place.dart';
import '../models/trip.dart';
import '../providers/current_trip_provider.dart';

class TripService {
  TripService(this._mongo);
  final MongoService _mongo;
  final math.Random _rng = math.Random();

  // ─────────────────────────────────────────────────────────────────────
  // Phase 3 matching engine
  // ─────────────────────────────────────────────────────────────────────

  /// Picks the nearest online driver to [pickupLat]/[pickupLng] using
  /// geohash prefix scanning. Strategy:
  ///   1. Encode pickup at precision 5 (~4.9km cell).
  ///   2. Collect that cell + 8 neighbors (9 prefixes).
  ///   3. Mongo query: status=online AND current_geohash regex ^(prefix|…).
  ///   4. Sort Dart-side by Haversine distance ascending.
  ///   5. Fallback once at precision 4 (~39km). Final fallback: any online.
  Future<Map<String, dynamic>?> findNearestDriver({
    required double pickupLat,
    required double pickupLng,
  }) async {
    final drivers = await _mongo.drivers();

    Future<List<Map<String, dynamic>>> queryWithPrecision(int precision) async {
      final hash = GeohashUtil.encode(
        pickupLat,
        pickupLng,
        precision: precision,
      );
      final neighbors = GeohashUtil.neighbors(hash);
      final selector = where.raw(<String, dynamic>{
        'status': 'online',
        'current_lat': {r'$ne': null},
        'current_lng': {r'$ne': null},
        'current_geohash': {r'$regex': '^(${neighbors.join('|')})'},
      });
      final cursor = drivers.find(selector);
      return cursor.toList();
    }

    var candidates = await queryWithPrecision(5);
    if (candidates.isEmpty) {
      candidates = await queryWithPrecision(4);
    }
    if (candidates.isEmpty) {
      // Last-ditch: any online driver, regardless of distance.
      final any = await drivers.findOne(where.eq('status', 'online'));
      return any;
    }

    candidates.sort((a, b) {
      final dA = GeohashUtil.distanceKm(
        pickupLat,
        pickupLng,
        (a['current_lat'] as num).toDouble(),
        (a['current_lng'] as num).toDouble(),
      );
      final dB = GeohashUtil.distanceKm(
        pickupLat,
        pickupLng,
        (b['current_lat'] as num).toDouble(),
        (b['current_lng'] as num).toDouble(),
      );
      return dA.compareTo(dB);
    });
    return candidates.first;
  }

  /// Looks for an existing pending shared trip whose route is compatible
  /// with the incoming one. Returns the matched raw doc or null.
  /// Criteria:
  ///   * status=pending, type=shared, created in the last 10 minutes
  ///   * Pickup geohash precision 6 within own cell or 8 neighbors
  ///   * Different passenger
  ///   * `shared_with` size < 3 (caps the pool per car)
  ///   * Bearing difference < 45° AND dropoff distance < 5km
  Future<Map<String, dynamic>?> findCarpoolMatch({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required String currentPassengerId,
  }) async {
    final pickupHash = GeohashUtil.encode(pickupLat, pickupLng);
    final neighbors = GeohashUtil.neighbors(pickupHash);
    final tenMinAgo = DateTime.now().toUtc().subtract(
      const Duration(minutes: 10),
    );

    final trips = await _mongo.trips();
    final selector = where.raw(<String, dynamic>{
      'status': 'pending',
      'type': 'shared',
      'passenger_id': {r'$ne': ObjectId.fromHexString(currentPassengerId)},
      'created_at': {r'$gt': tenMinAgo},
      'pickup_geohash': {r'$in': neighbors},
    });
    final cursor = trips.find(selector);
    final candidates = await cursor.toList();
    if (candidates.isEmpty) return null;

    // Sort oldest first to reduce wait time.
    candidates.sort((a, b) {
      final tA = a['created_at'] as DateTime;
      final tB = b['created_at'] as DateTime;
      return tA.compareTo(tB);
    });

    final myBearing = GeohashUtil.bearing(
      pickupLat,
      pickupLng,
      dropoffLat,
      dropoffLng,
    );

    for (final trip in candidates) {
      // Skip trips already carrying 3 carpool passengers.
      final sharedWith = (trip['shared_with'] as List?) ?? const <dynamic>[];
      if (sharedWith.length >= 3) continue;

      final theirBearing = GeohashUtil.bearing(
        (trip['pickup_lat'] as num).toDouble(),
        (trip['pickup_lng'] as num).toDouble(),
        (trip['dropoff_lat'] as num).toDouble(),
        (trip['dropoff_lng'] as num).toDouble(),
      );
      final rawDiff = (myBearing - theirBearing).abs() % 360;
      final diff = rawDiff > 180 ? 360 - rawDiff : rawDiff;
      if (diff > 45) continue;

      final dropoffDist = GeohashUtil.distanceKm(
        dropoffLat,
        dropoffLng,
        (trip['dropoff_lat'] as num).toDouble(),
        (trip['dropoff_lng'] as num).toDouble(),
      );
      if (dropoffDist > 5.0) continue;

      return trip;
    }
    return null;
  }

  /// Inserts a trip with status=pending and no driver_id. Returns the new
  /// trip's ObjectId hex. Used by the matching screen as step 1 before
  /// trying to carpool or dispatch.
  Future<String> insertPendingTrip({
    required String passengerId,
    required Place pickup,
    required Place dropoff,
    required TripType type,
    required int price,
    required double distanceKm,
    required int durationMin,
  }) async {
    final now = DateTime.now().toUtc();
    final tripId = ObjectId();
    final doc = <String, dynamic>{
      '_id': tripId,
      'passenger_id': ObjectId.fromHexString(passengerId),
      'driver_id': null,
      'type': type.name,
      'status': TripStatus.pending.name,
      'pickup_lat': pickup.lat,
      'pickup_lng': pickup.lng,
      'pickup_address': pickup.name,
      'pickup_geohash': GeohashUtil.encode(pickup.lat, pickup.lng),
      'dropoff_lat': dropoff.lat,
      'dropoff_lng': dropoff.lng,
      'dropoff_address': dropoff.name,
      'dropoff_geohash': GeohashUtil.encode(dropoff.lat, dropoff.lng),
      'distance_km': distanceKm,
      'duration_min': durationMin,
      'price': price,
      'payment_method': null,
      'shared_with': <ObjectId>[],
      'created_at': now,
      'updated_at': now,
      'started_at': null,
      'ended_at': null,
      'completed_at': null,
    };
    await (await _mongo.trips()).insertOne(doc);
    developer.log('[trip] pending ${tripId.oid}', name: 'trip');
    return tripId.oid;
  }

  /// Adds [newPassengerId] to the shared_with list of [hostTripId]
  /// (the existing pending carpool trip we matched into). The matched
  /// passenger does NOT get their own driver dispatched — they ride
  /// the host trip.
  Future<void> joinCarpool({
    required String hostTripId,
    required String newPassengerId,
  }) async {
    final now = DateTime.now().toUtc();
    await (await _mongo.trips()).updateOne(
      where.eq('_id', ObjectId.fromHexString(hostTripId)),
      modify
          .push('shared_with', ObjectId.fromHexString(newPassengerId))
          .set('updated_at', now),
    );
  }

  /// Promotes a pending trip to accepted with the chosen driver. Returns
  /// the assigned driver's raw Mongo doc so the UI can build ActiveTrip.
  Future<Map<String, dynamic>?> dispatchDriverToTrip({
    required String tripId,
    required double pickupLat,
    required double pickupLng,
  }) async {
    final driverDoc = await findNearestDriver(
      pickupLat: pickupLat,
      pickupLng: pickupLng,
    );
    if (driverDoc == null) return null;

    final now = DateTime.now().toUtc();
    await (await _mongo.trips()).updateOne(
      where.eq('_id', ObjectId.fromHexString(tripId)),
      modify
          .set('driver_id', driverDoc['_id'])
          .set('status', TripStatus.accepted.name)
          .set('updated_at', now),
    );
    return driverDoc;
  }

  /// Reads a trip + driver pair from Mongo into the in-memory ActiveTrip
  /// shape. Used by the matching screen after dispatch succeeds.
  Future<ActiveTrip?> loadActiveTrip(String tripId) async {
    final trips = await _mongo.trips();
    final tripDoc = await trips.findOne(
      where.eq('_id', ObjectId.fromHexString(tripId)),
    );
    if (tripDoc == null) return null;
    final driverId = tripDoc['driver_id'] as ObjectId?;
    if (driverId == null) return null;
    final drivers = await _mongo.drivers();
    final driverDoc = await drivers.findOne(where.eq('_id', driverId));
    if (driverDoc == null) return null;

    final trip = Trip.fromMongo(tripDoc);
    final driver = ActiveDriver(
      id: driverId.oid,
      name: driverDoc['name'] as String? ?? 'Tài xế',
      phone: driverDoc['phone'] as String? ?? '',
      vehicleModel: driverDoc['vehicle_model'] as String? ?? '',
      vehicleColor: driverDoc['vehicle_color'] as String? ?? '',
      vehiclePlate: driverDoc['vehicle_plate'] as String? ?? '',
      rating: (driverDoc['rating_avg'] as num?)?.toDouble() ?? 5.0,
      totalTrips: (driverDoc['total_trips'] as num?)?.toInt() ?? 0,
      currentLat:
          (driverDoc['current_lat'] as num?)?.toDouble() ?? trip.pickupLat,
      currentLng:
          (driverDoc['current_lng'] as num?)?.toDouble() ?? trip.pickupLng,
    );
    return ActiveTrip(tripId: trip.id, trip: trip, driver: driver);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Legacy single-shot helper (Phase 1B compatibility)
  // Used by /dev/matching-test fallback only.
  // ─────────────────────────────────────────────────────────────────────

  /// Picks a mock driver, upserts into the drivers collection, and returns
  /// the active record. Phase 1B legacy — Phase 3 prefers explicit
  /// insertPendingTrip + dispatchDriverToTrip.
  Future<ActiveDriver> _getOrCreateMockDriver(Place pickup) async {
    final mock = kMockDrivers[_rng.nextInt(kMockDrivers.length)];
    final driverLat = pickup.lat + mock.latOffset;
    final driverLng = pickup.lng + mock.lngOffset;
    final geohash = GeohashUtil.encode(driverLat, driverLng);

    final coll = await _mongo.drivers();
    final existing = await coll.findOne(where.eq('phone', mock.phone));
    final now = DateTime.now().toUtc();

    ObjectId driverId;
    if (existing == null) {
      driverId = ObjectId();
      await coll.insertOne(<String, dynamic>{
        '_id': driverId,
        'user_id': ObjectId(),
        'name': mock.name,
        'phone': mock.phone,
        'vehicle_model': mock.vehicleModel,
        'vehicle_color': mock.vehicleColor,
        'vehicle_plate': mock.vehiclePlate,
        'rating_avg': mock.rating,
        'total_trips': mock.totalTrips,
        'status': 'online',
        'current_lat': driverLat,
        'current_lng': driverLng,
        'current_geohash': geohash,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      driverId = existing['_id'] as ObjectId;
      await coll.updateOne(
        where.eq('_id', driverId),
        modify
            .set('current_lat', driverLat)
            .set('current_lng', driverLng)
            .set('current_geohash', geohash)
            .set('status', 'online')
            .set('updated_at', now),
      );
    }

    return ActiveDriver(
      id: driverId.oid,
      name: mock.name,
      phone: mock.phone,
      vehicleModel: mock.vehicleModel,
      vehicleColor: mock.vehicleColor,
      vehiclePlate: mock.vehiclePlate,
      rating: mock.rating,
      totalTrips: mock.totalTrips,
      currentLat: driverLat,
      currentLng: driverLng,
    );
  }

  /// Phase 1B path: inserts a trip with status=accepted and a freshly-
  /// picked mock driver in one shot. Still used as a fallback when the
  /// matching engine can't find any online driver.
  Future<ActiveTrip> createTrip({
    required String passengerId,
    required Place pickup,
    required Place dropoff,
    required TripType type,
    required int price,
    required double distanceKm,
    required int durationMin,
  }) async {
    final driver = await _getOrCreateMockDriver(pickup);
    final now = DateTime.now().toUtc();
    final tripId = ObjectId();

    final tripDoc = <String, dynamic>{
      '_id': tripId,
      'passenger_id': ObjectId.fromHexString(passengerId),
      'driver_id': ObjectId.fromHexString(driver.id),
      'type': type.name,
      'status': TripStatus.accepted.name,
      'pickup_lat': pickup.lat,
      'pickup_lng': pickup.lng,
      'pickup_address': pickup.name,
      'pickup_geohash': GeohashUtil.encode(pickup.lat, pickup.lng),
      'dropoff_lat': dropoff.lat,
      'dropoff_lng': dropoff.lng,
      'dropoff_address': dropoff.name,
      'dropoff_geohash': GeohashUtil.encode(dropoff.lat, dropoff.lng),
      'distance_km': distanceKm,
      'duration_min': durationMin,
      'price': price,
      'payment_method': null,
      'shared_with': <ObjectId>[],
      'created_at': now,
      'updated_at': now,
      'completed_at': null,
    };
    await (await _mongo.trips()).insertOne(tripDoc);
    developer.log('[trip] inserted ${tripId.oid}', name: 'trip');

    final trip = Trip.fromMongo(tripDoc);
    return ActiveTrip(tripId: trip.id, trip: trip, driver: driver);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────

  Future<void> updateStatus(String tripId, TripStatus status) async {
    final now = DateTime.now().toUtc();
    await (await _mongo.trips()).updateOne(
      where.eq('_id', ObjectId.fromHexString(tripId)),
      modify.set('status', status.name).set('updated_at', now),
    );
  }

  /// Marks trip completed + saves payment_method + inserts Rating doc.
  Future<void> completeTrip({
    required String tripId,
    required String passengerId,
    required String driverId,
    required String paymentMethod,
    required int stars,
    required Set<String> tags,
  }) async {
    final now = DateTime.now().toUtc();
    final tripObjId = ObjectId.fromHexString(tripId);

    await (await _mongo.trips()).updateOne(
      where.eq('_id', tripObjId),
      modify
          .set('status', TripStatus.completed.name)
          .set('payment_method', paymentMethod)
          .set('updated_at', now)
          .set('completed_at', now),
    );

    await (await _mongo.ratings()).insertOne(<String, dynamic>{
      '_id': ObjectId(),
      'trip_id': tripObjId,
      'rater_id': ObjectId.fromHexString(passengerId),
      'ratee_id': ObjectId.fromHexString(driverId),
      'stars': stars,
      'comment': null,
      'tags': tags.toList(),
      'created_at': now,
    });

    try {
      final drivers = await _mongo.drivers();
      final driverObjId = ObjectId.fromHexString(driverId);
      final existing = await drivers.findOne(where.eq('_id', driverObjId));
      if (existing != null) {
        final prevAvg = (existing['rating_avg'] as num?)?.toDouble() ?? 5.0;
        final prevCount = (existing['total_trips'] as num?)?.toInt() ?? 0;
        final newCount = prevCount + 1;
        final newAvg = ((prevAvg * prevCount) + stars) / newCount;
        await drivers.updateOne(
          where.eq('_id', driverObjId),
          modify
              .set('rating_avg', double.parse(newAvg.toStringAsFixed(2)))
              .set('total_trips', newCount)
              .set('updated_at', now),
        );
      }
    } catch (e) {
      developer.log('[trip] driver bump failed: $e', name: 'trip');
    }

    developer.log('[trip] completed $tripId', name: 'trip');
  }

  /// Provider-facing helper for the cancel button.
  Future<void> cancelTrip(String tripId) =>
      updateStatus(tripId, TripStatus.cancelled);
}
