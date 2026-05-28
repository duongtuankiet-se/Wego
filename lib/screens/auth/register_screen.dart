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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.initialRole = UserRole.passenger});
  final UserRole initialRole;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  late UserRole _role;
  bool _loading = false;
  bool _googleLoading = false;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
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
      extra: <String, Object>{
        'phone': phoneE164,
        'isRegister': true,
        'name': _nameCtrl.text.trim(),
        'role': _role,
      },
    );
  }

  Future<void> _handleGoogle() async {
    setState(() => _googleLoading = true);

    final result = await ref
        .read(authStateProvider.notifier)
        .signInWithGoogleAndLogin(defaultRole: _role);

    if (!mounted) return;
    setState(() => _googleLoading = false);

    if (result.error != null) {
      WgToast.error(context, result.error!);
      return;
    }

    // Phase 5P: divert to CompleteProfile when the freshly-signed-in
    // Google user has no phone yet.
    if (result.needPhone) {
      context.go('/complete-profile');
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
        title: const Text('Đăng ký'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                WgAuthHeader.text(
                  title: 'Tạo tài khoản WeGo',
                  subtitle: 'Đăng ký nhanh với số điện thoại',
                ),
                const SizedBox(height: 28),
                WgInput(
                  label: 'Họ và tên',
                  hint: 'Nguyễn Văn A',
                  controller: _nameCtrl,
                  prefixIcon: PhosphorIconsRegular.userCircle,
                  validator: Validators.validateName,
                  textInputAction: TextInputAction.next,
                  enabled: !anyLoading,
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
                  enabled: !anyLoading,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                Text(
                  'Bạn là',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink900,
                  ),
                ),
                const SizedBox(height: 10),
                _RoleSelector(
                  selected: _role,
                  onChanged: (r) => setState(() => _role = r),
                  enabled: !anyLoading,
                ),
                const SizedBox(height: 28),
                WgButton.primary(
                  label: 'Tiếp tục',
                  size: WgButtonSize.lg,
                  isFullWidth: true,
                  isLoading: _loading,
                  onPressed: anyLoading ? null : _submit,
                ),
                const SizedBox(height: 20),
                const _OrDivider(),
                const SizedBox(height: 16),
                GoogleSignInButton(
                  loading: _googleLoading,
                  enabled: !anyLoading,
                  onPressed: _handleGoogle,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: anyLoading ? null : () => context.go('/login'),
                    child: RichText(
                      text: TextSpan(
                        style: AppTypography.body.copyWith(
                          color: AppColors.ink500,
                        ),
                        children: [
                          const TextSpan(text: 'Đã có tài khoản? '),
                          TextSpan(
                            text: 'Đăng nhập',
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
                const SizedBox(height: 8),
                Text(
                  'Bằng việc tiếp tục, bạn đồng ý với Điều khoản & Chính '
                  'sách bảo mật của WeGo',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
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

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.selected,
    required this.onChanged,
    required this.enabled,
  });

  final UserRole selected;
  final ValueChanged<UserRole> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleCard(
            role: UserRole.passenger,
            label: 'Hành khách',
            icon: PhosphorIconsFill.userCircle,
            selected: selected == UserRole.passenger,
            enabled: enabled,
            onTap: () => onChanged(UserRole.passenger),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RoleCard(
            role: UserRole.driver,
            label: 'Tài xế',
            icon: PhosphorIconsFill.steeringWheel,
            selected: selected == UserRole.driver,
            enabled: enabled,
            onTap: () => onChanged(UserRole.driver),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final UserRole role;
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: selected ? AppColors.primary50 : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.primary500 : AppColors.ink200,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? AppColors.primary500 : AppColors.ink500,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primary700 : AppColors.ink900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
