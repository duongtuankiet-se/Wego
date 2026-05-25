import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

enum TxnKind { tripIncome, withdrawal, bonus, refund }

extension TxnKindX on TxnKind {
  String get label => switch (this) {
    TxnKind.tripIncome => 'Thu nhập chuyến đi',
    TxnKind.withdrawal => 'Rút về ví',
    TxnKind.bonus => 'Thưởng',
    TxnKind.refund => 'Hoàn tiền',
  };
}

@freezed
class WalletTxn with _$WalletTxn {
  const factory WalletTxn({
    required String id,
    required TxnKind kind,
    required int amount, // positive = inflow, negative = outflow
    required String description,
    required DateTime occurredAt,
    int? balanceAfter,
  }) = _WalletTxn;

  factory WalletTxn.fromJson(Map<String, dynamic> json) =>
      _$WalletTxnFromJson(json);
}
