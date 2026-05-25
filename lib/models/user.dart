import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'user.freezed.dart';
part 'user.g.dart';

enum UserRole { passenger, driver }

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String name,
    required String phone,
    required UserRole role,
    String? avatar,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  static User fromMongo(Map<String, dynamic> doc) => User(
    id: (doc['_id'] as ObjectId).oid,
    name: doc['name'] as String,
    phone: doc['phone'] as String,
    role: UserRole.values.byName(doc['role'] as String),
    avatar: doc['avatar'] as String?,
    createdAt: doc['created_at'] as DateTime,
    updatedAt: doc['updated_at'] as DateTime,
  );
}
