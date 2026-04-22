enum PatientGender { male, female, other }

enum CaseStatus { pending, reviewed }

enum RiskLevel { low, moderate, high }

enum ClinicianDecision { confirm, override }

class CaseRecord {
  const CaseRecord({
    required this.id,
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
    required this.imageBase64,
    required this.timestampIso,
    required this.status,
    required this.riskLevel,
    required this.confidence,
    required this.clinicianNotes,
    required this.decision,
    required this.notes,
  });

  final String id;
  final String patientName;
  final String patientAge;
  final PatientGender patientGender;
  final String bloodGroup;
  final String heightCm;
  final String weightKg;
  final String aadhaarNumber;
  /// no | yes | former
  final String tobaccoUse;
  /// no | yes | former
  final String alcoholUse;
  final String contactPhone;
  /// Optional.
  final String contactEmail;
  final String imageBase64;
  final String timestampIso;
  final CaseStatus status;
  final RiskLevel riskLevel;
  final double confidence;
  final String clinicianNotes;
  final ClinicianDecision? decision;
  final String notes;

  Map<String, Object?> toJson() => {
        'id': id,
        'patientName': patientName,
        'patientAge': patientAge,
        'patientGender': patientGender.name,
        'bloodGroup': bloodGroup,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'aadhaarNumber': aadhaarNumber,
        'tobaccoUse': tobaccoUse,
        'alcoholUse': alcoholUse,
        'contactPhone': contactPhone,
        'contactEmail': contactEmail,
        'imageBase64': imageBase64,
        'timestampIso': timestampIso,
        'status': status.name,
        'riskLevel': riskLevel.name,
        'confidence': confidence,
        'clinicianNotes': clinicianNotes,
        'decision': decision?.name,
        'notes': notes,
      };

  static CaseRecord fromJson(Map<String, Object?> json) => CaseRecord(
        id: (json['id'] as String?) ?? '',
        patientName: (json['patientName'] as String?) ?? '',
        patientAge: (json['patientAge'] as String?) ?? '',
        patientGender: PatientGender.values.firstWhere(
          (e) => e.name == (json['patientGender'] as String?),
          orElse: () => PatientGender.other,
        ),
        bloodGroup: (json['bloodGroup'] as String?) ?? '',
        heightCm: (json['heightCm'] as String?) ?? '',
        weightKg: (json['weightKg'] as String?) ?? '',
        aadhaarNumber: (json['aadhaarNumber'] as String?) ?? '',
        tobaccoUse: (json['tobaccoUse'] as String?) ?? '',
        alcoholUse: (json['alcoholUse'] as String?) ?? '',
        contactPhone: (json['contactPhone'] as String?) ?? '',
        contactEmail: (json['contactEmail'] as String?) ?? '',
        imageBase64: (json['imageBase64'] as String?) ?? '',
        timestampIso: (json['timestampIso'] as String?) ?? '',
        status: CaseStatus.values.firstWhere(
          (e) => e.name == (json['status'] as String?),
          orElse: () => CaseStatus.pending,
        ),
        riskLevel: RiskLevel.values.firstWhere(
          (e) => e.name == (json['riskLevel'] as String?),
          orElse: () => RiskLevel.high,
        ),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        clinicianNotes: (json['clinicianNotes'] as String?) ?? '',
        decision: (json['decision'] as String?) == null
            ? null
            : ClinicianDecision.values.firstWhere(
                (e) => e.name == (json['decision'] as String?),
                orElse: () => ClinicianDecision.confirm,
              ),
        notes: (json['notes'] as String?) ?? '',
      );

  CaseRecord copyWith({
    CaseStatus? status,
    RiskLevel? riskLevel,
    double? confidence,
    String? clinicianNotes,
    ClinicianDecision? decision,
  }) {
    return CaseRecord(
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
      timestampIso: timestampIso,
      status: status ?? this.status,
      riskLevel: riskLevel ?? this.riskLevel,
      confidence: confidence ?? this.confidence,
      clinicianNotes: clinicianNotes ?? this.clinicianNotes,
      decision: decision ?? this.decision,
      notes: notes,
    );
  }
}

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.timestampIso,
    required this.actionType,
    required this.details,
  });

  final String id;
  final String timestampIso;
  final String actionType;
  final String details;

  Map<String, Object?> toJson() => {
        'id': id,
        'timestampIso': timestampIso,
        'actionType': actionType,
        'details': details,
      };

  static AuditLogEntry fromJson(Map<String, Object?> json) => AuditLogEntry(
        id: (json['id'] as String?) ?? '',
        timestampIso: (json['timestampIso'] as String?) ?? '',
        actionType: (json['actionType'] as String?) ?? '',
        details: (json['details'] as String?) ?? '',
      );
}

class ClinicState {
  const ClinicState({
    required this.cases,
    required this.auditLogs,
  });

  final List<CaseRecord> cases;
  final List<AuditLogEntry> auditLogs;

  ClinicState copyWith({
    List<CaseRecord>? cases,
    List<AuditLogEntry>? auditLogs,
  }) {
    return ClinicState(
      cases: cases ?? this.cases,
      auditLogs: auditLogs ?? this.auditLogs,
    );
  }

  Map<String, Object?> toJson() => {
        'cases': cases.map((c) => c.toJson()).toList(growable: false),
        'auditLogs': auditLogs.map((a) => a.toJson()).toList(growable: false),
      };

  static ClinicState fromJson(Map<String, Object?> json) => ClinicState(
        cases: (json['cases'] as List?)
                ?.whereType<Map>()
                .map((m) => CaseRecord.fromJson(m.cast<String, Object?>()))
                .toList(growable: false) ??
            const [],
        auditLogs: (json['auditLogs'] as List?)
                ?.whereType<Map>()
                .map((m) => AuditLogEntry.fromJson(m.cast<String, Object?>()))
                .toList(growable: false) ??
            const [],
      );
}

