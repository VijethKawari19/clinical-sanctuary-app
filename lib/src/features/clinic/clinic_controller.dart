import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'clinic_models.dart';

final clinicControllerProvider =
    NotifierProvider<ClinicController, ClinicState>(ClinicController.new);

final pendingCountProvider = Provider<int>((ref) {
  final cases = ref.watch(clinicControllerProvider).cases;
  return cases.where((c) => c.status == CaseStatus.pending).length;
});

final reviewedCountProvider = Provider<int>((ref) {
  final cases = ref.watch(clinicControllerProvider).cases;
  return cases.where((c) => c.status == CaseStatus.reviewed).length;
});

final totalPatientsProvider = Provider<int>((ref) {
  final cases = ref.watch(clinicControllerProvider).cases;
  return cases.map((c) => c.patientName.trim()).where((n) => n.isNotEmpty).toSet().length;
});

final casesProvider = Provider<List<CaseRecord>>((ref) {
  final cases = ref.watch(clinicControllerProvider).cases;
  final sorted = [...cases];
  // pending first, then newest by timestamp
  sorted.sort((a, b) {
    final sa = a.status == CaseStatus.pending ? 0 : 1;
    final sb = b.status == CaseStatus.pending ? 0 : 1;
    return sa != sb ? sa.compareTo(sb) : b.timestampIso.compareTo(a.timestampIso);
  });
  return sorted;
});

final auditLogsProvider = Provider<List<AuditLogEntry>>((ref) {
  return ref.watch(clinicControllerProvider).auditLogs;
});

class ClinicController extends Notifier<ClinicState> {
  static const _storageKey = 'clinic_state_v1';
  bool _hydrated = false;

  @override
  ClinicState build() {
    if (!_hydrated) {
      _hydrated = true;
      // Fire-and-forget hydration.
      Future<void>(() async => _hydrate());
    }
    return const ClinicState(cases: [], auditLogs: []);
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      state = ClinicState.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      // ignore corrupt storage
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  void addAuditLog({
    required String actionType,
    required String details,
  }) {
    final now = DateTime.now().toIso8601String();
    final next = AuditLogEntry(
      id: 'AL-${now.hashCode}',
      timestampIso: now,
      actionType: actionType,
      details: details,
    );
    state = state.copyWith(auditLogs: [next, ...state.auditLogs]);
    _persist();
  }

  String nextCaseId() {
    final n = state.cases.length + 1;
    final num = 8800 + n;
    return 'OPMD-$num-X';
  }

  void createPendingCase({
    required String patientName,
    required String patientAge,
    required PatientGender patientGender,
    required String bloodGroup,
    required String heightCm,
    required String weightKg,
    required String aadhaarNumber,
    required String tobaccoUse,
    required String alcoholUse,
    required String contactPhone,
    required String contactEmail,
    required String imageBase64,
    required String notes,
  }) {
    final now = DateTime.now().toIso8601String();
    final id = nextCaseId();
    final rec = CaseRecord(
      id: id,
      patientName: patientName,
      patientAge: patientAge,
      patientGender: patientGender,
      bloodGroup: bloodGroup,
      heightCm: heightCm,
      weightKg: weightKg,
      aadhaarNumber: aadhaarNumber,
      tobaccoUse: tobaccoUse,
      alcoholUse: alcoholUse,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      imageBase64: imageBase64,
      timestampIso: now,
      status: CaseStatus.pending,
      riskLevel: RiskLevel.high,
      confidence: 0,
      clinicianNotes: '',
      decision: null,
      notes: notes,
    );
    state = state.copyWith(cases: [rec, ...state.cases]);
    addAuditLog(actionType: 'handleCapture', details: 'Created case $id');
    _persist();
  }

  void applySimulatedAnalysis({
    required String caseId,
    required RiskLevel riskLevel,
    required double confidence,
  }) {
    final nextCases = state.cases
        .map((c) => c.id == caseId ? c.copyWith(riskLevel: riskLevel, confidence: confidence) : c)
        .toList(growable: false);
    state = state.copyWith(cases: nextCases);
    addAuditLog(actionType: 'aiAnalysis', details: 'Analysis for $caseId: ${riskLevel.name} ${(confidence).toStringAsFixed(1)}%');
    _persist();
  }

  void reviewCase({
    required String caseId,
    required ClinicianDecision decision,
    required String clinicianNotes,
  }) {
    final nextCases = state.cases
        .map((c) => c.id == caseId
            ? c.copyWith(
                status: CaseStatus.reviewed,
                decision: decision,
                clinicianNotes: clinicianNotes,
              )
            : c)
        .toList(growable: false);
    state = state.copyWith(cases: nextCases);
    addAuditLog(actionType: 'caseReviewed', details: '$caseId reviewed ($decision)');
    _persist();
  }
}

