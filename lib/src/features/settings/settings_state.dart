import 'package:flutter/material.dart';

enum AppThemeMode { light, dark }

class SettingsState {
  const SettingsState({
    required this.cloudAnalysisEnabled,
    required this.themeMode,
    required this.highContrastEnabled,
    required this.biometricLockEnabled,
    required this.autoLogoutEnabled,
    required this.autoLogoutMinutes,
    required this.dataRetentionMonths,
    required this.profileName,
    required this.profileEmail,
    required this.profileRole,
    required this.profileJoinedIso,
    required this.profilePhotoPath,
    required this.profilePhotoBase64,
    required this.tutorialSeen,
    required this.tutorialWorkerStep,
    required this.tutorialClinicianStep,
  });

  final bool cloudAnalysisEnabled;
  final AppThemeMode themeMode;
  final bool highContrastEnabled;
  final bool biometricLockEnabled;
  final bool autoLogoutEnabled;
  final int autoLogoutMinutes;
  final int dataRetentionMonths;

  final String profileName;
  final String profileEmail;
  final String profileRole;
  final String profileJoinedIso;
  final String? profilePhotoPath;
  /// Base64-encoded image bytes for platforms without stable file paths (Web).
  final String? profilePhotoBase64;

  final bool tutorialSeen;
  /// Last completed/visited step index for Health Worker track.
  final int tutorialWorkerStep;
  /// Last completed/visited step index for Clinician track.
  final int tutorialClinicianStep;

  static const defaults = SettingsState(
    cloudAnalysisEnabled: true,
    themeMode: AppThemeMode.light,
    highContrastEnabled: false,
    biometricLockEnabled: false,
    autoLogoutEnabled: true,
    autoLogoutMinutes: 10,
    dataRetentionMonths: 12,
    profileName: 'User',
    profileEmail: 'vijethkawari7@gmail.com',
    profileRole: 'CLINICIAN',
    profileJoinedIso: '2026-04-01',
    profilePhotoPath: null,
    profilePhotoBase64: null,
    tutorialSeen: false,
    tutorialWorkerStep: 0,
    tutorialClinicianStep: 0,
  );

  ThemeMode get flutterThemeMode =>
      themeMode == AppThemeMode.dark ? ThemeMode.dark : ThemeMode.light;

  SettingsState copyWith({
    bool? cloudAnalysisEnabled,
    AppThemeMode? themeMode,
    bool? highContrastEnabled,
    bool? biometricLockEnabled,
    bool? autoLogoutEnabled,
    int? autoLogoutMinutes,
    int? dataRetentionMonths,
    String? profileName,
    String? profileEmail,
    String? profileRole,
    String? profileJoinedIso,
    String? profilePhotoPath,
    String? profilePhotoBase64,
    bool? tutorialSeen,
    int? tutorialWorkerStep,
    int? tutorialClinicianStep,
    bool clearProfilePhotoPath = false,
    bool clearProfilePhotoBase64 = false,
  }) {
    return SettingsState(
      cloudAnalysisEnabled: cloudAnalysisEnabled ?? this.cloudAnalysisEnabled,
      themeMode: themeMode ?? this.themeMode,
      highContrastEnabled: highContrastEnabled ?? this.highContrastEnabled,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      autoLogoutEnabled: autoLogoutEnabled ?? this.autoLogoutEnabled,
      autoLogoutMinutes: autoLogoutMinutes ?? this.autoLogoutMinutes,
      dataRetentionMonths: dataRetentionMonths ?? this.dataRetentionMonths,
      profileName: profileName ?? this.profileName,
      profileEmail: profileEmail ?? this.profileEmail,
      profileRole: profileRole ?? this.profileRole,
      profileJoinedIso: profileJoinedIso ?? this.profileJoinedIso,
      profilePhotoPath: clearProfilePhotoPath
          ? null
          : (profilePhotoPath ?? this.profilePhotoPath),
      profilePhotoBase64: clearProfilePhotoBase64
          ? null
          : (profilePhotoBase64 ?? this.profilePhotoBase64),
      tutorialSeen: tutorialSeen ?? this.tutorialSeen,
      tutorialWorkerStep: tutorialWorkerStep ?? this.tutorialWorkerStep,
      tutorialClinicianStep: tutorialClinicianStep ?? this.tutorialClinicianStep,
    );
  }

  Map<String, Object?> toJson() => {
        'cloudAnalysisEnabled': cloudAnalysisEnabled,
        'themeMode': themeMode.name,
        'highContrastEnabled': highContrastEnabled,
        'biometricLockEnabled': biometricLockEnabled,
        'autoLogoutEnabled': autoLogoutEnabled,
        'autoLogoutMinutes': autoLogoutMinutes,
        'dataRetentionMonths': dataRetentionMonths,
        'profileName': profileName,
        'profileEmail': profileEmail,
        'profileRole': profileRole,
        'profileJoinedIso': profileJoinedIso,
        'profilePhotoPath': profilePhotoPath,
        'profilePhotoBase64': profilePhotoBase64,
        'tutorialSeen': tutorialSeen,
        'tutorialWorkerStep': tutorialWorkerStep,
        'tutorialClinicianStep': tutorialClinicianStep,
      };

  static SettingsState fromJson(Map<String, Object?> json) {
    AppThemeMode parseTheme(Object? raw) {
      final name = (raw as String?) ?? AppThemeMode.light.name;
      return AppThemeMode.values
          .firstWhere((e) => e.name == name, orElse: () => AppThemeMode.light);
    }

    int parseInt(Object? raw, int fallback) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw) ?? fallback;
      return fallback;
    }

    bool parseBool(Object? raw, bool fallback) {
      if (raw is bool) return raw;
      if (raw is String) return raw.toLowerCase() == 'true';
      return fallback;
    }

    return SettingsState(
      cloudAnalysisEnabled:
          parseBool(json['cloudAnalysisEnabled'], defaults.cloudAnalysisEnabled),
      themeMode: parseTheme(json['themeMode']),
      highContrastEnabled:
          parseBool(json['highContrastEnabled'], defaults.highContrastEnabled),
      biometricLockEnabled:
          parseBool(json['biometricLockEnabled'], defaults.biometricLockEnabled),
      autoLogoutEnabled:
          parseBool(json['autoLogoutEnabled'], defaults.autoLogoutEnabled),
      autoLogoutMinutes:
          parseInt(json['autoLogoutMinutes'], defaults.autoLogoutMinutes),
      dataRetentionMonths:
          parseInt(json['dataRetentionMonths'], defaults.dataRetentionMonths),
      profileName: (json['profileName'] as String?) ?? defaults.profileName,
      profileEmail: (json['profileEmail'] as String?) ?? defaults.profileEmail,
      profileRole: (json['profileRole'] as String?) ?? defaults.profileRole,
      profileJoinedIso:
          (json['profileJoinedIso'] as String?) ?? defaults.profileJoinedIso,
      profilePhotoPath: (json['profilePhotoPath'] as String?),
      profilePhotoBase64: (json['profilePhotoBase64'] as String?),
      tutorialSeen: parseBool(json['tutorialSeen'], defaults.tutorialSeen),
      tutorialWorkerStep:
          parseInt(json['tutorialWorkerStep'], defaults.tutorialWorkerStep),
      tutorialClinicianStep:
          parseInt(json['tutorialClinicianStep'], defaults.tutorialClinicianStep),
    );
  }
}

