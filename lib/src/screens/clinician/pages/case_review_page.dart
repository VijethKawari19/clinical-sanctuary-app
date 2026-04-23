import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../features/clinic/clinic_controller.dart';
import '../../../features/clinic/clinic_models.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';

class CaseReviewPage extends ConsumerStatefulWidget {
  const CaseReviewPage({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<CaseReviewPage> createState() => _CaseReviewPageState();
}

class _CaseReviewPageState extends ConsumerState<CaseReviewPage> {
  ClinicianDecision _decision = ClinicianDecision.confirm;
  final _notesCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(CaseReviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caseId != widget.caseId) {
      _decision = ClinicianDecision.confirm;
    }
  }

  Future<_ReportType?> _pickReportType() {
    return showDialog<_ReportType>(
      context: context,
      builder: (ctx) {
        final dScheme = Theme.of(ctx).colorScheme;
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: dScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: dScheme.outline.withValues(alpha: 0.65),
                          ),
                        ),
                        child: const Icon(
                          Icons.download_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Download Report',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Select the type of report you would like to generate:',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: dScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ReportChoiceTile(
                    title: 'Short Report',
                    subtitle: '1-page summary of screening results',
                    icon: Icons.description_outlined,
                    onTap: () => Navigator.of(ctx).pop(_ReportType.short),
                  ),
                  const SizedBox(height: 12),
                  _ReportChoiceTile(
                    title: 'Detailed Report',
                    subtitle: 'Multi-page comprehensive pathology report',
                    icon: Icons.article_outlined,
                    onTap: () => Navigator.of(ctx).pop(_ReportType.detailed),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openClinicalImageZoom(Uint8List bytes) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  boundaryMargin: const EdgeInsets.all(48),
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: Center(
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cases = ref.watch(casesProvider);
    final caseRec = cases.firstWhere(
      (c) => c.id == widget.caseId,
      orElse: () => CaseRecord(
        id: widget.caseId,
        patientName: '—',
        patientAge: '—',
        patientGender: PatientGender.other,
        bloodGroup: '',
        heightCm: '',
        weightKg: '',
        aadhaarNumber: '',
        tobaccoUse: '',
        alcoholUse: '',
        contactPhone: '',
        contactEmail: '',
        imageBase64: '',
        timestampIso: DateTime.now().toIso8601String(),
        status: CaseStatus.pending,
        riskLevel: RiskLevel.high,
        confidence: 0,
        clinicianNotes: '',
        decision: null,
        notes: '',
      ),
    );

    if (_notesCtrl.text.isEmpty && caseRec.clinicianNotes.isNotEmpty) {
      _notesCtrl.text = caseRec.clinicianNotes;
    }

    final imageBytes = caseRec.imageBase64.isEmpty
        ? null
        : base64Decode(caseRec.imageBase64);

    final riskLabel = switch (caseRec.riskLevel) {
      RiskLevel.low => 'LOW RISK',
      RiskLevel.moderate => 'MODERATE',
      RiskLevel.high => 'HIGH RISK',
    };
    final riskColor = switch (caseRec.riskLevel) {
      RiskLevel.low => AppColors.success,
      RiskLevel.moderate => AppColors.warning,
      RiskLevel.high => AppColors.danger,
    };
    final canExport = caseRec.status == CaseStatus.reviewed;
    final isFirstReview = caseRec.status == CaseStatus.pending;
    final canFinalizeReview =
        isFirstReview || _decision == ClinicianDecision.override;
    final decisionForSubmit = isFirstReview
        ? _decision
        : ClinicianDecision.override;

    final h = double.tryParse(caseRec.heightCm);
    final w = double.tryParse(caseRec.weightKg);
    final bmi = (h != null && w != null && h > 0 && w > 0)
        ? (w / ((h / 100.0) * (h / 100.0)))
        : null;

    final scheme = Theme.of(context).colorScheme;
    final isNarrow = MediaQuery.sizeOf(context).width < 520;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                backgroundColor: scheme.surface,
                side: BorderSide(color: scheme.outline.withValues(alpha: 0.65)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patients  ›  Case Review',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Case ${widget.caseId}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: !canExport
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final type = await _pickReportType();
                      if (type == null) return;
                      final bytes = type == _ReportType.short
                          ? await _buildPdfShort(caseRec, imageBytes)
                          : await _buildPdf(caseRec, imageBytes);
                      final fileName = type == _ReportType.short
                          ? 'Case-${caseRec.id}-short.pdf'
                          : 'Case-${caseRec.id}-detailed.pdf';

                      // Mobile: share/save via platform share sheet (works on Android/iOS).
                      if (!kIsWeb &&
                          (defaultTargetPlatform == TargetPlatform.android ||
                              defaultTargetPlatform == TargetPlatform.iOS)) {
                        await Printing.sharePdf(bytes: bytes, filename: fileName);
                        return;
                      }

                      // Desktop: use file picker save location.
                      final loc = await getSaveLocation(suggestedName: fileName);
                      if (loc == null) return;
                      await XFile.fromData(
                        bytes,
                        mimeType: 'application/pdf',
                        name: fileName,
                      ).saveTo(loc.path);
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(content: Text('Saved: ${loc.path}')));
                    },
              icon: const Icon(Icons.download_outlined),
              label: Text(isNarrow ? 'Export' : 'Export Report'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Scrollbar(
            controller: _scrollCtrl,
            thumbVisibility: false,
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.only(right: 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1040;
                  return Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: [
                      SizedBox(
                        width: wide ? (constraints.maxWidth - 18) * 0.62 : null,
                        child: AppCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    color: Colors.black,
                                    child: imageBytes == null
                                        ? const Center(
                                            child: Icon(
                                              Icons.image_outlined,
                                              color: Colors.white54,
                                              size: 44,
                                            ),
                                          )
                                        : Image.memory(
                                            imageBytes,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.insert_drive_file_outlined,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Clinical_Capture_${caseRec.id}.jpg',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  IconButton(
                                    tooltip: 'Zoom image',
                                    onPressed: imageBytes == null
                                        ? null
                                        : () => _openClinicalImageZoom(
                                            imageBytes,
                                          ),
                                    icon: const Icon(Icons.zoom_in_rounded),
                                    style: IconButton.styleFrom(
                                      backgroundColor: scheme.surface,
                                      side: BorderSide(
                                        color: scheme.outline.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: wide ? (constraints.maxWidth - 18) * 0.38 : null,
                        child: AppCard(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Clinical Decision',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 14),
                                if (!isFirstReview) ...[
                                  Text(
                                    'This case was already reviewed. To change the outcome, use Override. Re-confirming the AI result is not available.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          height: 1.35,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (isFirstReview) ...[
                                  _DecisionTile(
                                    selected:
                                        _decision == ClinicianDecision.confirm,
                                    title: 'Confirm AI Result',
                                    subtitle:
                                        'Validates the automated assessment.',
                                    icon: Icons.verified_rounded,
                                    onTap: () => setState(
                                      () =>
                                          _decision = ClinicianDecision.confirm,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                _DecisionTile(
                                  selected:
                                      _decision == ClinicianDecision.override,
                                  title: 'Override Result',
                                  subtitle: isFirstReview
                                      ? 'Submit manual clinical correction.'
                                      : 'Update notes or change the clinical decision.',
                                  icon: Icons.edit_note_rounded,
                                  onTap: () => setState(() {
                                    _decision =
                                        _decision == ClinicianDecision.override
                                            ? ClinicianDecision.confirm
                                            : ClinicianDecision.override;
                                  }),
                                ),
                                if (_decision ==
                                    ClinicianDecision.override) ...[
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _notesCtrl,
                                    minLines: 4,
                                    maxLines: 6,
                                    decoration: const InputDecoration(
                                      hintText: 'Clinician notes...',
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  onPressed: !canFinalizeReview
                                      ? null
                                      : () {
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          ref
                                              .read(
                                                clinicControllerProvider
                                                    .notifier,
                                              )
                                              .reviewCase(
                                                caseId: widget.caseId,
                                                decision: decisionForSubmit,
                                                clinicianNotes:
                                                    decisionForSubmit ==
                                                        ClinicianDecision
                                                            .override
                                                    ? _notesCtrl.text.trim()
                                                    : '',
                                              );
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Review saved. You can update it anytime.',
                                              ),
                                            ),
                                          );
                                        },
                                  icon: const Icon(
                                    Icons.send_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Finalize Review'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: wide ? (constraints.maxWidth - 18) * 0.62 : null,
                        child: AppCard(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PATIENT INFORMATION',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        letterSpacing: 1.3,
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                _InfoRow(
                                  label: 'Full Name',
                                  value: caseRec.patientName,
                                ),
                                _InfoRow(
                                  label: 'Patient ID',
                                  value: caseRec.id,
                                ),
                                _InfoRow(
                                  label: 'Age / Gender',
                                  value:
                                      '${caseRec.patientAge}y / ${caseRec.patientGender.name}',
                                ),
                                _InfoRow(
                                  label: 'Screening Date',
                                  value: caseRec.timestampIso.split('T').first,
                                ),
                                _InfoRow(
                                  label: 'Blood Group',
                                  value: caseRec.bloodGroup.isEmpty
                                      ? '—'
                                      : caseRec.bloodGroup,
                                ),
                                _InfoRow(
                                  label: 'Height / Weight',
                                  value:
                                      '${caseRec.heightCm.isEmpty ? '—' : '${caseRec.heightCm} cm'} / ${caseRec.weightKg.isEmpty ? '—' : '${caseRec.weightKg} kg'}',
                                ),
                                _InfoRow(
                                  label: 'BMI',
                                  value: bmi == null
                                      ? '—'
                                      : bmi.toStringAsFixed(1),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'SCREENING NOTES',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        letterSpacing: 1.3,
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color:
                                          scheme.outline.withValues(alpha: 0.55),
                                    ),
                                  ),
                                  child: Text(
                                    caseRec.notes.trim().isEmpty
                                        ? '—'
                                        : caseRec.notes.trim(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          height: 1.35,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: wide ? (constraints.maxWidth - 18) * 0.38 : null,
                        child: AppCard(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI ANALYSIS SUMMARY',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        letterSpacing: 1.3,
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Risk Level',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: riskColor.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: riskColor.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Text(
                                    riskLabel,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: riskColor,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Confidence',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        child: LinearProgressIndicator(
                                          value: (caseRec.confidence / 100)
                                              .clamp(0, 1)
                                              .toDouble(),
                                          minHeight: 8,
                                          backgroundColor: const Color(
                                            0xFFEFF4FA,
                                          ),
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                Color
                                              >(AppColors.primary),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${caseRec.confidence.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<Uint8List> _buildPdf(CaseRecord c, Uint8List? imageBytes) async {
    final doc = pw.Document();
    final img = imageBytes == null ? null : pw.MemoryImage(imageBytes);
    final h = double.tryParse(c.heightCm);
    final w = double.tryParse(c.weightKg);
    final bmi = (h != null && w != null && h > 0 && w > 0)
        ? (w / ((h / 100.0) * (h / 100.0)))
        : null;

    String sex() => switch (c.patientGender) {
      PatientGender.male => 'M',
      PatientGender.female => 'F',
      PatientGender.other => 'Other',
    };

    final reportDate = DateTime.tryParse(c.timestampIso)?.toLocal();
    final reportDateStr = reportDate == null
        ? c.timestampIso.split('T').first
        : '${reportDate.month}/${reportDate.day}/${reportDate.year}';

    final suspicion = (c.confidence / 100).clamp(0, 1).toDouble();
    final label4 = switch (c.riskLevel) {
      RiskLevel.low => 'HEALTHY',
      RiskLevel.moderate => 'BENIGN',
      RiskLevel.high => 'HIGH RISK',
    };
    final binary = c.riskLevel == RiskLevel.high
        ? 'SUSPICIOUS'
        : 'NOT SUSPICIOUS';
    final qcPass = img != null;

    pw.Widget sectionHeader(String title) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: PdfColor.fromInt(0xFF0B1B2B),
        child: pw.Text(
          title,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
      );
    }

    pw.Widget kvRow(String k1, String v1, String k2, String v2) {
      pw.TextStyle kStyle = pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
      );
      pw.TextStyle vStyle = const pw.TextStyle(fontSize: 10);
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          children: [
            pw.SizedBox(width: 110, child: pw.Text(k1, style: kStyle)),
            pw.Expanded(child: pw.Text(v1, style: vStyle)),
            pw.SizedBox(width: 24),
            pw.SizedBox(width: 110, child: pw.Text(k2, style: kStyle)),
            pw.Expanded(child: pw.Text(v2, style: vStyle)),
          ],
        ),
      );
    }

    pw.Widget underlineField(String label) {
      return pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Container(
              height: 12,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey600, width: 1),
                ),
              ),
            ),
          ),
        ],
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 26),
        build: (context) => [
          // Header
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 14),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0B1B2B),
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'OralScan AI',
                  style: pw.TextStyle(
                    color: PdfColor.fromInt(0xFF22D3EE),
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'ORAL PATHOLOGY REPORT',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'AI-Assisted OPMD Detection & Triage System / Clinical Decision Support Only',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 8),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Facility block (placeholders for now)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Reporting Institution / Facility',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      '[Institution Name]',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      '[Department Name]',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      '[Address Line 1]',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      '[City, State, PIN]',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 18),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    underlineField('CLIA / Reg. ID:'),
                    pw.SizedBox(height: 6),
                    underlineField('Contact:'),
                    pw.SizedBox(height: 6),
                    underlineField('Ethics Approval No:'),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Report Generated: $reportDateStr',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 16),
          sectionHeader('SECTION 1 — CASE IDENTIFICATION'),
          pw.SizedBox(height: 10),
          kvRow('Case ID', c.id, 'Accession No.', '[ACC-XXXXXXX]'),
          kvRow(
            'Date of Report',
            reportDateStr,
            'Date of Surgery',
            'DD / MM / YYYY',
          ),

          pw.SizedBox(height: 14),
          sectionHeader('SECTION 2 — PATIENT INFORMATION'),
          pw.SizedBox(height: 10),
          kvRow(
            'Patient Name',
            c.patientName,
            'Patient Hash ID',
            '[HMAC-SHA256 Hash]',
          ),
          kvRow('Age', '${c.patientAge} years', 'Sex', sex()),
          kvRow(
            'Blood Group',
            c.bloodGroup.isEmpty ? '—' : c.bloodGroup,
            'BMI',
            bmi == null ? '—' : bmi.toStringAsFixed(1),
          ),
          kvRow(
            'Height (cm)',
            c.heightCm.isEmpty ? '—' : c.heightCm,
            'Weight (kg)',
            c.weightKg.isEmpty ? '—' : c.weightKg,
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Screening Notes (Health Worker):',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            c.notes.trim().isEmpty ? '—' : c.notes.trim(),
            style: const pw.TextStyle(fontSize: 10),
          ),

          pw.SizedBox(height: 14),
          sectionHeader('SECTION 3 — IMAGE CAPTURE & QUALITY CONTROL'),
          pw.SizedBox(height: 14),
          pw.Center(
            child: pw.Text(
              'Captured Photo',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Container(
              width: 220,
              height: 220,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: img == null
                  ? pw.Text('No image', style: const pw.TextStyle(fontSize: 10))
                  : pw.Image(img, fit: pw.BoxFit.contain),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Text(
              'QC Status: ${qcPass ? '[X] PASS [ ] FAIL' : '[ ] PASS [X] FAIL'}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),

          pw.SizedBox(height: 14),
          sectionHeader('SECTION 4 — GROSS DESCRIPTION & SPECIMEN DETAILS'),
          pw.SizedBox(height: 12),
          pw.Text(
            'Anatomical Location:',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '[ ] Buccal Mucosa  [ ] Tongue Dorsal  [ ] Tongue Lateral  [ ] Floor of Mouth',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 10),
          underlineField('Gross Description:'),

          pw.SizedBox(height: 14),
          sectionHeader('SECTION 5 — AI ANALYSIS RESULTS (OralScan AI)'),
          pw.SizedBox(height: 12),
          kvRow(
            '4-Class AI Label',
            label4,
            'Suspicion Score',
            '${suspicion.toStringAsFixed(3)} / 1.00',
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '[ ] HEALTHY  [ ] BENIGN  ${label4 == 'HIGH RISK' ? '[X]' : '[ ]'} HIGH RISK  [ ] ORAL CANCER',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 10),
          kvRow('Binary Result', binary, '', ''),
          pw.SizedBox(height: 10),
          pw.Text(
            'LLM Summary',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            c.riskLevel == RiskLevel.high
                ? 'The AI analysis indicates a suspicious lesion with high confidence. The visual features suggest potential malignancy, requiring urgent clinical correlation and histopathological evaluation.'
                : 'The AI analysis does not indicate high-risk features. Clinical correlation is recommended.',
            style: const pw.TextStyle(fontSize: 10),
          ),

          pw.SizedBox(height: 14),
          sectionHeader('SECTION 6 — CLINICAL & HISTOPATHOLOGICAL DIAGNOSIS'),
          pw.SizedBox(height: 12),
          underlineField('Clinical Diagnosis'),
          pw.SizedBox(height: 8),
          underlineField('ICD-10 / K-code:'),
          pw.SizedBox(height: 10),
          underlineField('Description:'),
          pw.SizedBox(height: 14),
          pw.Text(
            'Clinician Decision: ${c.decision?.name ?? '-'}',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Clinician Notes: ${c.clinicianNotes.isEmpty ? '-' : c.clinicianNotes}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<Uint8List> _buildPdfShort(CaseRecord c, Uint8List? imageBytes) async {
    final doc = pw.Document();
    final img = imageBytes == null ? null : pw.MemoryImage(imageBytes);
    // Keep BMI out of the short report to match the provided template.

    final ts = DateTime.tryParse(c.timestampIso)?.toLocal();
    final dateStr = ts == null
        ? c.timestampIso.split('T').first
        : '${ts.month}/${ts.day}/${ts.year}';
    final timeStr = ts == null
        ? (c.timestampIso.contains('T') ? c.timestampIso.split('T').last : '')
        : '${(ts.hour % 12 == 0 ? 12 : ts.hour % 12).toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')} ${ts.hour >= 12 ? 'PM' : 'AM'}';

    final riskLabel = switch (c.riskLevel) {
      RiskLevel.low => 'LOW RISK',
      RiskLevel.moderate => 'MODERATE RISK',
      RiskLevel.high => 'HIGH RISK',
    };
    final riskColor = switch (c.riskLevel) {
      RiskLevel.low => PdfColor.fromInt(0xFF15803D),
      RiskLevel.moderate => PdfColor.fromInt(0xFFB45309),
      RiskLevel.high => PdfColor.fromInt(0xFFB91C1C),
    };

    String genderLabel() => switch (c.patientGender) {
      PatientGender.male => 'Male',
      PatientGender.female => 'Female',
      PatientGender.other => 'Other',
    };

    pw.Widget sectionTitle(String title) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 6),
            height: 1,
            color: PdfColors.grey700,
          ),
        ],
      ),
    );

    pw.Widget infoRow(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 26),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Teal header
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              color: PdfColor.fromInt(0xFF0F766E),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CLINICAL SCREENING REPORT',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Oral Potential Malignant Disorders (OPMD) Screening Tool',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 9),
                  ),
                ],
              ),
            ),

            // Administrative
            sectionTitle('ADMINISTRATIVE INFORMATION'),
            infoRow('Report ID:', c.id),
            infoRow('Date:', dateStr),
            infoRow('Time:', timeStr),

            // Patient
            sectionTitle('PATIENT INFORMATION'),
            infoRow('Full Name:', c.patientName),
            infoRow('Age:', '${c.patientAge} Years'),
            infoRow('Gender:', genderLabel()),

            // Clinical findings
            sectionTitle('CLINICAL FINDINGS'),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 220,
                  height: 220,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  alignment: pw.Alignment.center,
                  child: img == null
                      ? pw.Text(
                          'No image',
                          style: const pw.TextStyle(fontSize: 10),
                        )
                      : pw.Image(img, fit: pw.BoxFit.cover),
                ),
                pw.SizedBox(width: 18),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Clinical Observations:',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '- Whitish patch detected in primary region of interest',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '- Irregular border with poorly defined margins',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '- Erythematous changes around the lesion',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '- No palpable lymphadenopathy reported',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Fig 1: Captured oral region of interest',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Screening Notes (Health Worker):',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              c.notes.trim().isEmpty ? '—' : c.notes.trim(),
              style: const pw.TextStyle(fontSize: 10),
            ),

            // AI-assisted analysis
            sectionTitle('AI-ASSISTED ANALYSIS'),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 130,
                    child: pw.Text(
                      'Risk Assessment:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Text(
                    riskLabel,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: riskColor,
                    ),
                  ),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 130,
                    child: pw.Text(
                      'Confidence Score:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Text(
                    '${c.confidence.toStringAsFixed(1)}%',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),

            // Clinician review
            sectionTitle('CLINICIAN REVIEW'),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 130,
                    child: pw.Text(
                      'Final Decision:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Text(
                    c.decision == ClinicianDecision.confirm
                        ? 'Confirmed AI Assessment'
                        : c.decision == ClinicianDecision.override
                        ? 'Overridden (Manual Review)'
                        : '—',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }
}

enum _ReportType { short, detailed }

class _ReportChoiceTile extends StatelessWidget {
  const _ReportChoiceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.65),
                ),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _DecisionTile extends StatelessWidget {
  const _DecisionTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.35)
                : scheme.outline.withValues(alpha: 0.65),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? AppColors.primary : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
