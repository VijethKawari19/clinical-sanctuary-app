import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/clinic/clinic_controller.dart';
import '../../features/clinic/clinic_models.dart';
import '../../features/session/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';

class PatientInfoScreen extends ConsumerStatefulWidget {
  const PatientInfoScreen({super.key});

  @override
  ConsumerState<PatientInfoScreen> createState() => _PatientInfoScreenState();
}

class _PatientInfoScreenState extends ConsumerState<PatientInfoScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  PatientGender _gender = PatientGender.male;
  String? _bloodGroupPick;
  String? _tobaccoUse;
  String? _alcoholUse;

  static const _bloodGroups = <String>[
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  static const _yesNoFormer = <String>['No', 'Yes', 'Former'];
  static const double _maxHeightCm = 271;
  static const double _maxWeightKg = 300;

  String? get _heightError {
    final raw = _heightCtrl.text.trim();
    if (raw.isEmpty) return null;
    final v = double.tryParse(raw);
    if (v == null) return 'Enter a valid number.';
    if (v <= 0) return 'Height must be greater than 0.';
    if (v > _maxHeightCm) return 'Max height is ${_maxHeightCm.toInt()} cm.';
    return null;
  }

  String? get _weightError {
    final raw = _weightCtrl.text.trim();
    if (raw.isEmpty) return null;
    final v = double.tryParse(raw);
    if (v == null) return 'Enter a valid number.';
    if (v <= 0) return 'Weight must be greater than 0.';
    if (v > _maxWeightKg) return 'Max weight is ${_maxWeightKg.toInt()} kg.';
    return null;
  }

  double? get _bmi {
    final h = double.tryParse(_heightCtrl.text.trim());
    final w = double.tryParse(_weightCtrl.text.trim());
    if (h == null || w == null || h <= 0 || w <= 0) return null;
    final hm = h / 100.0;
    final bmi = w / (hm * hm);
    if (bmi.isNaN || bmi.isInfinite) return null;
    return bmi;
  }

  void _showWhyRed(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invalid value'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _aadhaarCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _valid {
    final name = _nameCtrl.text.trim();
    final nameOk = name.isNotEmpty && RegExp(r'^[A-Za-z ]+$').hasMatch(name);

    final age = int.tryParse(_ageCtrl.text.trim());
    final ageOk = age != null && age >= 1 && age <= 120;

    final bloodOk = _bloodGroupPick != null;

    final heightOk = _heightError == null && _heightCtrl.text.trim().isNotEmpty;

    final weightOk = _weightError == null && _weightCtrl.text.trim().isNotEmpty;

    final aadhaar = _aadhaarCtrl.text.trim();
    final aadhaarOk = RegExp(r'^\d{12}$').hasMatch(aadhaar);

    final phoneOk = _phoneCtrl.text.trim().length == 10;

    final email = _emailCtrl.text.trim();
    final emailOk =
        email.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

    final tobaccoOk = _tobaccoUse != null;
    final alcoholOk = _alcoholUse != null;

    return nameOk &&
        ageOk &&
        bloodOk &&
        heightOk &&
        weightOk &&
        aadhaarOk &&
        tobaccoOk &&
        alcoholOk &&
        phoneOk &&
        emailOk;
  }

  /// [context.go] to this screen leaves no stack entry, so [pop] does nothing.
  void _leavePatientInfo() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    ref.read(sessionControllerProvider.notifier).clearTempCapture();
    if (mounted) context.go('/w/capture');
  }

  @override
  Widget build(BuildContext context) {
    final buf = ref.watch(sessionControllerProvider).tempCaptureBuffer;
    if (buf == null) {
      // Entered without a capture buffer (e.g., deep link). Send back to capture.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/w/capture');
      });
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _leavePatientInfo,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Patient Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Scrollbar(
                    controller: _scrollCtrl,
                    thumbVisibility: false,
                    child: SingleChildScrollView(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(18),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 980;
                          return Wrap(
                            spacing: 18,
                            runSpacing: 18,
                            children: [
                            SizedBox(
                              width: wide ? (constraints.maxWidth - 18) * 0.65 : null,
                              child: AppCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Enter basic details to complete the screening submission.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                color: scheme.onSurfaceVariant),
                                      ),
                                      const SizedBox(height: 16),
                                      _Field(
                                        label: 'Full Name',
                                        icon: Icons.person_outline_rounded,
                                        child: TextField(
                                          controller: _nameCtrl,
                                          onChanged: (_) => setState(() {}),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                              RegExp(r'[A-Za-z ]'),
                                            ),
                                          ],
                                          textCapitalization:
                                              TextCapitalization.words,
                                          decoration: const InputDecoration(
                                            hintText: 'e.g. John Doe',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _Field(
                                              label: 'Age',
                                              icon: Icons.calendar_month_outlined,
                                              child: TextField(
                                                controller: _ageCtrl,
                                                onChanged: (_) => setState(() {}),
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                  LengthLimitingTextInputFormatter(
                                                    3,
                                                  ),
                                                ],
                                                decoration: const InputDecoration(
                                                  hintText: 'Years',
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _Field(
                                              label: 'Gender',
                                              icon: Icons.group_outlined,
                                              child: DropdownButtonFormField<PatientGender>(
                                                initialValue: _gender,
                                                items: const [
                                                  DropdownMenuItem(
                                                    value: PatientGender.male,
                                                    child: Text('Male'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: PatientGender.female,
                                                    child: Text('Female'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: PatientGender.other,
                                                    child: Text('Other'),
                                                  ),
                                                ],
                                                onChanged: (v) =>
                                                    setState(() => _gender = v!),
                                                decoration:
                                                    const InputDecoration(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _Field(
                                        label: 'Blood Group',
                                        icon: Icons.bloodtype_outlined,
                                        child: DropdownButtonFormField<String>(
                                          key: ValueKey(_bloodGroupPick),
                                          initialValue: _bloodGroupPick,
                                          decoration: const InputDecoration(
                                            hintText: 'Select blood group',
                                          ),
                                          items: _bloodGroups
                                              .map(
                                                (bg) => DropdownMenuItem(
                                                  value: bg,
                                                  child: Text(bg),
                                                ),
                                              )
                                              .toList(growable: false),
                                          onChanged: (v) =>
                                              setState(() => _bloodGroupPick = v),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _Field(
                                              label: 'Height (cm)',
                                              icon: Icons.height_rounded,
                                              child: TextField(
                                                controller: _heightCtrl,
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(
                                                    RegExp(r'[0-9.]'),
                                                  ),
                                                  LengthLimitingTextInputFormatter(5),
                                                ],
                                                onChanged: (_) => setState(() {}),
                                                decoration: InputDecoration(
                                                  hintText: 'Max 271',
                                                  errorText: _heightError,
                                                  suffixIcon: _heightError == null
                                                      ? null
                                                      : IconButton(
                                                          tooltip: 'Why is this red?',
                                                          icon: const Icon(
                                                            Icons.info_outline_rounded,
                                                          ),
                                                          onPressed: () => _showWhyRed(
                                                            _heightError!,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _Field(
                                              label: 'Weight (kg)',
                                              icon: Icons.monitor_weight_outlined,
                                              child: TextField(
                                                controller: _weightCtrl,
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(
                                                    RegExp(r'[0-9.]'),
                                                  ),
                                                  LengthLimitingTextInputFormatter(5),
                                                ],
                                                onChanged: (_) => setState(() {}),
                                                decoration: InputDecoration(
                                                  hintText: 'Max 300',
                                                  errorText: _weightError,
                                                  suffixIcon: _weightError == null
                                                      ? null
                                                      : IconButton(
                                                          tooltip: 'Why is this red?',
                                                          icon: const Icon(
                                                            Icons.info_outline_rounded,
                                                          ),
                                                          onPressed: () => _showWhyRed(
                                                            _weightError!,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_bmi != null) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          'BMI: ${_bmi!.toStringAsFixed(1)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      _Field(
                                        label: 'Aadhaar Number',
                                        icon: Icons.credit_card_outlined,
                                        child: TextField(
                                          controller: _aadhaarCtrl,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(12),
                                          ],
                                          onChanged: (_) => setState(() {}),
                                          decoration: const InputDecoration(
                                            hintText: '12 digits',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _Field(
                                              label: 'Tobacco Use',
                                              icon: Icons.smoking_rooms_outlined,
                                              child: DropdownButtonFormField<String>(
                                                key: ValueKey(_tobaccoUse),
                                                initialValue: _tobaccoUse,
                                                items: _yesNoFormer
                                                    .map(
                                                      (v) => DropdownMenuItem(
                                                        value: v,
                                                        child: Text(v),
                                                      ),
                                                    )
                                                    .toList(growable: false),
                                                onChanged: (v) =>
                                                    setState(() => _tobaccoUse = v),
                                                decoration: const InputDecoration(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _Field(
                                              label: 'Alcohol',
                                              icon: Icons.local_bar_outlined,
                                              child: DropdownButtonFormField<String>(
                                                key: ValueKey(_alcoholUse),
                                                initialValue: _alcoholUse,
                                                items: _yesNoFormer
                                                    .map(
                                                      (v) => DropdownMenuItem(
                                                        value: v,
                                                        child: Text(v),
                                                      ),
                                                    )
                                                    .toList(growable: false),
                                                onChanged: (v) =>
                                                    setState(() => _alcoholUse = v),
                                                decoration: const InputDecoration(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Patient Contact Details',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _Field(
                                              label: 'Phone',
                                              icon: Icons.phone_outlined,
                                              child: TextField(
                                                controller: _phoneCtrl,
                                                keyboardType: TextInputType.phone,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.digitsOnly,
                                                  LengthLimitingTextInputFormatter(10),
                                                ],
                                                onChanged: (_) => setState(() {}),
                                                decoration: const InputDecoration(
                                                  hintText: '10-digit number',
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _Field(
                                              label: 'Email (optional)',
                                              icon: Icons.alternate_email_rounded,
                                              child: TextField(
                                                controller: _emailCtrl,
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                onChanged: (_) => setState(() {}),
                                                decoration: const InputDecoration(
                                                  hintText: 'name@example.com',
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _Field(
                                        label: 'Additional Notes',
                                        icon: Icons.edit_note_rounded,
                                        child: TextField(
                                          controller: _notesCtrl,
                                          minLines: 5,
                                          maxLines: 7,
                                          decoration: const InputDecoration(
                                            hintText:
                                                'Any relevant clinical observations...',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          OutlinedButton(
                                            onPressed: _leavePatientInfo,
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(140, 48),
                                            ),
                                            child: const Text('Back'),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: !_valid
                                                  ? null
                                                  : () {
                                                      final img = buf?.imageBase64;
                                                      if (img == null) {
                                                        context.go('/w/capture');
                                                        return;
                                                      }
                                                      final ctrl = ref.read(
                                                          clinicControllerProvider
                                                              .notifier);
                                                      ctrl.createPendingCase(
                                                        patientName:
                                                            _nameCtrl.text.trim(),
                                                        patientAge:
                                                            _ageCtrl.text.trim(),
                                                        patientGender: _gender,
                                                        bloodGroup:
                                                            _bloodGroupPick!,
                                                        heightCm:
                                                            _heightCtrl.text.trim(),
                                                        weightKg:
                                                            _weightCtrl.text.trim(),
                                                        aadhaarNumber:
                                                            _aadhaarCtrl.text.trim(),
                                                        tobaccoUse:
                                                            _tobaccoUse!.toLowerCase(),
                                                        alcoholUse:
                                                            _alcoholUse!.toLowerCase(),
                                                        contactPhone:
                                                            _phoneCtrl.text.trim(),
                                                        contactEmail:
                                                            _emailCtrl.text.trim(),
                                                        imageBase64:
                                                            img,
                                                        notes:
                                                            _notesCtrl.text.trim(),
                                                      );
                                                      final createdId = ref
                                                          .read(
                                                              clinicControllerProvider)
                                                          .cases
                                                          .first
                                                          .id;
                                                      context.push(
                                                        '/w/processing/$createdId',
                                                      );
                                                    },
                                              icon: const Icon(
                                                  Icons.send_rounded, size: 18),
                                              label: const Text(
                                                'Save & Submit Case',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                softWrap: false,
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                minimumSize: const Size(0, 48),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 12,
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
                            ),
                            SizedBox(
                              width: wide ? (constraints.maxWidth - 18) * 0.35 : null,
                              child: AppCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.info_outline_rounded,
                                              color: AppColors.primary),
                                          const SizedBox(width: 10),
                                          Text(
                                            'What happens next?',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(fontWeight: FontWeight.w900),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'The captured image and patient data will be securely uploaded for clinician review.\n\nYou will be redirected back to the screening start page.',
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          height: 1.4,
                                        ),
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
            ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.icon, required this.child});

  final String label;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

