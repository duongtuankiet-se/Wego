import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/wg_avatar.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_list_tile.dart';
import '../../core/widgets/wg_toast.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_provider.dart';

class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

  static const _gold = Color(0xFFD4A574);

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text(
          'Bạn sẽ ngừng nhận chuyến và phải đăng nhập lại để tiếp tục.',
        ),
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
    final driver = ref.watch(currentDriverProvider).valueOrNull;
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(title: const Text('Tôi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: AppRadius.card,
              boxShadow: AppShadows.md,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  height: 36,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_gold, Color(0xFFB8915E)],
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'TÀI XẾ KIM CƯƠNG',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      WgAvatar(
                        name: driver?.name ?? 'Tài xế',
                        size: 80,
                        rating: driver?.ratingAvg.toDouble(),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        driver?.name ?? 'Tài xế WeGo',
                        style: AppTypography.h1.copyWith(fontSize: 22),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        driver?.vehiclePlate ?? '— · —',
                        style: AppTypography.body.copyWith(
                          color: AppColors.ink500,
                          fontFamily: 'monospace',
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            PhosphorIconsFill.star,
                            color: AppColors.warning,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${driver?.ratingAvg.toStringAsFixed(2) ?? "—"} · '
                            '${driver?.totalTrips ?? 0} chuyến',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.ink500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle('Phương tiện'),
          _Group(
            children: [
              WgListTile(
                icon: PhosphorIconsRegular.car,
                title: driver?.vehicleModel ?? 'Xe',
                subtitle:
                    '${driver?.vehicleColor ?? "—"} · ${driver?.vehiclePlate ?? "—"}',
                onTap: () => WgToast.info(context, 'Chỉnh sửa xe sắp ra mắt'),
              ),
              const Divider(height: 1, color: AppColors.ink100, indent: 70),
              WgListTile(
                icon: PhosphorIconsRegular.fileText,
                title: 'Giấy tờ & Đăng ký',
                value: 'Đã xác minh',
                onTap: () => WgToast.info(context, 'Tài liệu sắp ra mắt'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionTitle('Cài đặt'),
          _Group(
            children: [
              WgListTile(
                icon: PhosphorIconsRegular.bell,
                title: 'Thông báo',
                onTap: () => WgToast.info(context, 'Sắp ra mắt'),
              ),
              const Divider(height: 1, color: AppColors.ink100, indent: 70),
              WgListTile(
                icon: PhosphorIconsRegular.shield,
                title: 'Bảo mật',
                onTap: () => WgToast.info(context, 'Sắp ra mắt'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionTitle('Hỗ trợ'),
          _Group(
            children: [
              WgListTile(
                icon: PhosphorIconsRegular.question,
                title: 'Trung tâm trợ giúp tài xế',
                onTap: () => WgToast.info(context, 'Sắp ra mắt'),
              ),
              const Divider(height: 1, color: AppColors.ink100, indent: 70),
              WgListTile(
                icon: PhosphorIconsRegular.phone,
                title: 'Hotline tài xế',
                value: '1900 5678',
                onTap: () => WgToast.info(context, 'Đang gọi 1900 5678...'),
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
              'WeGo Driver v0.1.0',
              style: AppTypography.caption.copyWith(color: AppColors.ink400),
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

class _Group extends StatelessWidget {
  const _Group({required this.children});
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
