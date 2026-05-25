import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'driver.freezed.dart';
part 'driver.g.dart';

enum DriverStatus { pending, active, suspended }

@freezed
class Driver with _$Driver {
  const factory Driver({
    required String id,
    required String userId,
    String? licenseNumber,
    @Default(0.0) double ratingAvg,
    @Default(0) int totalTrips,
    @Default(DriverStatus.pending) DriverStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Driver;

  factory Driver.fromJson(Map<String, dynamic> json) => _$DriverFromJson(json);

  static Driver fromMongo(Map<String, dynamic> doc) => Driver(
    id: (doc['_id'] as ObjectId).oid,
    userId: doc['user_id'] is ObjectId
        ? (doc['user_id'] as ObjectId).oid
        : doc['user_id'] as String,
    licenseNumber: doc['license_number'] as String?,
    ratingAvg: (doc['rating_avg'] as num?)?.toDouble() ?? 0.0,
    totalTrips: (doc['total_trips'] as num?)?.toInt() ?? 0,
    status: DriverStatus.values.byName((doc['status'] as String?) ?? 'pending'),
    createdAt: doc['created_at'] as DateTime,
    updatedAt: doc['updated_at'] as DateTime,
  );
}
