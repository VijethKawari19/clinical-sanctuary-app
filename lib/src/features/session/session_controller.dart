import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppRole { healthWorker, clinician }

enum CaptureMode { wireless, system, gallery }

class TempCaptureBuffer {
  const TempCaptureBuffer({
    required this.imageBase64,
    required this.mode,
  });

  final String imageBase64;
  final CaptureMode mode;
}

class PatientDraft {
  const PatientDraft({
    required this.patientName,
    required this.patientAge,
    required this.patientGender,
    required this.bloodGroup,
    required this.heightCm,
    required this.weightKg,
    required this.aadhaarNumber,
    required this.tobaccoUse,
    required this.alcoholUse,
    required this.contactPhone,
    required this.contactEmail,
    required this.notes,
  });

  final String patientName;
  final String patientAge;
  final String patientGender;
  final String bloodGroup;
  final String heightCm;
  final String weightKg;
  final String aadhaarNumber;
  final String tobaccoUse;
  final String alcoholUse;
  final String contactPhone;
  final String contactEmail;
  final String notes;
}

class SessionState {
  const SessionState({
    required this.email,
    required this.role,
    required this.consentAccepted,
    required this.tempCaptureBuffer,
    required this.patientDraft,
    required this.loginHistory,
  });

  final String? email;
  final AppRole? role;
  final bool consentAccepted;
  final TempCaptureBuffer? tempCaptureBuffer;
  final PatientDraft? patientDraft;

  /// ISO-8601 timestamps of successful logins (mirrors persisted user record).
  final List<String> loginHistory;

  static const empty = SessionState(
    email: null,
    role: null,
    consentAccepted: false,
    tempCaptureBuffer: null,
    patientDraft: null,
    loginHistory: [],
  );

  SessionState copyWith({
    String? email,
    AppRole? role,
    bool? consentAccepted,
    TempCaptureBuffer? tempCaptureBuffer,
    bool clearTempCaptureBuffer = false,
    PatientDraft? patientDraft,
    bool clearPatientDraft = false,
    List<String>? loginHistory,
  }) {
    return SessionState(
      email: email ?? this.email,
      role: role ?? this.role,
      consentAccepted: consentAccepted ?? this.consentAccepted,
      tempCaptureBuffer: clearTempCaptureBuffer
          ? null
          : (tempCaptureBuffer ?? this.tempCaptureBuffer),
      patientDraft: clearPatientDraft ? null : (patientDraft ?? this.patientDraft),
      loginHistory: loginHistory ?? this.loginHistory,
    );
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() => SessionState.empty;

  void startSession({
    required String email,
    required AppRole role,
    List<String>? loginHistory,
  }) {
    state = SessionState.empty.copyWith(
      email: email,
      role: role,
      consentAccepted: false,
      clearTempCaptureBuffer: true,
      clearPatientDraft: true,
      loginHistory: loginHistory ?? const [],
    );
  }

  void endSession() {
    state = SessionState.empty;
  }

  void acceptConsent() {
    state = state.copyWith(consentAccepted: true);
  }

  void setTempCapture(TempCaptureBuffer buf) {
    state = state.copyWith(tempCaptureBuffer: buf);
  }

  void clearTempCapture() {
    state = state.copyWith(clearTempCaptureBuffer: true);
  }

  void setPatientDraft(PatientDraft draft) {
    state = state.copyWith(patientDraft: draft);
  }

  void clearPatientDraft() {
    state = state.copyWith(clearPatientDraft: true);
  }
}

