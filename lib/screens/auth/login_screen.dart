import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_input.dart';
import '../../core/widgets/wg_toast.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.role});
  final UserRole role;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await ref
          .read(authStateProvider.notifier)
          .login(
            name: _nameCtrl.text,
            phone: _phoneCtrl.text,
            role: widget.role,
          );
      final auth = ref.read(authStateProvider);
      if (auth.hasError) throw auth.error!;
      if (!mounted) return;
      WgToast.success(context, 'Đăng nhập thành công');
      if (widget.role == UserRole.driver) {
        context.go('/driver/home');
      } else {
        context.go('/passenger/home');
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      WgToast.error(context, 'Lỗi: $msg');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = widget.role == UserRole.driver ? 'tài xế' : 'khách hàng';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Đăng nhập'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Nhập thông tin để bắt đầu',
                  style: AppTypography.body.copyWith(color: AppColors.ink500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bạn đang đăng nhập với vai trò $roleLabel',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),
                WgInput(
                  label: 'Họ và tên',
                  hint: 'Nguyễn Văn A',
                  controller: _nameCtrl,
                  prefixIcon: PhosphorIconsRegular.userCircle,
                  validator: Validators.validateName,
                  textInputAction: TextInputAction.next,
                  enabled: !_loading,
                ),
                const SizedBox(height: 16),
                WgInput(
                  label: 'Số điện thoại',
                  hint: '0905xxxxxx',
                  controller: _phoneCtrl,
                  variant: WgInputVariant.phone,
                  prefixIcon: PhosphorIconsRegular.phone,
                  validator: Validators.validatePhone,
                  textInputAction: TextInputAction.done,
                  enabled: !_loading,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 32),
                WgButton.primary(
                  label: 'Tiếp tục',
                  size: WgButtonSize.lg,
                  isFullWidth: true,
                  isLoading: _loading,
                  onPressed: _loading ? null : _submit,
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Bằng việc tiếp tục, bạn đồng ý với Điều khoản & Chính sách bảo mật của WeGo',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
