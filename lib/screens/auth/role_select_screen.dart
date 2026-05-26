import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/wg_card.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => context.go('/passenger/home'),
            child: Text(
              'Bỏ qua',
              style: AppTypography.caption.copyWith(
                color: AppColors.ink500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Bạn dùng WeGo với\nvai trò nào?',
                style: AppTypography.display.copyWith(fontSize: 30),
              ),
              const SizedBox(height: 8),
              Text(
                'Chọn một trong hai để bắt đầu',
                style: AppTypography.body.copyWith(color: AppColors.ink500),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _RoleCard(
                icon: PhosphorIconsFill.user,
                title: 'Tôi là khách hàng',
                subtitle: 'Đặt xe nhanh, đi ghép tiết kiệm',
                onTap: () => context.push('/login?role=passenger'),
              ),
              const SizedBox(height: AppSpacing.lg),
              _RoleCard(
                icon: PhosphorIconsFill.car,
                title: 'Tôi là tài xế',
                subtitle: 'Nhận chuyến, tăng thu nhập',
                onTap: () => context.push('/login?role=driver'),
              ),
              const Spacer(),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/login?role=passenger'),
                  child: Text(
                    'Đã có tài khoản? Đăng nhập',
                    style: AppTypography.body.copyWith(
                      color: AppColors.primary700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WgCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: SizedBox(
        height: 96,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.primary100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary700, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: AppTypography.h2.copyWith(fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.body.copyWith(
                      color: AppColors.ink500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              PhosphorIconsRegular.caretRight,
              color: AppColors.ink500,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
