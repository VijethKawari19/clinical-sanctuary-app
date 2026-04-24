import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
    // Intentionally no-op.
  }
}

/// Used when the app is expected to send real emails but SMTP isn't configured.
class MissingOtpBridge implements OtpBridge {
  @override
  Future<void> sendRecoveryCode({
    required String email,
    required String code,
  }) async {
    throw StateError(
      'SMTP is not configured. Provide SMTP_* values via --dart-define.',
    );
  }
}

/// SMTP sender configured via `--dart-define` values.
///
/// Example:
/// `flutter run -d windows --dart-define=SMTP_HOST=smtp.gmail.com --dart-define=SMTP_PORT=587 ...`
class SmtpOtpBridge implements OtpBridge {
  SmtpOtpBridge({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.fromEmail,
    required this.fromName,
    required this.useSsl,
    required this.allowInsecure,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final String fromEmail;
  final String fromName;
  final bool useSsl;
  final bool allowInsecure;

  static SmtpOtpBridge? tryFromDartDefines() {
    const host = String.fromEnvironment('SMTP_HOST');
    const portRaw = String.fromEnvironment('SMTP_PORT');
    const username = String.fromEnvironment('SMTP_USERNAME');
    const password = String.fromEnvironment('SMTP_PASSWORD');
    const fromEmail = String.fromEnvironment('SMTP_FROM');
    const fromName = String.fromEnvironment('SMTP_FROM_NAME', defaultValue: 'Clinical Curator');
    const useSslRaw = String.fromEnvironment('SMTP_SSL', defaultValue: 'false');
    const allowInsecureRaw = String.fromEnvironment('SMTP_ALLOW_INSECURE', defaultValue: 'false');

    if (host.isEmpty ||
        portRaw.isEmpty ||
        username.isEmpty ||
        password.isEmpty ||
        fromEmail.isEmpty) {
      return null;
    }

    final port = int.tryParse(portRaw);
    if (port == null) return null;

    final useSsl = useSslRaw.toLowerCase() == 'true';
    final allowInsecure = allowInsecureRaw.toLowerCase() == 'true';
    return SmtpOtpBridge(
      host: host,
      port: port,
      username: username,
      password: password,
      fromEmail: fromEmail,
      fromName: fromName,
      useSsl: useSsl,
      allowInsecure: allowInsecure,
    );
  }

  @override
  Future<void> sendRecoveryCode({
    required String email,
    required String code,
  }) async {
    final server = SmtpServer(
      host,
      port: port,
      username: username,
      password: password,
      ssl: useSsl,
      allowInsecure: allowInsecure,
    );

    final msg = Message()
      ..from = Address(fromEmail, fromName)
      ..recipients.add(email)
      ..subject = 'Password reset code'
      ..text = 'Your Clinical Curator password reset code is: $code\n\n'
          'This code expires in 15 minutes.'
      ..html = '''
<div style="font-family: Arial, sans-serif; line-height: 1.5;">
  <h2 style="margin: 0 0 8px 0;">Password reset</h2>
  <p style="margin: 0 0 16px 0;">Use this code to reset your password:</p>
  <div style="font-size: 28px; font-weight: 700; letter-spacing: 4px; padding: 12px 16px; background: #F2F4F7; display: inline-block; border-radius: 10px;">
    $code
  </div>
  <p style="margin: 16px 0 0 0; color: #667085;">This code expires in 15 minutes.</p>
</div>
''';

    await send(msg, server);
  }
}

/// Calls a backend API to send the OTP email.
///
/// Configure via `--dart-define=OTP_API_BASE_URL=https://your-server`.
class HttpOtpBridge implements OtpBridge {
  HttpOtpBridge({required this.baseUrl});

  final String baseUrl;

  static HttpOtpBridge? tryFromDartDefines() {
    const base = String.fromEnvironment('OTP_API_BASE_URL');
    if (base.isEmpty) return null;
    return HttpOtpBridge(baseUrl: base);
  }

  @override
  Future<void> sendRecoveryCode({
    required String email,
    required String code,
  }) async {
    final uri = Uri.parse(baseUrl).resolve('/otp/recovery');
    final resp = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('OTP API error ${resp.statusCode}: ${resp.body}');
    }
  }
}
