import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_toast.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  const VerifyOtpScreen({
    super.key,
    required this.phone,
    required this.isRegister,
    this.name,
    this.role,
  });

  /// E.164 phone (`+84...`). Used both for display and the verify call.
  final String phone;

  /// `true` if the user just came from RegisterScreen — verify will
  /// upsert the new Mongo doc using [name] + [role].
  final bool isRegister;

  /// Required when [isRegister] is `true`.
  final String? name;
  final UserRole? role;

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final _otpCtrl = TextEditingController();
  Timer? _countdownTimer;
  int _secondsLeft = 60;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpCtrl.dispose();
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

  Future<void> _resendOtp() async {
    if (_secondsLeft > 0 || _loading) return;
    setState(() => _loading = true);
    final error = await ref
        .read(authStateProvider.notifier)
        .sendOtp(widget.phone);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      WgToast.error(context, error);
      return;
    }
    _otpCtrl.clear();
    _startCountdown();
    WgToast.success(context, 'Đã gửi lại mã OTP');
  }

  Future<void> _verify(String code) async {
    if (code.length != 6 || _loading) return;
    setState(() => _loading = true);

    final error = await ref
        .read(authStateProvider.notifier)
        .verifyOtpAndLogin(otpCode: code, name: widget.name, role: widget.role);

    if (!mounted) return;

    if (error != null) {
      setState(() => _loading = false);
      WgToast.error(context, error);
      _otpCtrl.clear();
      return;
    }

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      setState(() => _loading = false);
      WgToast.error(context, 'Không tải được tài khoản');
      return;
    }

    HapticFeedback.lightImpact();
    if (user.role == UserRole.driver) {
      context.go('/driver/home');
    } else {
      context.go('/passenger/home');
    }
  }

  String _maskedPhone() {
    // Show "+84 9** *** 456" — middle 5 digits become * to confirm they
    // typed it correctly without exposing the full number.
    final p = widget.phone;
    if (p.length < 9) return p;
    final country = p.substring(0, 3);
    final firstDigit = p.substring(3, 4);
    final last3 = p.substring(p.length - 3);
    return '$country $firstDigit** *** $last3';
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft == 0;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Xác minh số điện thoại'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView(
            children: [
              const SizedBox(height: 8),
              Text(
                'Nhập mã OTP',
                style: AppTypography.h1.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  style: AppTypography.body.copyWith(color: AppColors.ink500),
                  children: [
                    const TextSpan(text: 'Mã đã gửi đến '),
                    TextSpan(
                      text: _maskedPhone(),
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
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
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink900,
                ),
                cursorColor: AppColors.primary500,
                enabled: !_loading,
                autoFocus: true,
                onChanged: (_) {},
                onCompleted: _verify,
              ),
              const SizedBox(height: 18),
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
                        'Gửi lại sau ${_formatSeconds(_secondsLeft)}',
                        style: AppTypography.body.copyWith(
                          color: AppColors.ink500,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              WgButton.primary(
                label: 'Xác nhận',
                size: WgButtonSize.lg,
                isFullWidth: true,
                isLoading: _loading,
                onPressed: (_loading || _otpCtrl.text.length != 6)
                    ? null
                    : () => _verify(_otpCtrl.text),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        PhosphorIconsFill.info,
                        color: AppColors.warning,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Demo: dùng các số test Firebase\n'
                          '+84 905 123 456 → 123456\n'
                          '+84 912 444 555 → 654321\n'
                          '+84 988 999 111 → 111111',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.ink700,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatSeconds(int s) {
    final m = (s ~/ 60).toString().padLeft(1, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }
}
