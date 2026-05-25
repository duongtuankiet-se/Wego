import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/mock_transactions.dart';
import '../models/transaction.dart';

part 'wallet_provider.g.dart';

/// Phase 2: wallet is fully mocked. Real implementation would back this
/// with a Mongo wallet ledger keyed by driver_id.
@Riverpod(keepAlive: true)
class WalletState extends _$WalletState {
  @override
  List<WalletTxn> build() => generateMockTransactions();

  int get currentBalance =>
      state.isNotEmpty ? state.first.balanceAfter ?? 1847500 : 1847500;

  int get withdrawnThisMonth {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return state
        .where(
          (t) =>
              t.kind == TxnKind.withdrawal && t.occurredAt.isAfter(monthStart),
        )
        .fold<int>(0, (sum, t) => sum + t.amount.abs());
  }
}
