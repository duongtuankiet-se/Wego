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

  /// Picks a mock driver (by index from kMockDrivers), upserts into the
  /// drivers collection, and returns the active record (id + position
  /// offset by mock latLng deltas relative to [pickup]).
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
        'user_id': ObjectId(), // fake stand-in user reference
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

  /// Inserts a Trip with status=accepted and a freshly-picked mock driver.
  /// Returns the [ActiveTrip] for the live screen.
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
      'created_at': now,
      'updated_at': now,
      'completed_at': null,
    };

    await (await _mongo.trips()).insertOne(tripDoc);
    developer.log('[trip] inserted ${tripId.oid}', name: 'trip');

    final trip = Trip.fromMongo(tripDoc);
    return ActiveTrip(tripId: trip.id, trip: trip, driver: driver);
  }

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

    // Bump driver stats (rolling average) — best-effort, no transactions.
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

  /// Provider-facing helper for the cancel button. Marks the trip cancelled.
  Future<void> cancelTrip(String tripId) =>
      updateStatus(tripId, TripStatus.cancelled);
}
