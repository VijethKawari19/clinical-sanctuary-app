import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_auth_repository.dart';
import 'otp_bridge.dart';

final localAuthRepositoryProvider = Provider<LocalAuthRepository>((ref) {
  const otpApiOverride = String.fromEnvironment('OTP_API_BASE_URL');
  if (otpApiOverride.isNotEmpty) {
    return LocalAuthRepository(
      otpBridge: HttpOtpBridge(baseUrl: otpApiOverride),
    );
  }
  final smtp = SmtpOtpBridge.tryFromDartDefines();
  if (smtp != null) {
    return LocalAuthRepository(otpBridge: smtp);
  }
  // Release builds: call production mailer so Forgot Password works without
  // --dart-define (v1.0.6 APK/MSIX were missing this and used MissingOtpBridge).
  return LocalAuthRepository(
    otpBridge: HttpOtpBridge(baseUrl: HttpOtpBridge.defaultProductionBaseUrl),
  );
});
