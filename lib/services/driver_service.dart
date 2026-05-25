import 'dart:developer' as developer;

import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where, modify;

import '../core/db/mongo_service.dart';
import '../core/utils/geohash_util.dart';
import '../models/driver.dart';
import '../models/trip.dart';

class DriverDailyStats {
  final int earningsVnd;
  final int tripCount;
  final int activeMinutes;
  final double ratingAvg;

  const DriverDailyStats({
    required this.earningsVnd,
    required this.tripCount,
    required this.activeMinutes,
    required this.ratingAvg,
  });

  static const empty = DriverDailyStats(
    earningsVnd: 0,
    tripCount: 0,
    activeMinutes: 0,
    ratingAvg: 0,
  );
}

class CompletedTripRow {
  final String tripId;
  final String pickupAddress;
  final String dropoffAddress;
  final DateTime completedAt;
  final int price;
  final double distanceKm;

  const CompletedTripRow({
    required this.tripId,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.completedAt,
    required this.price,
    required this.distanceKm,
  });
}

class DriverService {
  DriverService(this._mongo);
  final MongoService _mongo;

  /// Returns the driver doc tied to a user, or null if not registered yet.
  Future<Driver?> getDriverForUser(String userId) async {
    final coll = await _mongo.drivers();
    final doc = await coll.findOne(
      where.eq('user_id', ObjectId.fromHexString(userId)),
    );
    return doc == null ? null : Driver.fromMongo(doc);
  }

  /// Toggle the dispatch status (offline/online/busy). Also writes the
  /// last-known position so the heat map matches the actual driver.
  Future<void> setStatus({
    required String driverId,
    required DriverStatus status,
    double? lat,
    double? lng,
  }) async {
    final now = DateTime.now().toUtc();
    final mods = modify.set('status', status.name).set('updated_at', now);
    if (lat != null && lng != null) {
      mods
          .set('current_lat', lat)
          .set('current_lng', lng)
          .set('current_geohash', GeohashUtil.encode(lat, lng));
    }
    await (await _mongo.drivers()).updateOne(
      where.eq('_id', ObjectId.fromHexString(driverId)),
      mods,
    );
  }

  /// Driver accepts a pending trip (or a freshly-created mock dispatch).
  /// Returns true on success.
  Future<bool> acceptTrip({
    required String tripId,
    required String driverId,
  }) async {
    final now = DateTime.now().toUtc();
    final result = await (await _mongo.trips()).updateOne(
      where.eq('_id', ObjectId.fromHexString(tripId)),
      modify
          .set('driver_id', ObjectId.fromHexString(driverId))
          .set('status', TripStatus.accepted.name)
          .set('updated_at', now),
    );
    return result.nModified > 0 || result.isSuccess;
  }

  /// Driver tapped "Đón khách" — passenger is in the car now.
  Future<void> markPickedUp(String tripId) async {
    final now = DateTime.now().toUtc();
    await (await _mongo.trips()).updateOne(
      where.eq('_id', ObjectId.fromHexString(tripId)),
      modify
          .set('status', TripStatus.ongoing.name)
          .set('started_at', now)
          .set('updated_at', now),
    );
  }

  /// Driver tapped "Hoàn tất" — trip is done, payment outstanding.
  /// Status moves to completed but payment_method stays null until the
  /// passenger picks one on their Trip Summary screen.
  Future<void> completeAsDriver({
    required String tripId,
    required String driverId,
    required int price,
  }) async {
    final now = DateTime.now().toUtc();
    final trips = await _mongo.trips();
    await trips.updateOne(
      where.eq('_id', ObjectId.fromHexString(tripId)),
      modify
          .set('status', TripStatus.completed.name)
          .set('ended_at', now)
          .set('completed_at', now)
          .set('updated_at', now),
    );

    // Bump driver totalTrips counter (rating handled by passenger flow).
    try {
      final drivers = await _mongo.drivers();
      await drivers.updateOne(
        where.eq('_id', ObjectId.fromHexString(driverId)),
        modify.inc('total_trips', 1).set('updated_at', now),
      );
    } catch (e) {
      developer.log('[driver] totalTrips bump failed: $e', name: 'driver');
    }
  }

  /// Aggregates completed trips for the given driver since 00:00 today
  /// (local time, normalized to UTC for the query).
  Future<DriverDailyStats> getTodayStats(String driverId) async {
    final now = DateTime.now();
    final localMidnight = DateTime(now.year, now.month, now.day);
    final since = localMidnight.toUtc();

    final trips = await _mongo.trips();
    final cursor = trips.find(
      where
          .eq('driver_id', ObjectId.fromHexString(driverId))
          .eq('status', TripStatus.completed.name)
          .gte('completed_at', since),
    );

    var earnings = 0;
    var tripCount = 0;
    var activeMinutes = 0;
    await for (final doc in cursor) {
      earnings += (doc['price'] as num?)?.toInt() ?? 0;
      activeMinutes += (doc['duration_min'] as num?)?.toInt() ?? 0;
      tripCount += 1;
    }

    // Rating average from the driver doc itself (already maintained
    // by completeTrip in TripService).
    double ratingAvg = 0;
    final drivers = await _mongo.drivers();
    final driverDoc = await drivers.findOne(
      where.eq('_id', ObjectId.fromHexString(driverId)),
    );
    if (driverDoc != null) {
      ratingAvg = (driverDoc['rating_avg'] as num?)?.toDouble() ?? 0;
    }

    return DriverDailyStats(
      earningsVnd: earnings,
      tripCount: tripCount,
      activeMinutes: activeMinutes,
      ratingAvg: ratingAvg,
    );
  }

  /// Latest completed trips for the driver, newest first.
  Future<List<CompletedTripRow>> recentCompleted(
    String driverId, {
    int limit = 5,
  }) async {
    final trips = await _mongo.trips();
    final cursor = trips.find(
      where
          .eq('driver_id', ObjectId.fromHexString(driverId))
          .eq('status', TripStatus.completed.name)
          .sortBy('completed_at', descending: true)
          .limit(limit),
    );
    final rows = <CompletedTripRow>[];
    await for (final doc in cursor) {
      rows.add(
        CompletedTripRow(
          tripId: (doc['_id'] as ObjectId).oid,
          pickupAddress: doc['pickup_address'] as String? ?? '',
          dropoffAddress: doc['dropoff_address'] as String? ?? '',
          completedAt:
              (doc['completed_at'] as DateTime?) ??
              (doc['updated_at'] as DateTime),
          price: (doc['price'] as num?)?.toInt() ?? 0,
          distanceKm: (doc['distance_km'] as num?)?.toDouble() ?? 0,
        ),
      );
    }
    return rows;
  }

  /// Number of completed trips per weekday (Mon..Sun) over the last 7 days,
  /// ending today. Index 0 = Monday.
  Future<List<int>> weeklyTripCounts(String driverId) async {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final since = monday.toUtc();
    final trips = await _mongo.trips();
    final cursor = trips.find(
      where
          .eq('driver_id', ObjectId.fromHexString(driverId))
          .eq('status', TripStatus.completed.name)
          .gte('completed_at', since),
    );
    final counts = List<int>.filled(7, 0);
    await for (final doc in cursor) {
      final ts =
          (doc['completed_at'] as DateTime?)?.toLocal() ??
          (doc['updated_at'] as DateTime).toLocal();
      final dayIdx = ts.weekday - 1; // 0..6
      if (dayIdx >= 0 && dayIdx < 7) counts[dayIdx] += 1;
    }
    return counts;
  }
}
