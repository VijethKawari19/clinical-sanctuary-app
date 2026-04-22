import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_state.dart';

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

class SettingsController extends Notifier<SettingsState> {
  static const _key = 'clinical_curator.settings.v1';

  @override
  SettingsState build() {
    Future<void>(() async {
      await _load();
    });
    return SettingsState.defaults;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        state = SettingsState.fromJson(decoded);
      } else if (decoded is Map) {
        state = SettingsState.fromJson(
          decoded.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    } catch (_) {
      // ignore malformed settings
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> setCloudAnalysisEnabled(bool v) async {
    state = state.copyWith(cloudAnalysisEnabled: v);
    await _persist();
  }

  Future<void> setThemeMode(AppThemeMode v) async {
    state = state.copyWith(themeMode: v);
    await _persist();
  }

  Future<void> setHighContrastEnabled(bool v) async {
    state = state.copyWith(highContrastEnabled: v);
    await _persist();
  }

  Future<void> setBiometricLockEnabled(bool v) async {
    state = state.copyWith(biometricLockEnabled: v);
    await _persist();
  }

  Future<void> setAutoLogoutMinutes(int minutes) async {
    state = state.copyWith(autoLogoutMinutes: minutes);
    await _persist();
  }

  Future<void> setAutoLogoutEnabled(bool v) async {
    state = state.copyWith(autoLogoutEnabled: v);
    await _persist();
  }

  Future<void> setDataRetentionMonths(int months) async {
    state = state.copyWith(dataRetentionMonths: months);
    await _persist();
  }

  Future<void> setProfileName(String v) async {
    state = state.copyWith(profileName: v);
    await _persist();
  }

  Future<void> setProfileEmail(String v) async {
    state = state.copyWith(profileEmail: v);
    await _persist();
  }

  Future<void> setProfileRole(String v) async {
    state = state.copyWith(profileRole: v);
    await _persist();
  }

  Future<void> setProfilePhotoPath(String? v) async {
    state = state.copyWith(profilePhotoPath: v);
    await _persist();
  }

  Future<void> setProfilePhotoBase64(String? v) async {
    state = state.copyWith(profilePhotoBase64: v);
    await _persist();
  }

  Future<void> clearProfilePhoto() async {
    state = state.copyWith(
      clearProfilePhotoPath: true,
      clearProfilePhotoBase64: true,
    );
    await _persist();
  }

  Future<void> importProfilePhoto(XFile source) async {
    final bytes = await source.readAsBytes();
    final b64 = base64Encode(bytes);
    state = state.copyWith(
      profilePhotoBase64: b64,
      // Keep path for backwards compatibility on platforms where it exists.
      profilePhotoPath: source.path.isNotEmpty ? source.path : null,
    );
    await _persist();
  }

  Future<void> clearAll() async {
    state = SettingsState.defaults;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> setTutorialSeen(bool v) async {
    state = state.copyWith(tutorialSeen: v);
    await _persist();
  }

  Future<void> setTutorialWorkerStep(int step) async {
    final clamped = step < 0 ? 0 : step;
    state = state.copyWith(tutorialWorkerStep: clamped);
    await _persist();
  }

  Future<void> setTutorialClinicianStep(int step) async {
    final clamped = step < 0 ? 0 : step;
    state = state.copyWith(tutorialClinicianStep: clamped);
    await _persist();
  }
}

