import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'driver_vehicle.freezed.dart';

enum VehicleType { vios, innova, xpander, carnival, fortuner, other }

enum VehicleColor { white, black, gray, silver, red, blue, other }

extension VehicleTypeLabel on VehicleType {
  String get label => switch (this) {
    VehicleType.vios => 'Toyota Vios',
    VehicleType.innova => 'Toyota Innova',
    VehicleType.xpander => 'Mitsubishi Xpander',
    VehicleType.carnival => 'Kia Carnival',
    VehicleType.fortuner => 'Toyota Fortuner',
    VehicleType.other => 'Khác',
  };
}

extension VehicleColorLabel on VehicleColor {
  String get label => switch (this) {
    VehicleColor.white => 'Trắng',
    VehicleColor.black => 'Đen',
    VehicleColor.gray => 'Xám',
    VehicleColor.silver => 'Bạc',
    VehicleColor.red => 'Đỏ',
    VehicleColor.blue => 'Xanh',
    VehicleColor.other => 'Khác',
  };
}

@freezed
class DriverVehicle with _$DriverVehicle {
  const DriverVehicle._();

  const factory DriverVehicle({
    required String id,
    required String driverId,
    required int vehicleSeats,
    required VehicleType vehicleType,
    required String vehiclePlate,
    required VehicleColor vehicleColor,
    @Default(true) bool isActive,
    @Default(false) bool isPrimary,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _DriverVehicle;

  String get displayName =>
      '${vehicleType.label} $vehicleSeats chỗ · ${vehicleColor.label}';

  static DriverVehicle fromMongo(Map<String, dynamic> doc) => DriverVehicle(
    id: (doc['_id'] as ObjectId).oid,
    driverId: (doc['driver_id'] as ObjectId).oid,
    vehicleSeats: (doc['vehicle_seats'] as num).toInt(),
    vehicleType: VehicleType.values.byName(
      (doc['vehicle_type'] as String?) ?? 'other',
    ),
    vehiclePlate: doc['vehicle_plate'] as String,
    vehicleColor: VehicleColor.values.byName(
      (doc['vehicle_color'] as String?) ?? 'other',
    ),
    isActive: (doc['is_active'] as bool?) ?? true,
    isPrimary: (doc['is_primary'] as bool?) ?? false,
    createdAt: (doc['created_at'] as DateTime).toLocal(),
    updatedAt: (doc['updated_at'] as DateTime).toLocal(),
  );
}
