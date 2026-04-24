import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_auth_repository.dart';
import 'otp_bridge.dart';

final localAuthRepositoryProvider = Provider<LocalAuthRepository>((ref) {
  final smtp = SmtpOtpBridge.tryFromDartDefines();
  return LocalAuthRepository(otpBridge: smtp ?? MissingOtpBridge());
});
