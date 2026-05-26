import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/wg_toast.dart';
import '../../data/mock_promos.dart';

class PassengerPromoScreen extends StatelessWidget {
  const PassengerPromoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final promos = generateMockPromos();
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(title: const Text('Ưu đãi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: AppRadius.card,
              border: Border.all(
                color: AppColors.primary500.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.tag,
                  color: AppColors.primary500,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${promos.length} mã ưu đãi đang khả dụng',
                    style: AppTypography.body.copyWith(
                      color: AppColors.primary700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...promos.map((p) => _PromoCard(promo: p)),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.promo});
  final PromoVoucher promo;

  String _expires() {
    final d = promo.expiresAt;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.md,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: promo.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(promo.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        promo.title,
                        style: AppTypography.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        promo.description,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        promo.code,
                        style: AppTypography.body.copyWith(
                          color: AppColors.ink900,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'HSD: ${_expires()}',
                        style: AppTypography.micro.copyWith(
                          color: AppColors.ink500,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await Clipboard.setData(ClipboardData(text: promo.code));
                    if (!context.mounted) return;
                    WgToast.success(context, 'Đã sao chép mã ${promo.code}');
                  },
                  icon: const Icon(PhosphorIconsRegular.copy, size: 16),
                  label: const Text('Sao chép'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
