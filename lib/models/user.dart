import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'user.freezed.dart';
part 'user.g.dart';

enum UserRole { passenger, driver }

/// How this account was created — drives which fields are guaranteed
/// to be present.
///   - `phone`: registered via SMS OTP (Phase 5D). `phone` is set,
///     `email` is usually null.
///   - `google`: signed in via Google OAuth (Phase 5H). `email` +
///     `avatar` set, `phone` may be null until the user adds one.
enum AuthProvider { phone, google }

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String name,
    String? phone,
    String? email,
    required UserRole role,
    String? avatar,
    String? firebaseUid,
    AuthProvider? provider,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  static User fromMongo(Map<String, dynamic> doc) => User(
    id: (doc['_id'] as ObjectId).oid,
    name: doc['name'] as String,
    phone: doc['phone'] as String?,
    email: doc['email'] as String?,
    role: UserRole.values.byName(doc['role'] as String),
    avatar: doc['avatar'] as String?,
    firebaseUid: doc['firebase_uid'] as String?,
    provider: _providerFromString(doc['provider'] as String?),
    createdAt: doc['created_at'] as DateTime,
    updatedAt: doc['updated_at'] as DateTime,
  );

  static AuthProvider? _providerFromString(String? s) {
    if (s == null) return null;
    return AuthProvider.values.firstWhere(
      (p) => p.name == s,
      orElse: () => AuthProvider.phone,
    );
  }
}
