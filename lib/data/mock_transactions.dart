import '../models/transaction.dart';

/// Generates mock transaction history relative to "today" so the wallet
/// always shows fresh dates regardless of when the demo runs.
List<WalletTxn> generateMockTransactions() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var balance = 1847500;

  WalletTxn t(
    int daysAgo,
    int hour,
    int minute,
    TxnKind k,
    int amount,
    String desc,
  ) {
    balance += amount;
    return WalletTxn(
      id: 't_${daysAgo}_$hour$minute',
      kind: k,
      amount: amount,
      description: desc,
      occurredAt: today
          .subtract(Duration(days: daysAgo))
          .add(Duration(hours: hour, minutes: minute)),
      balanceAfter: balance,
    );
  }

  // Build chronologically oldest-first then reverse so balanceAfter stacks
  // correctly, and the consumer can group by date.
  final items = <WalletTxn>[
    t(2, 8, 15, TxnKind.tripIncome, 72000, 'Lê Lợi → Bãi biển Mỹ Khê'),
    t(2, 11, 30, TxnKind.tripIncome, 58000, 'Vincom → Đại học Duy Tân'),
    t(2, 21, 0, TxnKind.withdrawal, -1000000, 'Rút về Vietcombank ***4419'),
    t(1, 9, 12, TxnKind.tripIncome, 85000, 'Sân bay → Khách sạn Mường Thanh'),
    t(1, 14, 5, TxnKind.bonus, 200000, 'Thưởng chăm chỉ 20 chuyến'),
    t(1, 19, 40, TxnKind.tripIncome, 63000, 'Chợ Hàn → Cầu Sông Hàn'),
    t(0, 9, 32, TxnKind.tripIncome, 78000, 'Trần Phú → Sân bay Đà Nẵng'),
    t(0, 10, 15, TxnKind.tripIncome, 45000, 'Vincom → ĐH Duy Tân'),
    t(0, 11, 48, TxnKind.tripIncome, 52000, 'Cầu Rồng → Lotte Mart'),
    t(0, 21, 0, TxnKind.withdrawal, -500000, 'Rút về MoMo ***8821'),
  ];
  return items.reversed.toList();
}
