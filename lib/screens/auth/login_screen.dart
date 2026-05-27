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
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '_widgets/auth_header.dart';
import '_widgets/google_sign_in_button.dart';

/// Login (Phase 5D phone-only + Phase 5H Google). For accounts already
/// in Mongo, name + role come from the stored doc. Google sign-in
/// defaults brand-new accounts to the Passenger role; existing users
/// keep their stored role.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;

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

  Future<void> _handleGoogle() async {
    setState(() => _googleLoading = true);

    final error = await ref
        .read(authStateProvider.notifier)
        .signInWithGoogleAndLogin(defaultRole: UserRole.passenger);

    if (!mounted) return;
    setState(() => _googleLoading = false);

    if (error != null) {
      WgToast.error(context, error);
      return;
    }

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      WgToast.error(context, 'Không tải được tài khoản');
      return;
    }

    if (user.role == UserRole.driver) {
      context.go('/driver/home');
    } else {
      context.go('/passenger/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final anyLoading = _loading || _googleLoading;
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
                  subtitle: 'Nhập số điện thoại hoặc đăng nhập với Google',
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
                  enabled: !anyLoading,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                WgButton.primary(
                  label: 'Tiếp tục',
                  size: WgButtonSize.lg,
                  isFullWidth: true,
                  isLoading: _loading,
                  onPressed: anyLoading ? null : _submit,
                ),
                const SizedBox(height: 24),
                const _OrDivider(),
                const SizedBox(height: 16),
                GoogleSignInButton(
                  loading: _googleLoading,
                  enabled: !anyLoading,
                  onPressed: _handleGoogle,
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: anyLoading
                        ? null
                        : () => context.go('/register'),
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.ink200, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'hoặc',
            style: AppTypography.caption.copyWith(color: AppColors.ink400),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.ink200, thickness: 1)),
      ],
    );
  }
}

