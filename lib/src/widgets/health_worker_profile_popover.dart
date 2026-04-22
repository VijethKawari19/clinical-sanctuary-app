import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../features/session/session_controller.dart';
import '../features/settings/settings_controller.dart';
import '../features/settings/settings_state.dart';
import '../theme/app_theme.dart';

/// Profile popover for health workers only: theme controls and logout.
class HealthWorkerProfilePopover extends ConsumerWidget {
  const HealthWorkerProfilePopover({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: scheme.outline.withValues(alpha: 0.55)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x20000000),
              blurRadius: 28,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surface,
                      side: BorderSide(
                          color: scheme.outline.withValues(alpha: 0.65)),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: scheme.surface, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 18,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: settings.profilePhotoBase64 == null
                              ? const Icon(Icons.person,
                                  color: AppColors.primary, size: 40)
                              : Image.memory(
                                  base64Decode(settings.profilePhotoBase64!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) =>
                                      const Icon(Icons.person,
                                          color: AppColors.primary, size: 40),
                                ),
                        ),
                      ),
                      Positioned(
                        right: -8,
                        bottom: -8,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () async {
                              final file = await ImagePicker()
                                  .pickImage(source: ImageSource.gallery);
                              if (file == null) return;
                              await ctrl.importProfilePhoto(file);
                            },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(44, 44),
                            ),
                            child: const Icon(Icons.photo_camera_outlined,
                                size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    settings.profileName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'HEALTH WORKER',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          letterSpacing: 2,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileRow(
                    icon: Icons.mail_outline_rounded,
                    text: settings.profileEmail,
                  ),
                  const SizedBox(height: 10),
                  _ProfileRow(
                    icon: Icons.calendar_month_outlined,
                    text: 'Joined: ${settings.profileJoinedIso}',
                  ),
                  const SizedBox(height: 10),
                  const _ProfileRow(
                    icon: Icons.info_outline_rounded,
                    text: 'Account Active',
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'APP THEME',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.3,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  _ThemeRow(
                    settings: settings,
                    onLight: () async => ctrl.setThemeMode(AppThemeMode.light),
                    onDark: () async => ctrl.setThemeMode(AppThemeMode.dark),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.appNestedTileFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: scheme.outline.withValues(alpha: 0.65)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.contrast_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'High contrast',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Switch(
                          value: settings.highContrastEnabled,
                          onChanged: (v) => ctrl.setHighContrastEnabled(v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(
                      height: 1,
                      color: scheme.outline.withValues(alpha: 0.45)),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      onClose();
                      ref.read(sessionControllerProvider.notifier).endSession();
                      context.go('/auth');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.logout_rounded,
                              color: AppColors.danger),
                          const SizedBox(width: 12),
                          Text(
                            'Logout',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.settings,
    required this.onLight,
    required this.onDark,
  });

  final SettingsState settings;
  final Future<void> Function() onLight;
  final Future<void> Function() onDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = settings.themeMode == AppThemeMode.light;
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: OutlinedButton(
              onPressed: () async {
                await onLight();
              },
              style: OutlinedButton.styleFrom(
                backgroundColor:
                    isLight ? scheme.primaryContainer : scheme.surface,
                side: BorderSide(
                  color: isLight
                      ? scheme.primary.withValues(alpha: 0.35)
                      : scheme.outline.withValues(alpha: 0.65),
                ),
                foregroundColor: scheme.onSurface,
                minimumSize: const Size(0, 44),
              ),
              child: const Text('Light'),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: OutlinedButton(
              onPressed: () async {
                await onDark();
              },
              style: OutlinedButton.styleFrom(
                backgroundColor:
                    !isLight ? scheme.primaryContainer : scheme.surface,
                side: BorderSide(
                  color: !isLight
                      ? scheme.primary.withValues(alpha: 0.35)
                      : scheme.outline.withValues(alpha: 0.65),
                ),
                foregroundColor: scheme.onSurface,
                minimumSize: const Size(0, 44),
              ),
              child: const Text('Dark'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}
