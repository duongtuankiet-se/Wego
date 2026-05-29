import 'dart:developer' as developer;

import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where, modify;

import '../core/db/mongo_service.dart';
import '../models/wallet.dart';
import '../models/wallet_transaction.dart';

/// Outcome of a wallet mutation — success/failure plus the post-state
/// snapshot so callers can render an immediate confirmation without a
/// follow-up read.
class WalletOpResult {
  WalletOpResult.success(this.wallet, this.transaction)
    : isSuccess = true,
      error = null;

  WalletOpResult.failure(String message)
    : isSuccess = false,
      wallet = null,
      transaction = null,
      error = message;

  final bool isSuccess;
  final Wallet? wallet;
  final WalletTransaction? transaction;
  final String? error;
}

/// Phase 5Q wallet ledger CRUD. Every mutation goes through
/// [_apply] so the wallet row and the transaction journal stay in
/// lock-step (balance_before / balance_after on the txn always match
/// the wallet row that produced it).
class WalletService {
  WalletService(this._mongo);
  final MongoService _mongo;

  Future<Wallet> getOrCreate({
    required String userId,
    required String userRole,
  }) async {
    final col = await _mongo.wallets();
    final userObjId = ObjectId.fromHexString(userId);
    final existing = await col.findOne(where.eq('user_id', userObjId));
    if (existing != null) return Wallet.fromMongo(existing);

    final now = DateTime.now().toUtc();
    final doc = <String, dynamic>{
      '_id': ObjectId(),
      'user_id': userObjId,
      'user_role': userRole,
      'balance': 0,
      'min_balance_required': Wallet.minBalanceFor(userRole),
      'is_active': true,
      'total_topup': 0,
      'total_spent': 0,
      'created_at': now,
      'updated_at': now,
    };
    await col.insertOne(doc);
    developer.log('[wallet] created for user $userId ($userRole)', name: 'wallet');
    return Wallet.fromMongo(doc);
  }

  Future<Wallet?> getByUserId(String userId) async {
    final col = await _mongo.wallets();
    final doc = await col.findOne(
      where.eq('user_id', ObjectId.fromHexString(userId)),
    );
    return doc == null ? null : Wallet.fromMongo(doc);
  }

  Future<List<WalletTransaction>> getHistory({
    required String userId,
    int limit = 30,
  }) async {
    final col = await _mongo.walletTransactions();
    final cursor = col.find(
      where
          .eq('user_id', ObjectId.fromHexString(userId))
          .sortBy('created_at', descending: true)
          .limit(limit),
    );
    final docs = await cursor.toList();
    return docs.map(WalletTransaction.fromMongo).toList(growable: false);
  }

  // ── Mutations ─────────────────────────────────────────────────────

  Future<WalletOpResult> topup({
    required String userId,
    required int amount,
    String description = 'Nạp ví',
  }) {
    return _apply(
      userId: userId,
      delta: amount.abs(),
      type: WalletTxnType.topup,
      description: description,
    );
  }

  Future<WalletOpResult> deduct({
    required String userId,
    required int amount,
    required WalletTxnType type,
    required String description,
    String? relatedTripId,
    bool allowNegative = false,
  }) {
    return _apply(
      userId: userId,
      delta: -amount.abs(),
      type: type,
      description: description,
      relatedTripId: relatedTripId,
      allowNegative: allowNegative,
    );
  }

  Future<WalletOpResult> credit({
    required String userId,
    required int amount,
    required WalletTxnType type,
    required String description,
    String? relatedTripId,
  }) {
    return _apply(
      userId: userId,
      delta: amount.abs(),
      type: type,
      description: description,
      relatedTripId: relatedTripId,
    );
  }

  Future<WalletOpResult> _apply({
    required String userId,
    required int delta,
    required WalletTxnType type,
    required String description,
    String? relatedTripId,
    bool allowNegative = false,
  }) async {
    final walletCol = await _mongo.wallets();
    final txnCol = await _mongo.walletTransactions();
    final userObjId = ObjectId.fromHexString(userId);

    final walletDoc = await walletCol.findOne(where.eq('user_id', userObjId));
    if (walletDoc == null) {
      return WalletOpResult.failure('Không tìm thấy ví của bạn');
    }
    final wallet = Wallet.fromMongo(walletDoc);
    final newBalance = wallet.balance + delta;
    if (!allowNegative && newBalance < 0) {
      return WalletOpResult.failure('Số dư ví không đủ');
    }

    final now = DateTime.now().toUtc();
    await walletCol.updateOne(
      where.id(ObjectId.fromHexString(wallet.id)),
      modify
          .set('balance', newBalance)
          .inc(
            delta > 0 ? 'total_topup' : 'total_spent',
            delta.abs(),
          )
          .set('updated_at', now),
    );

    final txnId = ObjectId();
    final txnDoc = <String, dynamic>{
      '_id': txnId,
      'wallet_id': ObjectId.fromHexString(wallet.id),
      'user_id': userObjId,
      'type': type.mongoName,
      'amount': delta,
      'balance_before': wallet.balance,
      'balance_after': newBalance,
      'related_trip_id': relatedTripId == null
          ? null
          : ObjectId.fromHexString(relatedTripId),
      'description': description,
      'status': 'completed',
      'created_at': now,
    };
    await txnCol.insertOne(txnDoc);

    final updatedWallet = wallet.copyWith(
      balance: newBalance,
      totalTopup: wallet.totalTopup + (delta > 0 ? delta : 0),
      totalSpent: wallet.totalSpent + (delta < 0 ? -delta : 0),
      updatedAt: now,
    );
    final txn = WalletTransaction.fromMongo(txnDoc);
    developer.log(
      '[wallet] ${type.mongoName} ${delta > 0 ? "+" : ""}$delta → balance $newBalance',
      name: 'wallet',
    );
    return WalletOpResult.success(updatedWallet, txn);
  }
}
