import 'package:flutter/foundation.dart';

/// Pluggable bridge for sending OTP (SMTP in production). Stub logs / surfaces in debug.
abstract class OtpBridge {
  Future<void> sendRecoveryCode({required String email, required String code});
}

/// Development / offline: no SMTP. Logs code; production should replace with HTTP→SMTP service.
class StubOtpBridge implements OtpBridge {
  @override
  Future<void> sendRecoveryCode({
    required String email,
    required String code,
  }) async {
    debugPrint('[OTP] $email → $code (stub: replace with SMTP/API)');
  }
}
