import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../session/session_controller.dart';
import 'otp_bridge.dart';
import 'password_rules.dart';
import 'user_record.dart';

enum LoginFailure { notFound, badPassword, roleMismatch }

class LocalAuthRepository {
  LocalAuthRepository({OtpBridge? otpBridge})
      : _otpBridge = otpBridge ?? StubOtpBridge();

  static const _usersKey = 'clinical_sanctuary.auth.users.v1';
  static const _otpKey = 'clinical_sanctuary.auth.otp.v1';
  static const _rememberKey = 'clinical_sanctuary.auth.remember.v1';

  final OtpBridge _otpBridge;

  String _hash(String password) =>
      sha256.convert(utf8.encode(password.trim())).toString();

  Future<List<UserRecord>> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usersKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return UserRecord.decodeList(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveUsers(List<UserRecord> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, UserRecord.encodeList(users));
  }

  Future<UserRecord?> findUser(String email) async {
    final e = email.trim().toLowerCase();
    final users = await _loadUsers();
    for (final u in users) {
      if (u.email.toLowerCase() == e) return u;
    }
    return null;
  }

  Future<UserRecord?> findUserByEmailOrPhone(String input) async {
    final raw = input.trim();
    if (raw.isEmpty) return null;
    final users = await _loadUsers();

    final maybeEmail = raw.toLowerCase();
    if (isValidEmail(maybeEmail)) {
      for (final u in users) {
        if (u.email.toLowerCase() == maybeEmail) return u;
      }
      return null;
    }

    final normalizedPhone = raw.replaceAll(RegExp(r'\D'), '');
    if (normalizedPhone.isEmpty) return null;
    for (final u in users) {
      final phone = (u.profile['phone'] as String?)?.replaceAll(RegExp(r'\D'), '');
      if (phone != null && phone == normalizedPhone) return u;
    }
    return null;
  }

  /// Returns error message or null on success.
  Future<String?> register({
    required String email,
    required String password,
    required AppRole role,
    required Map<String, dynamic> profile,
    List<String>? documentPaths,
  }) async {
    final em = email.trim().toLowerCase();
    if (!isValidEmail(em)) return 'Enter a valid email address.';
    final fails = passwordRuleFailures(password);
    if (fails.isNotEmpty) {
      return 'Password must include: ${fails.join(', ')}.';
    }
    if (await findUser(em) != null) {
      return 'An account with this email already exists.';
    }

    final docs = documentPaths ?? const <String>[];
    final merged = Map<String, dynamic>.from(profile);
    merged['docs'] = docs;

    final rec = UserRecord(
      email: em,
      passwordHash: _hash(password),
      role: role == AppRole.clinician ? 'clinician' : 'health_worker',
      profile: merged,
      loginHistory: const [],
    );
    final users = await _loadUsers();
    users.add(rec);
    await _saveUsers(users);
    return null;
  }

  Future<({UserRecord? user, LoginFailure? fail})> loginWithPassword({
    required String email,
    required String password,
    required AppRole selectedRole,
  }) async {
    final u = await findUser(email.trim().toLowerCase());
    if (u == null) return (user: null, fail: LoginFailure.notFound);
    if (u.passwordHash != _hash(password)) {
      return (user: null, fail: LoginFailure.badPassword);
    }
    if (u.appRole != selectedRole) {
      return (user: null, fail: LoginFailure.roleMismatch);
    }
    final updated = await _appendLoginHistory(u);
    return (user: updated, fail: null);
  }

  Future<UserRecord> _appendLoginHistory(UserRecord u) async {
    final stamp = DateTime.now().toUtc().toIso8601String();
    final next = u.copyWith(
      loginHistory: [...u.loginHistory, stamp],
    );
    final users = await _loadUsers();
    final idx = users.indexWhere(
      (x) => x.email.toLowerCase() == u.email.toLowerCase(),
    );
    if (idx >= 0) {
      users[idx] = next;
      await _saveUsers(users);
    }
    return next;
  }

  Future<void> saveRemembered({
    required String email,
    required AppRole role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _rememberKey,
      jsonEncode({
        'email': email.trim().toLowerCase(),
        'role': role == AppRole.clinician ? 'clinician' : 'health_worker',
      }),
    );
  }

