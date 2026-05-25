import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where, modify;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/format.dart';
import '../data/mock_drivers.dart';
import '../models/user.dart';
import 'mongo_provider.dart';

part 'auth_provider.g.dart';

const _kPrefUserId = 'auth.user_id';
const _kPrefUserRole = 'auth.user_role';

@Riverpod(keepAlive: true)
class AuthState extends _$AuthState {
  @override
  Future<User?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kPrefUserId);
    if (id == null || id.isEmpty) return null;

    try {
      final mongo = ref.read(mongoServiceProvider);
      final coll = await mongo.users();
      final doc = await coll.findOne(
        where.eq('_id', ObjectId.fromHexString(id)),
      );
      if (doc == null) {
        await prefs.remove(_kPrefUserId);
        await prefs.remove(_kPrefUserRole);
        return null;
      }
      return User.fromMongo(doc);
    } catch (_) {
      return null;
    }
  }

  Future<void> login({
    required String name,
    required String phone,
    required UserRole role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final normalizedPhone = normalizePhone(phone);
      final trimmedName = name.trim();

      final mongo = ref.read(mongoServiceProvider);
      final users = await mongo.users();
      final now = DateTime.now().toUtc();

      final existing = await users.findOne(where.eq('phone', normalizedPhone));

      Map<String, dynamic> finalDoc;
      if (existing == null) {
        final newDoc = <String, dynamic>{
          '_id': ObjectId(),
          'name': trimmedName,
          'phone': normalizedPhone,
          'role': role.name,
          'avatar': null,
          'created_at': now,
          'updated_at': now,
        };
        await users.insertOne(newDoc);
        finalDoc = newDoc;
      } else {
        await users.updateOne(
          where.eq('_id', existing['_id']),
          modify
              .set('name', trimmedName)
              .set('role', role.name)
              .set('updated_at', now),
        );
        finalDoc = Map<String, dynamic>.from(existing)
          ..['name'] = trimmedName
          ..['role'] = role.name
          ..['updated_at'] = now;
      }

      // If driver, ensure a stub driver record exists with mock vehicle
      // assigned round-robin so the UI has something to display.
      if (role == UserRole.driver) {
        final drivers = await mongo.drivers();
        final userId = finalDoc['_id'] as ObjectId;
        final existingDriver = await drivers.findOne(
          where.eq('user_id', userId),
        );
        if (existingDriver == null) {
          // Pick a mock vehicle profile by hashing user-id hex to spread
          // drivers across the 3 templates deterministically.
          final vehicleIdx =
              userId.oid.codeUnits.fold<int>(0, (a, b) => a + b) %
              kMockDrivers.length;
          final v = kMockDrivers[vehicleIdx];
          await drivers.insertOne(<String, dynamic>{
            '_id': ObjectId(),
            'user_id': userId,
            'name': trimmedName,
            'phone': normalizedPhone,
            'license_number': null,
            'vehicle_model': v.vehicleModel,
            'vehicle_color': v.vehicleColor,
            'vehicle_plate': v.vehiclePlate,
            'rating_avg': 0.0,
            'total_trips': 0,
            'status': 'offline',
            'current_lat': null,
            'current_lng': null,
            'current_geohash': null,
            'created_at': now,
            'updated_at': now,
          });
        } else {
          // Keep name/phone in sync so the driver header stays correct
          // if the user edits their profile later.
          await drivers.updateOne(
            where.eq('_id', existingDriver['_id']),
            modify
                .set('name', trimmedName)
                .set('phone', normalizedPhone)
                .set('updated_at', now),
          );
        }
      }

      final user = User.fromMongo(finalDoc);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefUserId, user.id);
      await prefs.setString(_kPrefUserRole, user.role.name);

      return user;
    });
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefUserId);
    await prefs.remove(_kPrefUserRole);
    state = const AsyncData(null);
  }
}
