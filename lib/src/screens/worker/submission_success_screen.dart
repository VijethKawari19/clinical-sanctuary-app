import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/session/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';

class SubmissionSuccessScreen extends ConsumerWidget {
  const SubmissionSuccessScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionControllerProvider).role;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Scrollbar(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x22000000),
                                    blurRadius: 30,
                                    offset: Offset(0, 18),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 44,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Success!',
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Case Submitted Successfully',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE4F7EA),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: scheme.outline.withValues(alpha: 0.55),
                                ),
                              ),
                              child: const Text(
                                'QC PASSED • SECURELY STORED',
                                style: TextStyle(
                                  color: Color(0xFF1B7A3A),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            AppCard(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Text(
                                  "The patient's information and clinical image have been securely uploaded for clinician review.\n\nContinue screening another patient, or log out when you are finished.",
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        height: 1.4,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      if (role == AppRole.clinician) {
                                        context.go('/c/dashboard');
                                        return;
                                      }
                                      ref
                                          .read(
                                            sessionControllerProvider.notifier,
                                          )
                                          .endSession();
                                      context.go('/auth');
                                    },
                                    child: Text(
                                      role == AppRole.clinician
                                          ? 'Back to dashboard'
                                          : 'Logout',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      ref
                                          .read(
                                            sessionControllerProvider.notifier,
                                          )
                                          .clearTempCapture();
                                      context.go('/w/capture');
                                    },
                                    child: const Text('Do more screening'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
