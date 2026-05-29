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
import '../../models/wallet.dart';
import '../../models/wallet_transaction.dart';
import '../../providers/wallet_provider.dart';
import '_widgets/transaction_item.dart';

/// Driver wallet screen — Phase 5Q rebuild. Reads the Mongo-backed
/// [Wallet] + [WalletTransaction] feeds instead of the legacy mock.
/// Bank-account section is intentionally still hard-coded — wiring up
/// bank settlement is out of Phase 5Q scope.
class DriverWalletScreen extends ConsumerWidget {
  const DriverWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(currentUserWalletProvider);
    final historyAsync = ref.watch(walletHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Ví của tôi'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentUserWalletProvider);
          ref.invalidate(walletHistoryProvider);
          await Future.wait([
            ref.read(currentUserWalletProvider.future),
            ref.read(walletHistoryProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            walletAsync.when(
              loading: () => const _BalanceCardSkeleton(),
              error: (e, _) => _BalanceCardError(message: '$e'),
              data: (w) => _BalanceCard(
                wallet: w,
                onTopup: () => _showTopupSheet(context, ref),
              ),
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
            const _AccountCard(
              brand: 'M',
              brandColor: Color(0xFFA50064),
              name: 'MoMo',
              holder: 'Nguyễn Thị D · ****8821',
              isDefault: true,
            ),
            const SizedBox(height: 10),
            const _AccountCard(
              brand: 'V',
              brandColor: Color(0xFF1E8A50),
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
            historyAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Không tải được lịch sử: $e',
                  style: AppTypography.caption.copyWith(color: AppColors.danger),
                ),
              ),
              data: (txns) {
                if (txns.isEmpty) return const _EmptyHistory();
                final groups = _groupByDate(txns);
                return Column(
                  children: groups.entries
                      .map((e) => _DateGroup(label: e.key, items: e.value))
                      .toList(growable: false),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Map<String, List<WalletTransaction>> _groupByDate(
    List<WalletTransaction> items,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final out = <String, List<WalletTransaction>>{};
    for (final t in items) {
      final d = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
      String key;
      if (d == today) {
        key = 'Hôm nay';
      } else if (d == yesterday) {
        key = 'Hôm qua';
      } else {
        key =
            '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/'
            '${d.year}';
      }
      out.putIfAbsent(key, () => []).add(t);
    }
    return out;
  }

  Future<void> _showTopupSheet(BuildContext context, WidgetRef ref) async {
    final wallet = ref.read(currentUserWalletProvider).valueOrNull;
    if (wallet == null) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _TopupSheet(),
    );
    if (picked == null || !context.mounted) return;

    final svc = ref.read(walletServiceProvider);
    final result = await svc.topup(userId: wallet.userId, amount: picked);
    if (!context.mounted) return;
    if (!result.isSuccess) {
      WgToast.error(context, result.error ?? 'Nạp ví thất bại');
      return;
    }
    WgToast.success(context, 'Đã nạp ${formatVnd(picked)}');
    ref.invalidate(currentUserWalletProvider);
    ref.invalidate(walletHistoryProvider);
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet, required this.onTopup});
  final Wallet? wallet;
  final VoidCallback onTopup;

  @override
  Widget build(BuildContext context) {
    final balance = wallet?.balance ?? 0;
    final minRequired = wallet?.minBalanceRequired ?? 0;
    final canAccept = wallet?.canAcceptTrips ?? false;

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
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (minRequired > 0)
            Row(
              children: [
                Icon(
                  canAccept
                      ? PhosphorIconsFill.checkCircle
                      : PhosphorIconsFill.warning,
                  size: 14,
                  color: canAccept ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    canAccept
                        ? 'Đủ điều kiện nhận chuyến'
                        : 'Cần ≥ ${formatVnd(minRequired)} để nhận chuyến',
                    style: AppTypography.caption.copyWith(
                      color: canAccept
                          ? AppColors.success
                          : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: WgButton.primary(
                  label: 'Nạp',
                  leadingIcon: PhosphorIconsRegular.plus,
                  onPressed: wallet == null ? null : onTopup,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WgButton.secondary(
                  label: 'Rút tiền',
                  leadingIcon: PhosphorIconsRegular.paperPlaneRight,
                  onPressed: () => WgToast.info(context, 'Rút tiền sắp ra mắt'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceCardSkeleton extends StatelessWidget {
  const _BalanceCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _BalanceCardError extends StatelessWidget {
  const _BalanceCardError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(
        'Không tải được ví: $message',
        style: AppTypography.body.copyWith(color: AppColors.danger),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            PhosphorIconsRegular.receipt,
            color: AppColors.ink300,
            size: 44,
          ),
          const SizedBox(height: 10),
          Text(
            'Chưa có giao dịch nào',
            style: AppTypography.body.copyWith(color: AppColors.ink500),
          ),
        ],
      ),
    );
  }
}

class _TopupSheet extends StatelessWidget {
  const _TopupSheet();

  static const _options = [50000, 100000, 200000, 500000, 1000000];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.ink300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Chọn mệnh giá nạp',
            style: AppTypography.h2.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          ..._options.map(
            (v) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => Navigator.pop(context, v),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.ink50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.ink200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        PhosphorIconsFill.wallet,
                        color: AppColors.primary500,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        formatVnd(v),
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        PhosphorIconsRegular.caretRight,
                        size: 16,
                        color: AppColors.ink400,
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                fontWeight: FontWeight.w700,
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
  final List<WalletTransaction> items;

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
