import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/format.dart';
import '../../../models/wallet_transaction.dart';

/// One row in the driver wallet history. Phase 5Q migration: now binds
/// against the Mongo-backed [WalletTransaction] (was the legacy
/// `WalletTxn` mock model). Icon + color come from the
/// [WalletTxnTypeX] extension so the row chrome stays in sync with
/// any new transaction kinds added to the enum.
class TransactionItem extends StatelessWidget {
  const TransactionItem({super.key, required this.txn});
  final WalletTransaction txn;

  String _time() {
    final dt = txn.createdAt;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final color = txn.type.color;
    final amount = '${txn.isCredit ? "+" : "-"}${formatVnd(txn.amount.abs())}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(txn.type.icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.type.label,
                  style: AppTypography.body.copyWith(
                    color: AppColors.ink900,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${txn.description} · ${_time()}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: AppTypography.body.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'Số dư ${formatVnd(txn.balanceAfter)}',
                style: AppTypography.micro.copyWith(color: AppColors.ink500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
