import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/clinic/clinic_controller.dart';
import '../../features/clinic/clinic_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  int _step = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _step = min(3, _step + 1));
      if (_step >= 3) {
        t.cancel();
        final ctrl = ref.read(clinicControllerProvider.notifier);
        // Simulated AI for prototype
        ctrl.applySimulatedAnalysis(
          caseId: widget.caseId,
          riskLevel: RiskLevel.high,
          confidence: 94.2,
        );
        context.go('/w/success/${widget.caseId}');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.65)),
                ),
                child: const Icon(Icons.biotech_rounded,
                    color: AppColors.primary),
              ),
              const SizedBox(height: 18),
              Text(
                'Analyzing Image',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cross-referencing biopsy datasets',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _Line(
                        done: _step >= 1,
                        label: 'Checking image quality',
                        sub: 'VERIFIED • 4.2K DPI',
                      ),
                      const SizedBox(height: 12),
                      _Line(
                        done: _step >= 2,
                        label: 'Running AI analysis',
                        sub: _step >= 2 ? 'IN PROGRESS...' : '',
                        showProgress: _step == 2,
                      ),
                      const SizedBox(height: 12),
                      _Line(
                        done: _step >= 3,
                        label: 'Preparing report',
                        sub: _step >= 3 ? 'READY' : 'WAITING...',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'Our neural network is identifying cellular patterns associated with OPMD. This typically takes 30–45 seconds.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                            color: scheme.onSurfaceVariant, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.done,
    required this.label,
    required this.sub,
    this.showProgress = false,
  });

  final bool done;
  final String label;
  final String sub;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? AppColors.success.withValues(alpha: 0.2)
                : scheme.surfaceContainerHighest,
            border: Border.all(
                color: scheme.outline.withValues(alpha: 0.65)),
          ),
          child: Icon(
            done ? Icons.check_rounded : Icons.circle_outlined,
            size: 14,
            color: done ? AppColors.success : scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              if (sub.isNotEmpty)
                Text(sub,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              if (showProgress) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 4),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

