import 'dart:developer' as developer;

import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where, modify;

import '../core/db/mongo_service.dart';
import '../models/driver.dart';
import '../models/driver_vehicle.dart';

/// CRUD for the `driver_vehicles` collection introduced in Phase 5N.
///
/// One driver can have many vehicles; the pool-accept flow needs to know
/// which specific vehicle the driver is using for a given pool because
/// pool size (4 vs 7 seats) must match the vehicle.
class DriverVehicleService {
  DriverVehicleService(this._mongo);
  final MongoService _mongo;

  Future<List<DriverVehicle>> getDriverVehicles(String driverId) async {
    final col = await _mongo.driverVehicles();
    final cursor = col.find(
      where
          .eq('driver_id', ObjectId.fromHexString(driverId))
          .eq('is_active', true)
          .sortBy('is_primary', descending: true)
          .sortBy('created_at'),
    );
    final docs = await cursor.toList();
    return docs.map(DriverVehicle.fromMongo).toList(growable: false);
  }

  Future<DriverVehicle?> getPrimaryVehicle(String driverId) async {
    final col = await _mongo.driverVehicles();
    final doc = await col.findOne(
      where
          .eq('driver_id', ObjectId.fromHexString(driverId))
          .eq('is_active', true)
          .eq('is_primary', true),
    );
    return doc == null ? null : DriverVehicle.fromMongo(doc);
  }

  Future<DriverVehicle?> getById(String vehicleId) async {
    final col = await _mongo.driverVehicles();
    final doc = await col.findOne(
      where.id(ObjectId.fromHexString(vehicleId)),
    );
    return doc == null ? null : DriverVehicle.fromMongo(doc);
  }

  /// Returns vehicles matching exactly [seats] — used when offering the
  /// driver a vehicle picker for a pool that needs e.g. a 7-seater.
  Future<List<DriverVehicle>> getVehiclesBySeats({
    required String driverId,
    required int seats,
  }) async {
    final col = await _mongo.driverVehicles();
    final cursor = col.find(
      where
          .eq('driver_id', ObjectId.fromHexString(driverId))
          .eq('is_active', true)
          .eq('vehicle_seats', seats)
          .sortBy('is_primary', descending: true),
    );
    final docs = await cursor.toList();
    return docs.map(DriverVehicle.fromMongo).toList(growable: false);
  }

  Future<DriverVehicle> addVehicle({
    required String driverId,
    required int vehicleSeats,
    required VehicleType vehicleType,
    required String vehiclePlate,
    required VehicleColor vehicleColor,
    bool isPrimary = false,
  }) async {
    final col = await _mongo.driverVehicles();
    final now = DateTime.now().toUtc();
    final driverObjId = ObjectId.fromHexString(driverId);

    // If this is the very first vehicle for the driver, auto-mark it
    // primary regardless of the caller's preference — otherwise the
    // driver would have no default vehicle for pool offers.
    final existingCount = await col.count(
      where.eq('driver_id', driverObjId).eq('is_active', true),
    );
    final shouldBePrimary = isPrimary || existingCount == 0;

    if (shouldBePrimary) {
      await col.updateMany(
        where.eq('driver_id', driverObjId),
        modify.set('is_primary', false),
      );
    }

    final id = ObjectId();
    final doc = <String, dynamic>{
      '_id': id,
      'driver_id': driverObjId,
      'vehicle_seats': vehicleSeats,
      'vehicle_type': vehicleType.name,
      'vehicle_plate': vehiclePlate,
      'vehicle_color': vehicleColor.name,
      'is_active': true,
      'is_primary': shouldBePrimary,
      'created_at': now,
      'updated_at': now,
    };
    await col.insertOne(doc);
    developer.log('[vehicle] add ${vehicleType.name} $vehiclePlate', name: 'vehicle');
    return DriverVehicle.fromMongo(doc);
  }