  Future<void> clearRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberKey);
  }

  Future<({String? email, AppRole? role})> loadRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_rememberKey);
    if (raw == null) return (email: null, role: null);
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final r = m['role'] as String?;
      return (
        email: m['email'] as String?,
        role: r == 'clinician' ? AppRole.clinician : AppRole.healthWorker,
      );
    } catch (_) {
      return (email: null, role: null);
    }
  }

  /// Returns error message or null if OTP was issued.
  Future<String?> requestPasswordOtp(String email) async {
    final res = await requestPasswordOtpForIdentifier(email);
    return res.error;
  }

  /// Request password OTP by email or phone.
  ///
  /// Returns resolved email (delivery target) on success.
  Future<({String? resolvedEmail, String? error})> requestPasswordOtpForIdentifier(
    String identifier,
  ) async {
    final raw = identifier.trim();
    if (raw.isEmpty) {
      return (resolvedEmail: null, error: 'Enter your email or phone number.');
    }
    final u = await findUserByEmailOrPhone(raw);
    if (u == null) {
      return (
        resolvedEmail: null,
        error: 'No account exists for that email/phone.',
      );
    }
    final em = u.email.trim().toLowerCase();
    final code = (Random.secure().nextInt(900000) + 100000).toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _otpKey,
      jsonEncode({
        'email': em,
        'requestedBy': raw,
        'code': code,
        'expires': DateTime.now()
            .add(const Duration(minutes: 15))
            .millisecondsSinceEpoch,
      }),
    );
    try {
      await _otpBridge.sendRecoveryCode(email: em, code: code);
    } catch (e) {
      await prefs.remove(_otpKey);
      const isRelease = bool.fromEnvironment('dart.vm.product');
      final details = e.toString();
      return (
        resolvedEmail: null,
        error: isRelease
            ? 'Unable to send email right now. Please try again later or contact support.'
            : 'Unable to send email: $details',
      );
    }
    return (resolvedEmail: em, error: null);
  }

  /// Peek current OTP (dev UI only — remove when wiring real SMTP).
  Future<String?> peekPendingOtpForDev() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_otpKey);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m['code'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Validate OTP for password reset without consuming it.
  ///
  /// This allows a 2-step UX: verify code → set new password → consume OTP.
  Future<String?> verifyPasswordOtp({
    required String email,
    required String code,
  }) async {
    final em = email.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_otpKey);
    if (raw == null) {
      return 'No active reset code. Request a new one.';
    }
    Map<String, dynamic> m;
    try {
      m = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return 'Invalid reset state.';
    }
    if ((m['email'] as String?)?.toLowerCase() != em) {
      return 'Code was requested for a different account.';
    }
    final exp = m['expires'] as int?;
    if (exp != null && DateTime.now().millisecondsSinceEpoch > exp) {
      await prefs.remove(_otpKey);
      return 'Code expired. Request a new one.';
    }
    if ((m['code'] as String?) != code.trim()) {
      return 'Incorrect code.';
    }
    return null;
  }

  /// OTP-verified password reset.
  ///
  /// Returns error message or null on success.
  Future<String?> resetPasswordWithOtp({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final em = email.trim().toLowerCase();
    if (!isValidEmail(em)) return 'Enter a valid email address.';
    final fails = passwordRuleFailures(newPassword);
    if (fails.isNotEmpty) {
      return 'Password must include: ${fails.join(', ')}.';
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_otpKey);
    if (raw == null) return 'No active reset code. Request a new one.';

    Map<String, dynamic> m;
    try {
      m = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return 'Invalid reset state.';
    }

    if ((m['email'] as String?)?.toLowerCase() != em) {
      return 'Code was requested for a different email.';
    }

    final exp = m['expires'] as int?;
    if (exp != null && DateTime.now().millisecondsSinceEpoch > exp) {
      await prefs.remove(_otpKey);
      return 'Code expired. Request a new one.';
    }

    if ((m['code'] as String?) != code.trim()) {
      return 'Incorrect code.';
    }

    final users = await _loadUsers();
    final idx = users.indexWhere((u) => u.email.toLowerCase() == em);
    if (idx < 0) {
      await prefs.remove(_otpKey);
      return 'Account no longer exists.';
    }

    users[idx] = users[idx].copyWith(passwordHash: _hash(newPassword));
    await _saveUsers(users);
    await prefs.remove(_otpKey);
    return null;
  }
}
