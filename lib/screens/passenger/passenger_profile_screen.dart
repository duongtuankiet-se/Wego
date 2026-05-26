import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/wg_avatar.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_list_tile.dart';
import '../../core/widgets/wg_toast.dart';
import '../../providers/auth_provider.dart';

class PassengerProfileScreen extends ConsumerWidget {
  const PassengerProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn sẽ phải đăng nhập lại bằng SĐT.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authStateProvider.notifier).logout();
    if (context.mounted) context.go('/role-select');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final phone = user == null ? '—' : formatPhone(user.phone);
    final maskedPhone = phone.length > 6
        ? '${phone.substring(0, 4)} *** ${phone.substring(phone.length - 3)}'
        : phone;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Tôi'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.gear),
            onPressed: () => WgToast.info(context, 'Cài đặt sắp ra mắt'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _UserCard(name: user?.name ?? 'Khách', maskedPhone: maskedPhone),
          const SizedBox(height: 20),
          _SectionTitle('Tài khoản'),
          _SettingsGroup(
            children: [
              WgListTile(
                icon: PhosphorIconsRegular.mapPin,
                title: 'Địa điểm đã lưu',
                onTap: () => WgToast.info(context, 'Tính năng đang phát triển'),
              ),
              const Divider(height: 1, color: AppColors.ink100, indent: 70),
              WgListTile(
                icon: PhosphorIconsRegular.creditCard,
                title: 'Phương thức thanh toán',
                onTap: () => WgToast.info(context, 'Tính năng đang phát triển'),
              ),
              const Divider(height: 1, color: AppColors.ink100, indent: 70),
              WgListTile(
                icon: PhosphorIconsRegular.globe,
                title: 'Ngôn ngữ',
                value: 'Tiếng Việt',
                onTap: () => WgToast.info(context, 'Đa ngôn ngữ sắp ra mắt'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionTitle('Cài đặt'),
          _SettingsGroup(
            children: [
              WgListTile(
                icon: PhosphorIconsRegular.bell,
                title: 'Thông báo',
                onTap: () => WgToast.info(context, 'Tính năng đang phát triển'),
              ),
              const Divider(height: 1, color: AppColors.ink100, indent: 70),
              WgListTile(
                icon: PhosphorIconsRegular.shield,
                title: 'Bảo mật & Quyền riêng tư',
                onTap: () => WgToast.info(context, 'Tính năng đang phát triển'),
              ),
              const Divider(height: 1, color: AppColors.ink100, indent: 70),
              WgListTile(
                icon: PhosphorIconsRegular.fileText,
                title: 'Điều khoản & Chính sách',
                onTap: () => WgToast.info(context, 'Tính năng đang phát triển'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionTitle('Hỗ trợ'),
          _SettingsGroup(
            children: [
              WgListTile(
                icon: PhosphorIconsRegular.question,
                title: 'Trung tâm trợ giúp',
                onTap: () =>
                    WgToast.info(context, 'Vào tab "Hỗ trợ" để xem FAQ'),
              ),
              const Divider(height: 1, color: AppColors.ink100, indent: 70),
              WgListTile(
                icon: PhosphorIconsRegular.phone,
                title: 'Liên hệ WeGo',
                value: '1900 1234',
                onTap: () => WgToast.info(context, 'Đang gọi 1900 1234...'),
              ),
              const Divider(height: 1, color: AppColors.ink100, indent: 70),
              WgListTile(
                icon: PhosphorIconsRegular.star,
                title: 'Đánh giá ứng dụng',
                onTap: () => WgToast.info(context, 'Cảm ơn bạn yêu WeGo!'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          WgButton.secondary(
            label: 'Đăng xuất',
            leadingIcon: PhosphorIconsRegular.signOut,
            isFullWidth: true,
            onPressed: () => _confirmLogout(context, ref),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'WeGo v0.1.0',
              style: AppTypography.caption.copyWith(color: AppColors.ink400),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.name, required this.maskedPhone});
  final String name;
  final String maskedPhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.md,
      ),
      child: Column(
        children: [
          WgAvatar(name: name, size: 80),
          const SizedBox(height: 14),
          Text(
            name,
            style: AppTypography.h1.copyWith(fontSize: 22),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            maskedPhone,
            style: AppTypography.body.copyWith(
              color: AppColors.ink500,
              fontFamily: 'monospace',
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 16),
            label: const Text('Chỉnh sửa hồ sơ'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary500,
              side: BorderSide(
                color: AppColors.primary500.withValues(alpha: 0.3),
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.button,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.micro.copyWith(
          color: AppColors.ink500,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.sm,
      ),
      child: Column(children: children),
    );
  }
}
