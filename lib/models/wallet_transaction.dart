import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme/app_colors.dart';

part 'wallet_transaction.freezed.dart';

/// Phase 5Q wallet event kinds. Positive amounts flow IN to the
/// wallet (topup, tripEarning, refund, bonus); negative amounts flow
/// OUT (withdrawal, tripPayment, commission, noShowFee). Persisted
/// snake_case in Mongo (`trip_payment`, etc).
enum WalletTxnType {
  topup,
  withdrawal,
  tripPayment,
  tripEarning,
  commission,
  refund,
  bonus,
  noShowFee,
}

extension WalletTxnTypeX on WalletTxnType {
  /// snake_case Mongo representation (e.g. `WalletTxnType.tripPayment`
  /// ⇄ `'trip_payment'`).
  String get mongoName => switch (this) {
    WalletTxnType.topup => 'topup',
    WalletTxnType.withdrawal => 'withdrawal',
    WalletTxnType.tripPayment => 'trip_payment',
    WalletTxnType.tripEarning => 'trip_earning',
    WalletTxnType.commission => 'commission',
    WalletTxnType.refund => 'refund',
    WalletTxnType.bonus => 'bonus',
    WalletTxnType.noShowFee => 'no_show_fee',
  };

  static WalletTxnType fromMongo(String raw) => switch (raw) {
    'topup' => WalletTxnType.topup,
    'withdrawal' => WalletTxnType.withdrawal,
    'trip_payment' => WalletTxnType.tripPayment,
    'trip_earning' => WalletTxnType.tripEarning,
    'commission' => WalletTxnType.commission,
    'refund' => WalletTxnType.refund,
    'bonus' => WalletTxnType.bonus,
    'no_show_fee' => WalletTxnType.noShowFee,
    _ => WalletTxnType.topup,
  };

  String get label => switch (this) {
    WalletTxnType.topup => 'Nạp ví',
    WalletTxnType.withdrawal => 'Rút ví',
    WalletTxnType.tripPayment => 'Thanh toán chuyến',
    WalletTxnType.tripEarning => 'Thu nhập chuyến',
    WalletTxnType.commission => 'Hoa hồng',
    WalletTxnType.refund => 'Hoàn tiền',
    WalletTxnType.bonus => 'Thưởng',
    WalletTxnType.noShowFee => 'Phí khách không đến',
  };

  IconData get icon => switch (this) {
    WalletTxnType.topup => PhosphorIconsRegular.arrowDown,
    WalletTxnType.withdrawal => PhosphorIconsRegular.arrowUp,
    WalletTxnType.tripPayment => PhosphorIconsRegular.arrowUp,
    WalletTxnType.tripEarning => PhosphorIconsRegular.arrowDown,
    WalletTxnType.commission => PhosphorIconsFill.percent,
    WalletTxnType.refund => PhosphorIconsRegular.arrowCounterClockwise,
    WalletTxnType.bonus => PhosphorIconsFill.gift,
    WalletTxnType.noShowFee => PhosphorIconsFill.userMinus,
  };

  /// Foreground color for the leading-icon chip; greens for inflows,
  /// reds for outflows, amber for the bonus visual flair.
  Color get color {
    switch (this) {
      case WalletTxnType.topup:
      case WalletTxnType.tripEarning:
      case WalletTxnType.refund:
        return AppColors.success;
      case WalletTxnType.bonus:
        return const Color(0xFFD4A574);
      case WalletTxnType.withdrawal:
      case WalletTxnType.tripPayment:
      case WalletTxnType.commission:
      case WalletTxnType.noShowFee:
        return AppColors.danger;
    }
  }
}

@freezed
class WalletTransaction with _$WalletTransaction {
  const WalletTransaction._();

  const factory WalletTransaction({
    required String id,
    required String walletId,
    required String userId,
    required WalletTxnType type,

    /// Signed VND. Positive = credit, negative = debit.
    required int amount,
    required int balanceBefore,
    required int balanceAfter,
    String? relatedTripId,
    required String description,
    @Default('completed') String status,
    required DateTime createdAt,
  }) = _WalletTransaction;

  bool get isCredit => amount > 0;

  static WalletTransaction fromMongo(Map<String, dynamic> doc) =>
      WalletTransaction(
        id: (doc['_id'] as ObjectId).oid,
        walletId: (doc['wallet_id'] as ObjectId).oid,
        userId: (doc['user_id'] as ObjectId).oid,
        type: WalletTxnTypeX.fromMongo(doc['type'] as String),
        amount: (doc['amount'] as num).toInt(),
        balanceBefore: (doc['balance_before'] as num).toInt(),
        balanceAfter: (doc['balance_after'] as num).toInt(),
        relatedTripId: (doc['related_trip_id'] as ObjectId?)?.oid,
        description: doc['description'] as String,
        status: (doc['status'] as String?) ?? 'completed',
        createdAt: (doc['created_at'] as DateTime).toLocal(),
      );
}
