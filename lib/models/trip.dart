import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'trip.freezed.dart';
part 'trip.g.dart';

enum TripType { private, shared }

enum TripStatus { pending, matching, accepted, ongoing, completed, cancelled }

@freezed
class Trip with _$Trip {
  const factory Trip({
    required String id,
    required String passengerId,
    String? driverId,
    required double pickupLat,
    required double pickupLng,
    required String pickupGeohash,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffGeohash,
    required String dropoffAddress,
    required double distanceKm,
    required int durationMin,
    required int price,
    @Default(TripType.private) TripType type,
    @Default(TripStatus.pending) TripStatus status,
    String? paymentMethod,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? completedAt,
  }) = _Trip;

  factory Trip.fromJson(Map<String, dynamic> json) => _$TripFromJson(json);

  static Trip fromMongo(Map<String, dynamic> doc) => Trip(
    id: (doc['_id'] as ObjectId).oid,
    passengerId: doc['passenger_id'] is ObjectId
        ? (doc['passenger_id'] as ObjectId).oid
        : doc['passenger_id'] as String,
    driverId: doc['driver_id'] is ObjectId
        ? (doc['driver_id'] as ObjectId).oid
        : doc['driver_id'] as String?,
    pickupLat: (doc['pickup_lat'] as num).toDouble(),
    pickupLng: (doc['pickup_lng'] as num).toDouble(),
    pickupGeohash: doc['pickup_geohash'] as String,
    pickupAddress: doc['pickup_address'] as String,
    dropoffLat: (doc['dropoff_lat'] as num).toDouble(),
    dropoffLng: (doc['dropoff_lng'] as num).toDouble(),
    dropoffGeohash: doc['dropoff_geohash'] as String,
    dropoffAddress: doc['dropoff_address'] as String,
    distanceKm: (doc['distance_km'] as num).toDouble(),
    durationMin: (doc['duration_min'] as num).toInt(),
    price: (doc['price'] as num).toInt(),
    type: TripType.values.byName((doc['type'] as String?) ?? 'private'),
    status: TripStatus.values.byName((doc['status'] as String?) ?? 'pending'),
    paymentMethod: doc['payment_method'] as String?,
    createdAt: doc['created_at'] as DateTime,
    updatedAt: doc['updated_at'] as DateTime,
    completedAt: doc['completed_at'] as DateTime?,
  );
}
