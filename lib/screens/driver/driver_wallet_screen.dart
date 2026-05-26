import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/wg_badge.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_toast.dart';
import '../../models/transaction.dart';
import '../../providers/wallet_provider.dart';
import '_widgets/transaction_item.dart';

class DriverWalletScreen extends ConsumerWidget {
  const DriverWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletStateProvider);
    final state = ref.read(walletStateProvider.notifier);
    final groups = _groupByDate(wallet);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Ví của tôi'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BalanceCard(
            balance: state.currentBalance,
            withdrawnThisMonth: state.withdrawnThisMonth,
          ),
          const SizedBox(height: 16),
          Text(
            'Tài khoản liên kết',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.ink900,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _AccountCard(
            brand: 'M',
            brandColor: const Color(0xFFA50064),
            name: 'MoMo',
            holder: 'Nguyễn Thị D · ****8821',
            isDefault: true,
          ),
          const SizedBox(height: 10),
          _AccountCard(
            brand: 'V',
            brandColor: const Color(0xFF1E8A50),
            name: 'Vietcombank',
            holder: 'VCB · ****4419',
            isDefault: false,
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => WgToast.info(context, 'Thêm tài khoản sắp ra mắt'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary500.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.plusCircle,
                    color: AppColors.primary500,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Thêm tài khoản',
                    style: AppTypography.body.copyWith(
                      color: AppColors.primary700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Lịch sử giao dịch',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.ink900,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...groups.entries.map(
            (e) => _DateGroup(label: e.key, items: e.value),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Map<String, List<WalletTxn>> _groupByDate(List<WalletTxn> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final out = <String, List<WalletTxn>>{};
    for (final t in items) {
      final d = DateTime(
        t.occurredAt.year,
        t.occurredAt.month,
        t.occurredAt.day,
      );
      String key;
      if (d == today) {
        key = 'Hôm nay';
      } else if (d == yesterday) {
        key = 'Hôm qua';
      } else {
        key =
            '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      }
      out.putIfAbsent(key, () => []).add(t);
    }
    return out;
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.withdrawnThisMonth});
  final int balance;
  final int withdrawnThisMonth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink900.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Số dư khả dụng',
            style: AppTypography.body.copyWith(
              color: AppColors.ink500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: balance.toDouble()),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              formatVnd(v.round()),
              style: AppTypography.display.copyWith(
                color: AppColors.ink900,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Đã rút trong tháng: ${formatVnd(withdrawnThisMonth)}',
            style: AppTypography.caption.copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: WgButton.primary(
                  label: 'Rút tiền',
                  leadingIcon: PhosphorIconsRegular.paperPlaneRight,
                  onPressed: () => WgToast.info(context, 'Rút tiền sắp ra mắt'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WgButton.secondary(
                  label: 'Nạp',
                  leadingIcon: PhosphorIconsRegular.plus,
                  onPressed: () => WgToast.info(context, 'Nạp tiền sắp ra mắt'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.brand,
    required this.brandColor,
    required this.name,
    required this.holder,
    required this.isDefault,
  });
  final String brand;
  final Color brandColor;
  final String name;
  final String holder;
  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: brandColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              brand,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      const WgBadge(
                        label: 'Mặc định',
                        variant: WgBadgeVariant.success,
                      ),
                    ],
                  ],
                ),
                Text(
                  holder,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              PhosphorIconsRegular.x,
              color: AppColors.ink500,
              size: 20,
            ),
            onPressed: () => WgToast.info(context, 'Quản lý sắp ra mắt'),
          ),
        ],
      ),
    );
  }
}

class _DateGroup extends StatelessWidget {
  const _DateGroup({required this.label, required this.items});
  final String label;
  final List<WalletTxn> items;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (s, t) => s + t.amount);
    final sign = total >= 0 ? '+' : '-';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.caretDown,
                  color: AppColors.ink500,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  'Tổng: $sign${formatVnd(total.abs())}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: List.generate(items.length, (i) {
                return Column(
                  children: [
                    TransactionItem(txn: items[i]),
                    if (i < items.length - 1)
                      const Divider(
                        height: 1,
                        color: AppColors.ink100,
                        indent: 58,
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
