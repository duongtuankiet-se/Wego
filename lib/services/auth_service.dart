import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Wraps Firebase Phone Auth into a 2-step API:
///   1. [sendOtp] — push SMS; returns success/error.
///   2. [verifyOtp] — exchange code for a User; returns uid + phone.
///
/// The Firebase verificationId from step 1 is cached on the singleton so
/// the verify call doesn't need it threaded back through the UI.
class AuthService {
  AuthService._();

  static final _auth = FirebaseAuth.instance;
  static String? _verificationId;

  /// Send an OTP SMS to [phoneNumber] (must be E.164: `+84...`).
  /// On Android the Play Integrity flow may auto-verify; in that case
  /// the result has `isAutoVerified = true` and the caller should skip
  /// the OTP screen.
  static Future<AuthOtpResult> sendOtp({required String phoneNumber}) async {
    final completer = Completer<AuthOtpResult>();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
            if (!completer.isCompleted) {
              completer.complete(AuthOtpResult.autoVerified());
            }
          } catch (_) {
            if (!completer.isCompleted) {
              completer.complete(
                AuthOtpResult.error('Tự động xác minh thất bại'),
              );
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('[auth] verificationFailed: ${e.code} ${e.message}');
          if (!completer.isCompleted) {
            completer.complete(AuthOtpResult.error(_mapSendError(e)));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete(AuthOtpResult.codeSent(verificationId));
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );

      return await completer.future.timeout(
        const Duration(seconds: 70),
        onTimeout: () => AuthOtpResult.error('Hết thời gian gửi OTP'),
      );
    } catch (e) {
      debugPrint('[auth] sendOtp error: $e');
      return AuthOtpResult.error('Lỗi không xác định: $e');
    }
  }

  /// Verify the SMS code the user typed. Requires [sendOtp] succeeded
  /// in the current session (we cache `_verificationId`).
  static Future<AuthVerifyResult> verifyOtp({required String otpCode}) async {
    if (_verificationId == null) {
      return AuthVerifyResult.error('Phiên OTP đã hết hạn, vui lòng gửi lại');
    }
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpCode,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        return AuthVerifyResult.error('Đăng nhập thất bại');
      }
      return AuthVerifyResult.success(
        firebaseUid: user.uid,
        phoneNumber: user.phoneNumber ?? '',
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[auth] verifyOtp error: ${e.code}');
      return AuthVerifyResult.error(_mapVerifyError(e));
    } catch (e) {
      return AuthVerifyResult.error('Lỗi không xác định: $e');
    }
  }

  static Future<void> signOut() async {
    _verificationId = null;
    await _auth.signOut();
  }

  static User? get currentUser => _auth.currentUser;

  static String _mapSendError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Số điện thoại không hợp lệ';
      case 'too-many-requests':
        return 'Quá nhiều yêu cầu, thử lại sau';
      case 'quota-exceeded':
        return 'Đã đạt giới hạn SMS hàng ngày, dùng số test';
      case 'app-not-authorized':
        return 'App chưa được Firebase xác thực (kiểm tra SHA-1)';
      default:
        return 'Không gửi được OTP: ${e.message ?? e.code}';
    }
  }

  static String _mapVerifyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Mã OTP không đúng, kiểm tra lại';
      case 'session-expired':
        return 'Phiên OTP đã hết hạn, gửi lại mã';
      default:
        return 'Lỗi: ${e.message ?? e.code}';
    }
  }
}

class AuthOtpResult {
  const AuthOtpResult._({
    required this.isSuccess,
    this.isAutoVerified = false,
    this.verificationId,
    this.error,
  });

  final bool isSuccess;
  final bool isAutoVerified;
  final String? verificationId;
  final String? error;

  factory AuthOtpResult.codeSent(String id) =>
      AuthOtpResult._(isSuccess: true, verificationId: id);

  factory AuthOtpResult.autoVerified() =>
      const AuthOtpResult._(isSuccess: true, isAutoVerified: true);

  factory AuthOtpResult.error(String msg) =>
      AuthOtpResult._(isSuccess: false, error: msg);
}

class AuthVerifyResult {
  const AuthVerifyResult._({
    required this.isSuccess,
    this.firebaseUid,
    this.phoneNumber,
    this.error,
  });

  final bool isSuccess;
  final String? firebaseUid;
  final String? phoneNumber;
  final String? error;

  factory AuthVerifyResult.success({
    required String firebaseUid,
    required String phoneNumber,
  }) => AuthVerifyResult._(
    isSuccess: true,
    firebaseUid: firebaseUid,
    phoneNumber: phoneNumber,
  );

  factory AuthVerifyResult.error(String msg) =>
      AuthVerifyResult._(isSuccess: false, error: msg);
}
