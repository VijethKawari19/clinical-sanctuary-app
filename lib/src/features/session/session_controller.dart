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

class SessionState {
  const SessionState({
    required this.email,
    required this.role,
    required this.consentAccepted,
    required this.tempCaptureBuffer,
    required this.loginHistory,
  });

  final String? email;
  final AppRole? role;
  final bool consentAccepted;
  final TempCaptureBuffer? tempCaptureBuffer;

  /// ISO-8601 timestamps of successful logins (mirrors persisted user record).
  final List<String> loginHistory;

  static const empty = SessionState(
    email: null,
    role: null,
    consentAccepted: false,
    tempCaptureBuffer: null,
    loginHistory: [],
  );

  SessionState copyWith({
    String? email,
    AppRole? role,
    bool? consentAccepted,
    TempCaptureBuffer? tempCaptureBuffer,
    bool clearTempCaptureBuffer = false,
    List<String>? loginHistory,
  }) {
    return SessionState(
      email: email ?? this.email,
      role: role ?? this.role,
      consentAccepted: consentAccepted ?? this.consentAccepted,
      tempCaptureBuffer: clearTempCaptureBuffer
          ? null
          : (tempCaptureBuffer ?? this.tempCaptureBuffer),
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
}

