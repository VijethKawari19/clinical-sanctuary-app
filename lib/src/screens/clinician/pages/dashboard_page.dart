import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../features/clinic/clinic_controller.dart';
import '../../../features/settings/settings_controller.dart';

class ClinicianDashboardPage extends ConsumerWidget {
  const ClinicianDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingCountProvider);
    final reviewed = ref.watch(reviewedCountProvider);
    final totalPatients = ref.watch(totalPatientsProvider);
    final profileName = ref.watch(settingsControllerProvider).profileName.trim();

    final scheme = Theme.of(context).colorScheme;
    final welcomeTitle = (profileName.isEmpty || profileName == 'User')
        ? 'Welcome'
        : 'Welcome, $profileName';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        final outer = MediaQuery.sizeOf(context);
        final verticalPadding = isNarrow ? 12.0 : 4.0;

        // Mobile needs scroll; desktop can still scroll but generally fits.
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // Ensure the cards can anchor near the bottom when there's room,
              // but never force a vertical overflow on phones.
              minHeight: outer.height * 0.55,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  welcomeTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Here is your clinical overview for today.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 860;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        _Metric(
                          label: 'PENDING',
                          value: '$pending',
                          icon: Icons.schedule_rounded,
                          width: wide ? (constraints.maxWidth - 28) / 3 : null,
                        ),
                        _Metric(
                          label: 'REVIEWED',
                          value: '$reviewed',
                          icon: Icons.show_chart_rounded,
                          width: wide ? (constraints.maxWidth - 28) / 3 : null,
                        ),
                        _Metric(
                          label: 'TOTAL PATIENTS',
                          value: '$totalPatients',
                          icon: Icons.people_outline_rounded,
                          width: wide ? (constraints.maxWidth - 28) / 3 : null,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 920;
                    final cardWidth = wide ? (constraints.maxWidth - 18) / 2 : null;
                    return Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _ActionCard(
                            title: 'New Screening',
                            description:
                                'Initiate a new oral health screening using the AI-assisted capture tool.',
                            icon: Icons.photo_camera_outlined,
                            linkLabel: 'Start Screening',
                      onTap: () => context.push('/w/patient-info'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _ActionCard(
                            title: 'Review Queue',
                            description:
                                'Review pending submissions from health workers and finalize clinical reports.',
                            icon: Icons.fact_check_outlined,
                            badgeCount: pending,
                            linkLabel: 'View Queue',
                            onTap: () => context.go('/c/queue'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    this.width,
  });

  final String label;
  final String value;
  final IconData icon;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.65)),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.1,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.linkLabel,
    required this.onTap,
    this.badgeCount,
  });

  final String title;
  final String description;
  final IconData icon;
  final int? badgeCount;
  final String linkLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: scheme.outline.withValues(alpha: 0.65)),
                    ),
                    child: Icon(icon, color: AppColors.primary),
                  ),
                  const Spacer(),
                  if (badgeCount != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: scheme.outline.withValues(alpha: 0.65)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.circle,
                              size: 6, color: AppColors.danger),
                          const SizedBox(width: 6),
                          Text(
                            '$badgeCount',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Text(
                '$linkLabel  →',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

