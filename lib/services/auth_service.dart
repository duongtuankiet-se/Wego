import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  /// Scopes we actually use today — email lets us key Mongo users by
  /// address and avoid dup accounts; profile gives us the display name
  /// + avatar URL we render in the header.
  static final _googleSignIn = GoogleSignIn(scopes: const ['email', 'profile']);

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

  /// Sign out from BOTH providers. Skipping the Google side leaves a
  /// stale token cached and the next `signIn()` returns the previous
  /// account without showing the picker.
  static Future<void> signOut() async {
    _verificationId = null;
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  /// Trigger the native Google account picker → exchange the resulting
  /// id/access tokens for a Firebase credential → sign into Firebase.
  /// Returns the picked email + display name + photo so the caller can
  /// upsert into Mongo.
  static Future<AuthGoogleResult> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthGoogleResult.error('Đã hủy đăng nhập');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        return AuthGoogleResult.error('Đăng nhập Firebase thất bại');
      }

      return AuthGoogleResult.success(
        firebaseUid: user.uid,
        email: user.email ?? googleUser.email,
        displayName: user.displayName ?? googleUser.displayName ?? 'Người dùng',
        photoUrl: user.photoURL ?? googleUser.photoUrl,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[auth-google] FirebaseAuthException: ${e.code}');
      return AuthGoogleResult.error(_mapGoogleError(e));
    } catch (e) {
      debugPrint('[auth-google] error: $e');
      return AuthGoogleResult.error('Lỗi không xác định: $e');
    }
  }

  static String _mapGoogleError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'Email này đã đăng ký bằng cách khác';
      case 'invalid-credential':
        return 'Thông tin đăng nhập không hợp lệ';
      case 'network-request-failed':
        return 'Lỗi mạng, vui lòng thử lại';
      case 'user-disabled':
        return 'Tài khoản đã bị khóa';
      default:
        return 'Lỗi: ${e.message ?? e.code}';
    }
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

class AuthGoogleResult {
  const AuthGoogleResult._({
    required this.isSuccess,
    this.firebaseUid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.error,
  });

  final bool isSuccess;
  final String? firebaseUid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? error;

  factory AuthGoogleResult.success({
    required String firebaseUid,
    required String email,
    required String displayName,
    String? photoUrl,
  }) => AuthGoogleResult._(
    isSuccess: true,
    firebaseUid: firebaseUid,
    email: email,
    displayName: displayName,
    photoUrl: photoUrl,
  );

  factory AuthGoogleResult.error(String msg) =>
      AuthGoogleResult._(isSuccess: false, error: msg);
}
