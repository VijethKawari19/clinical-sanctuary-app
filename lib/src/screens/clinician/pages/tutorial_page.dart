import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/settings/settings_controller.dart';
import '../../../features/settings/settings_state.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';

enum _TutorialTrack { worker, clinician }

class TutorialPage extends ConsumerWidget {
  const TutorialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    final initialTrack = settings.profileRole.toUpperCase().contains('WORKER')
        ? _TutorialTrack.worker
        : _TutorialTrack.clinician;

    return DefaultTabController(
      length: 2,
      initialIndex: initialTrack == _TutorialTrack.worker ? 0 : 1,
      child: Column(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tutorial',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      settings.tutorialSeen
                          ? 'Pick a track, resume where you left off.'
                          : 'Start here to learn the end-to-end workflow.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (!settings.tutorialSeen)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(6),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: scheme.onPrimaryContainer,
              unselectedLabelColor: scheme.onSurfaceVariant,
              indicator: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.25),
                ),
              ),
              tabs: const [
                Tab(text: 'Health Worker'),
                Tab(text: 'Clinician'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: TabBarView(
              children: [
                _TrackStepper(
                  track: _TutorialTrack.worker,
                  settings: settings,
                  onStepChanged: (step) => ctrl.setTutorialWorkerStep(step),
                  onComplete: () => ctrl.setTutorialSeen(true),
                  onQuickAction: (action) {
                    switch (action) {
                      case _QuickAction.startScreening:
                        context.go('/w/consent');
                      case _QuickAction.openCapture:
                        context.go('/w/capture');
                      case _QuickAction.openQueue:
                        context.go('/c/queue');
                      case _QuickAction.openDashboard:
                        context.go('/c/dashboard');
                    }
                  },
                ),
                _TrackStepper(
                  track: _TutorialTrack.clinician,
                  settings: settings,
                  onStepChanged: (step) => ctrl.setTutorialClinicianStep(step),
                  onComplete: () => ctrl.setTutorialSeen(true),
                  onQuickAction: (action) {
                    switch (action) {
                      case _QuickAction.startScreening:
                        context.go('/w/consent');
                      case _QuickAction.openCapture:
                        context.go('/w/capture');
                      case _QuickAction.openQueue:
                        context.go('/c/queue');
                      case _QuickAction.openDashboard:
                        context.go('/c/dashboard');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _QuickAction { startScreening, openCapture, openQueue, openDashboard }

class _TrackStepper extends StatelessWidget {
  const _TrackStepper({
    required this.track,
    required this.settings,
    required this.onStepChanged,
    required this.onComplete,
    required this.onQuickAction,
  });

  final _TutorialTrack track;
  final SettingsState settings;
  final ValueChanged<int> onStepChanged;
  final VoidCallback onComplete;
  final ValueChanged<_QuickAction> onQuickAction;

  int get _currentStep => track == _TutorialTrack.worker
      ? settings.tutorialWorkerStep
      : settings.tutorialClinicianStep;

  @override
  Widget build(BuildContext context) {
    final steps = track == _TutorialTrack.worker
        ? _workerSteps(context)
        : _clinicianSteps(context);

    final clampedStep = _currentStep.clamp(0, (steps.length - 1).clamp(0, 999));
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Stepper(
          currentStep: clampedStep,
          type: StepperType.vertical,
          onStepTapped: onStepChanged,
          onStepContinue: () {
            final next = clampedStep + 1;
            if (next >= steps.length) {
              onComplete();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tutorial completed.')),
                );
              }
              return;
            }
            onStepChanged(next);
          },
          onStepCancel: () {
            final prev = clampedStep - 1;
            if (prev < 0) return;
            onStepChanged(prev);
          },
          controlsBuilder: (context, details) {
            final isLast = clampedStep == steps.length - 1;
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: details.onStepContinue,
                    icon: Icon(isLast ? Icons.check_rounded : Icons.arrow_forward),
                    label: Text(isLast ? 'Finish' : 'Next'),
                  ),
                  if (clampedStep > 0)
                    OutlinedButton.icon(
                      onPressed: details.onStepCancel,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back'),
                    ),
                  const SizedBox(width: 6),
                  if (track == _TutorialTrack.worker) ...[
                    _QuickChip(
                      label: 'Start Screening',
                      icon: Icons.play_arrow_rounded,
                      onTap: () => onQuickAction(_QuickAction.startScreening),
                    ),
                    _QuickChip(
                      label: 'Open Capture',
                      icon: Icons.photo_camera_rounded,
                      onTap: () => onQuickAction(_QuickAction.openCapture),
                    ),
                  ] else ...[
                    _QuickChip(
                      label: 'Open Dashboard',
                      icon: Icons.space_dashboard_outlined,
                      onTap: () => onQuickAction(_QuickAction.openDashboard),
                    ),
                    _QuickChip(
                      label: 'Open Queue',
                      icon: Icons.people_outline_rounded,
                      onTap: () => onQuickAction(_QuickAction.openQueue),
                    ),
                  ],
                  if (settings.tutorialSeen)
                    Text(
                      'Saved',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                    ),
                ],
              ),
            );
          },
          steps: steps,
        ),
      ),
    );
  }

  List<Step> _workerSteps(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget tip(String title, String body, {IconData icon = Icons.info_outline}) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.55)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 10),
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
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.35,
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return [
      Step(
        title: const Text('Consent & 준비'),
        subtitle: const Text('Start a new screening session'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Before you capture any image, confirm the patient understands the purpose of screening and agrees.',
            ),
            const SizedBox(height: 10),
            tip(
              'Good practice',
              'Use a clean light source. Ask the patient to remove masks or obstructions and sit still for 5–10 seconds.',
            ),
          ],
        ),
        isActive: true,
      ),
      Step(
        title: const Text('Capture mouth/teeth only'),
        subtitle: const Text('System / Wireless / Gallery'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Capture a close-up of the oral region of interest. Avoid full-face photos.',
            ),
            const SizedBox(height: 10),
            tip(
              'Automatic rejection (System Camera)',
              'If a full face is detected, the app will reject the photo and ask you to retake it.',
              icon: Icons.no_accounts_rounded,
            ),
            const SizedBox(height: 10),
            tip(
              'Framing checklist',
              'Fill the frame with mouth/teeth, keep focus sharp, and ensure even lighting (no harsh shadows).',
              icon: Icons.center_focus_strong_rounded,
            ),
          ],
        ),
        isActive: true,
      ),
      Step(
        title: const Text('Review & confirm'),
        subtitle: const Text('Retake if quality is low'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use Review to zoom and confirm the image is clear. Retake if blurry or too dark.',
            ),
            const SizedBox(height: 10),
            tip(
              'Quality matters',
              'Blurry images reduce confidence. If the patient moves, take another shot.',
              icon: Icons.auto_fix_high_rounded,
            ),
          ],
        ),
        isActive: true,
      ),
      Step(
        title: const Text('Enter patient details'),
        subtitle: const Text('Add notes from screening'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fill patient demographics and add “Additional Notes” with relevant observations.',
            ),
            const SizedBox(height: 10),
            tip(
              'Write actionable notes',
              'Location, appearance, pain/bleeding, duration, tobacco/alcohol history—keep it short and specific.',
              icon: Icons.edit_note_rounded,
            ),
          ],
        ),
        isActive: true,
      ),
      Step(
        title: const Text('Submit & track'),
        subtitle: const Text('Wait for clinician review'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'After submission, the case is queued for review. You can start a new screening immediately.',
            ),
            const SizedBox(height: 10),
            tip(
              'Next step',
              'If the clinician requests a retake, capture a tighter mouth-only image and resubmit.',
              icon: Icons.task_alt_rounded,
            ),
          ],
        ),
        isActive: true,
      ),
    ];
  }

  List<Step> _clinicianSteps(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget tip(String title, String body, {IconData icon = Icons.info_outline}) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.55)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 10),
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
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.35,
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return [
      Step(
        title: const Text('Dashboard overview'),
        subtitle: const Text('See pending + reviewed cases'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use Dashboard to monitor volume, pending queue, and recent activity.',
            ),
            const SizedBox(height: 10),
            tip(
              'Triage',
              'Prioritize HIGH RISK cases first and confirm image quality before making a decision.',
              icon: Icons.warning_amber_rounded,
            ),
          ],
        ),
        isActive: true,
      ),
      Step(
        title: const Text('Review the patient queue'),
        subtitle: const Text('Search, filter, prioritize'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use the queue filters to find cases quickly (risk, status, ID/name).',
            ),
            const SizedBox(height: 10),
            tip(
              'Screening notes',
              'Worker screening notes appear on the case card preview and inside the case review details.',
              icon: Icons.edit_note_rounded,
            ),
          ],
        ),
        isActive: true,
      ),
      Step(
        title: const Text('Case review'),
        subtitle: const Text('Image + AI result + notes'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Open a case to inspect the image (zoom), review AI risk/confidence, and check patient details.',
            ),
            const SizedBox(height: 10),
            tip(
              'Quality first',
              'If the image is not mouth/teeth-focused or is low quality, request a retake before finalizing.',
              icon: Icons.center_focus_strong_rounded,
            ),
          ],
        ),
        isActive: true,
      ),
      Step(
        title: const Text('Finalize decision'),
        subtitle: const Text('Confirm or override'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirm AI or Override with clinician notes. Overrides can update outcomes later.',
            ),
            const SizedBox(height: 10),
            tip(
              'Write clinician notes',
              'Document the rationale for overrides and recommended next actions (referral, biopsy, follow-up).',
              icon: Icons.assignment_rounded,
            ),
          ],
        ),
        isActive: true,
      ),
      Step(
        title: const Text('Export report'),
        subtitle: const Text('Short or detailed PDF'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export a short or detailed report for reviewed cases. Include clinician notes as needed.',
            ),
            const SizedBox(height: 10),
            tip(
              'Privacy',
              'Avoid sharing identifying data outside approved channels. Use your facility’s secure workflow.',
              icon: Icons.shield_outlined,
            ),
          ],
        ),
        isActive: true,
      ),
    ];
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.65)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

