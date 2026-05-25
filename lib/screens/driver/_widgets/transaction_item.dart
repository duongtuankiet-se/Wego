import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/format.dart';
import '../../../models/transaction.dart';

class TransactionItem extends StatelessWidget {
  const TransactionItem({super.key, required this.txn});
  final WalletTxn txn;

  ({IconData icon, Color color, Color bg}) get _visual {
    if (txn.amount > 0) {
      if (txn.kind == TxnKind.bonus) {
        return (
          icon: Icons.card_giftcard,
          color: const Color(0xFFD4A574),
          bg: const Color(0xFFFFF8EC),
        );
      }
      return (
        icon: Icons.arrow_downward_rounded,
        color: AppColors.success,
        bg: AppColors.success.withValues(alpha: 0.15),
      );
    }
    return (
      icon: Icons.arrow_upward_rounded,
      color: AppColors.danger,
      bg: AppColors.danger.withValues(alpha: 0.15),
    );
  }

  String _time() {
    final dt = txn.occurredAt;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final v = _visual;
    final sign = txn.amount >= 0 ? '+' : '-';
    final amount = '$sign${formatVnd(txn.amount.abs())}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: v.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(v.icon, color: v.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.kind.label,
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
                  color: v.color,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (txn.balanceAfter != null)
                Text(
                  'Số dư ${formatVnd(txn.balanceAfter!)}',
                  style: AppTypography.micro.copyWith(color: AppColors.ink500),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
