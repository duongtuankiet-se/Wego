import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'driver.freezed.dart';
part 'driver.g.dart';

/// Driver lifecycle status. `pending/active/suspended` are admin-side
/// (account approval); `offline/online/busy` are runtime dispatch states.
enum DriverStatus { pending, active, suspended, offline, online, busy }

@freezed
class Driver with _$Driver {
  const factory Driver({
    required String id,
    required String userId,
    String? name,
    String? phone,
    String? licenseNumber,
    String? vehicleModel,
    String? vehicleColor,
    String? vehiclePlate,
    @Default(0.0) double ratingAvg,
    @Default(0) int totalTrips,
    @Default(DriverStatus.offline) DriverStatus status,
    double? currentLat,
    double? currentLng,
    String? currentGeohash,
    // ── Phase 5R: outstanding trip offer ─────────────────────────────
    // When non-null the driver is currently considering a 15s offer
    // for the referenced scheduled trip. Used as the atomic "busy with
    // offer" signal so the search job doesn't double-book them.
    String? currentOfferTripId,
    DateTime? currentOfferExpiresAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Driver;

  factory Driver.fromJson(Map<String, dynamic> json) => _$DriverFromJson(json);

  static Driver fromMongo(Map<String, dynamic> doc) => Driver(
    id: (doc['_id'] as ObjectId).oid,
    userId: doc['user_id'] is ObjectId
        ? (doc['user_id'] as ObjectId).oid
        : doc['user_id'] as String,
    name: doc['name'] as String?,
    phone: doc['phone'] as String?,
    licenseNumber: doc['license_number'] as String?,
    vehicleModel: doc['vehicle_model'] as String?,
    vehicleColor: doc['vehicle_color'] as String?,
    vehiclePlate: doc['vehicle_plate'] as String?,
    ratingAvg: (doc['rating_avg'] as num?)?.toDouble() ?? 0.0,
    totalTrips: (doc['total_trips'] as num?)?.toInt() ?? 0,
    status: DriverStatus.values.byName((doc['status'] as String?) ?? 'offline'),
    currentLat: (doc['current_lat'] as num?)?.toDouble(),
    currentLng: (doc['current_lng'] as num?)?.toDouble(),
    currentGeohash: doc['current_geohash'] as String?,
    currentOfferTripId: (doc['current_offer_trip_id'] as ObjectId?)?.oid,
    currentOfferExpiresAt:
        (doc['current_offer_expires_at'] as DateTime?)?.toLocal(),
    createdAt: doc['created_at'] as DateTime,
    updatedAt: doc['updated_at'] as DateTime,
  );
}