  Future<bool> updateVehicle({
    required String vehicleId,
    required int vehicleSeats,
    required VehicleType vehicleType,
    required String vehiclePlate,
    required VehicleColor vehicleColor,
  }) async {
    final col = await _mongo.driverVehicles();
    final res = await col.updateOne(
      where.id(ObjectId.fromHexString(vehicleId)),
      modify
          .set('vehicle_seats', vehicleSeats)
          .set('vehicle_type', vehicleType.name)
          .set('vehicle_plate', vehiclePlate)
          .set('vehicle_color', vehicleColor.name)
          .set('updated_at', DateTime.now().toUtc()),
    );
    return res.isSuccess && res.nModified > 0;
  }

  Future<bool> setPrimary({
    required String vehicleId,
    required String driverId,
  }) async {
    final col = await _mongo.driverVehicles();
    final now = DateTime.now().toUtc();
    await col.updateMany(
      where.eq('driver_id', ObjectId.fromHexString(driverId)),
      modify.set('is_primary', false),
    );
    final res = await col.updateOne(
      where.id(ObjectId.fromHexString(vehicleId)),
      modify.set('is_primary', true).set('updated_at', now),
    );
    return res.isSuccess && res.nModified > 0;
  }

  /// Soft-delete: clears [DriverVehicle.isActive] so existing pool refs
  /// don't dangle.
  Future<bool> deleteVehicle(String vehicleId) async {
    final col = await _mongo.driverVehicles();
    final res = await col.updateOne(
      where.id(ObjectId.fromHexString(vehicleId)),
      modify
          .set('is_active', false)
          .set('is_primary', false)
          .set('updated_at', DateTime.now().toUtc()),
    );
    return res.isSuccess && res.nModified > 0;
  }

  /// Phase 5N migration helper: if the driver has zero vehicles in the
  /// new collection but has the legacy inline fields on their Driver
  /// doc (`vehicleModel/Color/Plate`), seed one so they can immediately
  /// accept pools. Returns the seeded vehicle, or null if there was
  /// nothing to seed.
  Future<DriverVehicle?> seedFromLegacyDriverIfEmpty(Driver driver) async {
    final existing = await getDriverVehicles(driver.id);
    if (existing.isNotEmpty) return null;

    final plate = driver.vehiclePlate?.trim();
    if (plate == null || plate.isEmpty) return null;

    return addVehicle(
      driverId: driver.id,
      vehicleSeats: _guessSeatsFromModel(driver.vehicleModel),
      vehicleType: _guessTypeFromModel(driver.vehicleModel),
      vehiclePlate: plate,
      vehicleColor: _guessColorFromString(driver.vehicleColor),
      isPrimary: true,
    );
  }

  int _guessSeatsFromModel(String? model) {
    if (model == null) return 4;
    final m = model.toLowerCase();
    if (m.contains('innova') ||
        m.contains('xpander') ||
        m.contains('carnival') ||
        m.contains('fortuner') ||
        m.contains('staria')) {
      return 7;
    }
    return 4;
  }

  VehicleType _guessTypeFromModel(String? model) {
    if (model == null) return VehicleType.other;
    final m = model.toLowerCase();
    if (m.contains('vios')) return VehicleType.vios;
    if (m.contains('innova')) return VehicleType.innova;
    if (m.contains('xpander')) return VehicleType.xpander;
    if (m.contains('carnival')) return VehicleType.carnival;
    if (m.contains('fortuner')) return VehicleType.fortuner;
    return VehicleType.other;
  }

  VehicleColor _guessColorFromString(String? color) {
    if (color == null) return VehicleColor.other;
    final c = color.toLowerCase().trim();
    if (c.contains('trắng') || c.contains('trang') || c == 'white') {
      return VehicleColor.white;
    }
    if (c.contains('đen') || c.contains('den') || c == 'black') {
      return VehicleColor.black;
    }
    if (c.contains('xám') || c.contains('xam') || c == 'gray' || c == 'grey') {
      return VehicleColor.gray;
    }
    if (c.contains('bạc') || c.contains('bac') || c == 'silver') {
      return VehicleColor.silver;
    }
    if (c.contains('đỏ') || c.contains('do') || c == 'red') {
      return VehicleColor.red;
    }
    if (c.contains('xanh') || c == 'blue') return VehicleColor.blue;
    return VehicleColor.other;
  }
}
