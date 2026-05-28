import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_input.dart';
import '../../core/widgets/wg_toast.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

/// Phase 5P: shown after a Google sign-in for accounts that don't yet
/// have a phone on file. Single-screen 2-state form (phone → OTP) that
/// uses Firebase's `linkWithCredential` so the resulting Firebase user
/// has BOTH `google.com` and `phone` providers attached. Mongo
/// `users.phone` is updated on success.
///
/// Intentionally no "skip" affordance — every account needs a phone so
/// drivers can reach passengers.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  Timer? _countdownTimer;
  int _secondsLeft = 60;

  bool _otpSent = false;
  bool _loading = false;
  String? _pendingPhoneE164;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsLeft = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _sendOtp() async {
    final phoneError = Validators.validatePhone(_phoneCtrl.text);
    if (phoneError != null) {
      WgToast.error(context, phoneError);
      return;
    }
    setState(() => _loading = true);
    final phoneE164 = normalizePhone(_phoneCtrl.text);

    final result = await AuthService.sendOtpForLink(phoneNumber: phoneE164);
    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() => _loading = false);
      WgToast.error(context, result.error ?? 'Không gửi được OTP');
      return;
    }

    if (result.isAutoVerified) {
      // Android auto-verify: phone already linked under the hood —
      // skip OTP screen and persist phone to Mongo.
      await _persistAndExit(phoneE164);
      return;
    }

    setState(() {
      _otpSent = true;
      _loading = false;
      _pendingPhoneE164 = phoneE164;
    });
    _startCountdown();
  }

  Future<void> _resendOtp() async {
    if (_secondsLeft > 0 || _loading) return;
    setState(() => _loading = true);
    final result = await AuthService.sendOtpForLink(
      phoneNumber: _pendingPhoneE164!,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.isSuccess) {
      WgToast.error(context, result.error ?? 'Không gửi lại được OTP');
      return;
    }
    _otpCtrl.clear();
    _startCountdown();
    WgToast.success(context, 'Đã gửi lại mã OTP');
  }

  Future<void> _verifyOtp(String code) async {
    if (code.length != 6 || _loading) return;
    setState(() => _loading = true);

    final result = await AuthService.verifyOtpAndLink(otpCode: code);
    if (!mounted) return;

    if (!result.success) {
      setState(() => _loading = false);
      WgToast.error(context, result.error ?? 'Xác thực thất bại');
      _otpCtrl.clear();
      return;
    }

    await _persistAndExit(_pendingPhoneE164!);
  }

  Future<void> _persistAndExit(String phoneE164) async {
    final err = await ref
        .read(authStateProvider.notifier)
        .updateUserPhone(phoneE164);
    if (!mounted) return;
    if (err != null) {
      setState(() => _loading = false);
      WgToast.error(context, err);
      return;
    }
    HapticFeedback.lightImpact();
    WgToast.success(context, 'Đã liên kết số điện thoại');

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    if (user.role == UserRole.driver) {
      context.go('/driver/home');
    } else {
      context.go('/passenger/home');
    }
  }

  String _maskedPhone(String e164) {
    if (e164.length < 9) return e164;
    return '${e164.substring(0, 3)} ${e164.substring(3, 6)} *** '
        '${e164.substring(e164.length - 3)}';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    return PopScope(
      // Prevent accidental back swipe — completing the profile is
      // mandatory before reaching the app. The only way out is the
      // explicit sign-out from the appbar.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          title: const Text('Hoàn tất hồ sơ'),
          actions: [
            TextButton(
              onPressed: _loading
                  ? null
                  : () async {
                      await ref.read(authStateProvider.notifier).logout();
                      if (!context.mounted) return;
                      context.go('/login');
                    },
              child: Text(
                'Đăng xuất',
                style: AppTypography.body.copyWith(
                  color: AppColors.ink500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    PhosphorIconsFill.phone,
                    color: AppColors.primary500,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Thêm số điện thoại',
                  style: AppTypography.h1.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  user?.name != null
                      ? 'Chào ${user!.name}! Số điện thoại giúp tài xế liên hệ với bạn khi đặt chuyến.'
                      : 'Số điện thoại giúp tài xế liên hệ với bạn khi đặt chuyến.',
                  style: AppTypography.body.copyWith(color: AppColors.ink600),
                ),
                const SizedBox(height: 28),
                if (!_otpSent) _buildPhoneStep() else _buildOtpStep(),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Số điện thoại là bắt buộc để sử dụng dịch vụ',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WgInput(
          label: 'Số điện thoại',
          hint: '0905xxxxxx',
          controller: _phoneCtrl,
          variant: WgInputVariant.phone,
          prefixIcon: PhosphorIconsRegular.phone,
          validator: Validators.validatePhone,
          textInputAction: TextInputAction.done,
          enabled: !_loading,
          onSubmitted: (_) => _sendOtp(),
        ),
        const SizedBox(height: 18),
        WgButton.primary(
          label: 'Gửi mã OTP',
          size: WgButtonSize.lg,
          isFullWidth: true,
          isLoading: _loading,
          onPressed: _loading ? null : _sendOtp,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    final canResend = _secondsLeft == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RichText(
          text: TextSpan(
            style: AppTypography.body.copyWith(color: AppColors.ink600),
            children: [
              const TextSpan(text: 'Mã đã gửi đến '),
              TextSpan(
                text: _maskedPhone(_pendingPhoneE164 ?? ''),
                style: AppTypography.body.copyWith(
                  color: AppColors.ink900,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PinCodeTextField(
          appContext: context,
          controller: _otpCtrl,
          length: 6,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          animationType: AnimationType.fade,
          animationDuration: const Duration(milliseconds: 200),
          enableActiveFill: true,
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(12),
            fieldHeight: 56,
            fieldWidth: 44,
            activeFillColor: AppColors.white,
            inactiveFillColor: AppColors.ink50,
            selectedFillColor: AppColors.primary50,
            activeColor: AppColors.primary500,
            inactiveColor: AppColors.ink200,
            selectedColor: AppColors.primary500,
            borderWidth: 1.5,
          ),
          textStyle: AppTypography.h2.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.ink900,
          ),
          cursorColor: AppColors.primary500,
          enabled: !_loading,
          autoFocus: true,
          onChanged: (_) {},
          onCompleted: _verifyOtp,
        ),
        const SizedBox(height: 12),
        Center(
          child: canResend
              ? TextButton(
                  onPressed: _loading ? null : _resendOtp,
                  child: Text(
                    'Gửi lại mã',
                    style: AppTypography.body.copyWith(
                      color: AppColors.primary500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : Text(
                  'Gửi lại sau ${_secondsLeft.toString().padLeft(2, '0')}s',
                  style: AppTypography.body.copyWith(color: AppColors.ink500),
                ),
        ),
        const SizedBox(height: 12),
        WgButton.primary(
          label: 'Xác nhận',
          size: WgButtonSize.lg,
          isFullWidth: true,
          isLoading: _loading,
          onPressed: (_loading || _otpCtrl.text.length != 6)
              ? null
              : () => _verifyOtp(_otpCtrl.text),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _loading
                ? null
                : () {
                    setState(() {
                      _otpSent = false;
                      _otpCtrl.clear();
                    });
                  },
            child: Text(
              'Đổi số điện thoại khác',
              style: AppTypography.caption.copyWith(
                color: AppColors.ink500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
