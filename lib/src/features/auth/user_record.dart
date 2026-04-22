import 'dart:convert';

import '../session/session_controller.dart';

/// Stored account matching the unified auth JSON shape (local persistence).
class UserRecord {
  const UserRecord({
    required this.email,
    required this.passwordHash,
    required this.role,
    required this.profile,
    required this.loginHistory,
  });

  final String email;
  final String passwordHash;
  /// `health_worker` | `clinician`
  final String role;
  final Map<String, dynamic> profile;
  final List<String> loginHistory;

  AppRole get appRole =>
      role == 'clinician' ? AppRole.clinician : AppRole.healthWorker;

  Map<String, dynamic> toJson() => {
        'email': email,
        'passwordHash': passwordHash,
        'role': role,
        'profile': profile,
        'loginHistory': loginHistory,
      };

  factory UserRecord.fromJson(Map<String, dynamic> j) {
    final hist = j['loginHistory'];
    return UserRecord(
      email: j['email'] as String,
      passwordHash: j['passwordHash'] as String,
      role: j['role'] as String,
      profile: Map<String, dynamic>.from(
        (j['profile'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      loginHistory: hist is List
          ? hist.map((e) => e.toString()).toList()
          : const [],
    );
  }

  UserRecord copyWith({
    String? email,
    String? passwordHash,
    String? role,
    Map<String, dynamic>? profile,
    List<String>? loginHistory,
  }) {
    return UserRecord(
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      profile: profile ?? Map<String, dynamic>.from(this.profile),
      loginHistory: loginHistory ?? List<String>.from(this.loginHistory),
    );
  }

  static String encodeList(List<UserRecord> users) =>
      jsonEncode(users.map((e) => e.toJson()).toList());

  static List<UserRecord> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => UserRecord.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Display name from registration (`profile.fullName`), with sensible fallbacks.
  String get displayName {
    final raw = profile['fullName'];
    if (raw is String) {
      final t = raw.trim();
      if (t.isNotEmpty) return t;
    }
    final local = email.split('@').first;
    return local.isNotEmpty ? local : 'User';
  }
}
