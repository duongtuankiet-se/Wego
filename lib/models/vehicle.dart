import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'vehicle.freezed.dart';
part 'vehicle.g.dart';

enum VehicleType { car4, car7, motorbike }

@freezed
class Vehicle with _$Vehicle {
  const factory Vehicle({
    required String id,
    required String driverId,
    required String plate,
    required String model,
    String? color,
    @Default(4) int seats,
    @Default(VehicleType.car4) VehicleType type,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Vehicle;

  factory Vehicle.fromJson(Map<String, dynamic> json) =>
      _$VehicleFromJson(json);

  static Vehicle fromMongo(Map<String, dynamic> doc) => Vehicle(
    id: (doc['_id'] as ObjectId).oid,
    driverId: doc['driver_id'] is ObjectId
        ? (doc['driver_id'] as ObjectId).oid
        : doc['driver_id'] as String,
    plate: doc['plate'] as String,
    model: doc['model'] as String,
    color: doc['color'] as String?,
    seats: (doc['seats'] as num?)?.toInt() ?? 4,
    type: VehicleType.values.byName((doc['type'] as String?) ?? 'car4'),
    createdAt: doc['created_at'] as DateTime,
    updatedAt: doc['updated_at'] as DateTime,
  );
}
