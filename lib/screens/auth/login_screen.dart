import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_input.dart';
import '../../core/widgets/wg_toast.dart';
import '../../providers/auth_provider.dart';
import '_widgets/auth_header.dart';

/// Phone-only login (Phase 5D). For accounts already in Mongo, name +
/// role come from the stored doc — we only re-verify the phone via OTP.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final phoneE164 = normalizePhone(_phoneCtrl.text);
    final error = await ref.read(authStateProvider.notifier).sendOtp(phoneE164);

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      WgToast.error(context, error);
      return;
    }

    context.push(
      '/verify-otp',
      extra: <String, Object>{'phone': phoneE164, 'isRegister': false},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
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
            child: ListView(
              children: [
                WgAuthHeader.text(
                  title: 'Chào mừng trở lại',
                  subtitle: 'Nhập số điện thoại để nhận mã OTP',
                ),
                const SizedBox(height: 28),
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
                const SizedBox(height: 28),
                WgButton.primary(
                  label: 'Tiếp tục',
                  size: WgButtonSize.lg,
                  isFullWidth: true,
                  isLoading: _loading,
                  onPressed: _loading ? null : _submit,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : () => context.go('/register'),
                    child: RichText(
                      text: TextSpan(
                        style: AppTypography.body.copyWith(
                          color: AppColors.ink500,
                        ),
                        children: [
                          const TextSpan(text: 'Chưa có tài khoản? '),
                          TextSpan(
                            text: 'Đăng ký',
                            style: AppTypography.body.copyWith(
                              color: AppColors.primary500,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
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
