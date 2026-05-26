import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_toast.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mongo_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  String? _error;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _error = null;
      _retrying = false;
    });
    try {
      final start = DateTime.now();
      final mongo = ref.read(mongoServiceProvider);
      await mongo.getDb();
      final user = await ref.read(authStateProvider.future);

      final elapsed = DateTime.now().difference(start);
      const minSplash = Duration(seconds: 2);
      if (elapsed < minSplash) {
        await Future.delayed(minSplash - elapsed);
      }
      if (!mounted) return;
      _redirect(user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      WgToast.error(context, 'Không kết nối được MongoDB');
    }
  }

  void _redirect(User? user) {
    if (user == null) {
      context.go('/role-select');
    } else if (user.role == UserRole.driver) {
      context.go('/driver/home');
    } else {
      context.go('/passenger/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PulseLogo(controller: _pulse),
                  const SizedBox(height: 24),
                  Text(
                    'WeGo',
                    style: AppTypography.display.copyWith(
                      color: AppColors.primary500,
                      fontSize: 44,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đi chung — tiết kiệm hơn',
                    style: AppTypography.body.copyWith(color: AppColors.ink500),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Lỗi kết nối. Kiểm tra mạng và .env',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    WgButton.secondary(
                      label: _retrying ? 'Đang thử...' : 'Thử lại',
                      onPressed: _retrying
                          ? null
                          : () {
                              setState(() => _retrying = true);
                              _bootstrap();
                            },
                      leadingIcon: PhosphorIconsRegular.arrowsClockwise,
                    ),
                  ],
                ],
              ),
            ),
            if (_error == null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 32,
                child: SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(
                    backgroundColor: AppColors.ink100,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PulseLogo extends StatelessWidget {
  const _PulseLogo({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++) _ring(controller.value, i),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primary500,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsFill.mapPin,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(double t, int index) {
    final p = ((t + index * 0.33) % 1.0);
    final size = 64 + p * 96;
    final opacity = (1.0 - p).clamp(0.0, 1.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary300.withValues(alpha: opacity * 0.6),
          width: 2,
        ),
      ),
    );
  }
}
