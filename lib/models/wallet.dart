import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'wallet.freezed.dart';

/// Phase 5Q: per-user balance ledger root document. One row per Mongo
/// `users._id`; the running balance is mutated in-place by every
/// [WalletService] mutation so screens can read it cheaply without
/// recomputing from the transaction log.
@freezed
class Wallet with _$Wallet {
  const Wallet._();

  const factory Wallet({
    required String id,
    required String userId,
    required String userRole,
    @Default(0) int balance,
    @Default(0) int minBalanceRequired,
    @Default(true) bool isActive,
    @Default(0) int totalTopup,
    @Default(0) int totalSpent,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Wallet;

  /// Phase 5Q rule: drivers need ≥ [minBalanceRequired] (50k) to flip
  /// online — otherwise they can take a trip + immediately ghost.
  bool get canAcceptTrips =>
      isActive && balance >= minBalanceRequired;

  /// Default per-role min balance applied at wallet creation. Drivers
  /// need the 50k float because they receive cash from passengers;
  /// passengers pay nothing upfront.
  static int minBalanceFor(String role) => role == 'driver' ? 50000 : 0;

  static Wallet fromMongo(Map<String, dynamic> doc) => Wallet(
    id: (doc['_id'] as ObjectId).oid,
    userId: (doc['user_id'] as ObjectId).oid,
    userRole: doc['user_role'] as String,
    balance: (doc['balance'] as num?)?.toInt() ?? 0,
    minBalanceRequired:
        (doc['min_balance_required'] as num?)?.toInt() ?? 0,
    isActive: (doc['is_active'] as bool?) ?? true,
    totalTopup: (doc['total_topup'] as num?)?.toInt() ?? 0,
    totalSpent: (doc['total_spent'] as num?)?.toInt() ?? 0,
    createdAt: (doc['created_at'] as DateTime).toLocal(),
    updatedAt: (doc['updated_at'] as DateTime).toLocal(),
  );
}
