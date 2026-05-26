import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where, modify;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/format.dart';
import '../data/mock_drivers.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
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

    // Phase 5D session restore: prefs is the source of truth for "who is
    // logged in". We treat Firebase auth state as supplementary — if it's
    // missing we still load the Mongo user (the prefs id alone is enough
    // to drive the in-app session), but we surface that mismatch only on
    // explicit signOut.
    try {
      final mongo = ref.read(mongoServiceProvider);
      final coll = await mongo.users();
      final doc = await coll.findOne(
        where.eq('_id', ObjectId.fromHexString(id)),
      );
      if (doc == null) {
        await prefs.remove(_kPrefUserId);
        await prefs.remove(_kPrefUserRole);
        await AuthService.signOut();
        return null;
      }
      return User.fromMongo(doc);
    } catch (_) {
      return null;
    }
  }

  /// Phase 5D step 1: send OTP SMS. Returns a Vietnamese error message
  /// on failure, or `null` on success.
  Future<String?> sendOtp(String rawPhone) async {
    final phone = normalizePhone(rawPhone);
    final result = await AuthService.sendOtp(phoneNumber: phone);
    return result.isSuccess ? null : result.error;
  }

  /// Phase 5D step 2: verify OTP + upsert the user in Mongo + persist
  /// the session. [name] / [role] are only consumed when creating a new
  /// user (login flow re-uses the stored values).
  ///
  /// Returns `null` on success, or a Vietnamese error message.
  Future<String?> verifyOtpAndLogin({
    required String otpCode,
    String? name,
    UserRole? role,
  }) async {
    final verify = await AuthService.verifyOtp(otpCode: otpCode);
    if (!verify.isSuccess) return verify.error;

    final firebaseUid = verify.firebaseUid!;
    final phone = verify.phoneNumber!;
    final now = DateTime.now().toUtc();

    try {
      final mongo = ref.read(mongoServiceProvider);
      final users = await mongo.users();
      final existing = await users.findOne(where.eq('phone', phone));

      Map<String, dynamic> finalDoc;
      if (existing != null) {
        // Login flow — keep stored name/role, only refresh firebase_uid.
        await users.updateOne(
          where.eq('_id', existing['_id']),
          modify.set('firebase_uid', firebaseUid).set('updated_at', now),
        );
        finalDoc = Map<String, dynamic>.from(existing)
          ..['firebase_uid'] = firebaseUid
          ..['updated_at'] = now;
      } else {
        // Register flow — name + role are required for new users.
        if (name == null || name.trim().isEmpty || role == null) {
          return 'Thiếu thông tin tên hoặc vai trò để đăng ký';
        }
        final newDoc = <String, dynamic>{
          '_id': ObjectId(),
          'name': name.trim(),
          'phone': phone,
          'role': role.name,
          'firebase_uid': firebaseUid,
          'avatar': null,
          'created_at': now,
          'updated_at': now,
        };
        await users.insertOne(newDoc);
        finalDoc = newDoc;

        if (role == UserRole.driver) {
          await _seedDriverForUser(
            userId: newDoc['_id'] as ObjectId,
            name: name.trim(),
            phone: phone,
            now: now,
          );
        }
      }

      final user = User.fromMongo(finalDoc);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefUserId, user.id);
      await prefs.setString(_kPrefUserRole, user.role.name);

      state = AsyncData(user);
      return null;
    } catch (e) {
      return 'Lưu thông tin thất bại: $e';
    }
  }

  Future<void> _seedDriverForUser({
    required ObjectId userId,
    required String name,
    required String phone,
    required DateTime now,
  }) async {
    final drivers = await ref.read(mongoServiceProvider).drivers();
    final existing = await drivers.findOne(where.eq('user_id', userId));
    if (existing != null) return;

    final vehicleIdx =
        userId.oid.codeUnits.fold<int>(0, (a, b) => a + b) %
        kMockDrivers.length;
    final v = kMockDrivers[vehicleIdx];
    await drivers.insertOne(<String, dynamic>{
      '_id': ObjectId(),
      'user_id': userId,
      'name': name,
      'phone': phone,
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
  }

  Future<void> logout() async {
    await AuthService.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefUserId);
    await prefs.remove(_kPrefUserRole);
    state = const AsyncData(null);
  }
}
