import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/session/session_controller.dart';
class QcProcessingScreen extends ConsumerStatefulWidget {
  const QcProcessingScreen({super.key});

  @override
  ConsumerState<QcProcessingScreen> createState() => _QcProcessingScreenState();
}

class _QcProcessingScreenState extends ConsumerState<QcProcessingScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_runQc());
  }

  Future<void> _runQc() async {
    final buf = ref.read(sessionControllerProvider).tempCaptureBuffer;
    if (buf == null) {
      if (!mounted) return;
      context.go('/w/capture');
      return;
    }

    // Simulated QC. (Next step: Gemini face/oral-cavity validation.)
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final b64 = buf.imageBase64;
    final likelyBad =
        b64.length < 20_000; // very small images tend to be unusable

    if (likelyBad) {
      context.go(
        '/w/qc-fail',
        extra: 'Image quality is too low (blurry or too small). Please recapture.',
      );
      return;
    }

    context.go('/w/patient-info');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Running AI Quality Check…',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Checking privacy (face) and clinical quality (oral cavity).',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

