import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../features/settings/settings_controller.dart';
import '../../../features/settings/settings_state.dart';

class ClinicianSettingsPage extends ConsumerWidget {
  const ClinicianSettingsPage({super.key});

  static String _formatMonths(int months) {
    final m = months.clamp(1, 60);
    final years = m ~/ 12;
    final rem = m % 12;
    if (years == 0) return '${m}m';
    if (rem == 0) return '${years}y';
    return '${years}y ${rem}m';
  }

  static Future<void> _saveBytesAs(
    BuildContext context, {
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final file = XFile.fromData(bytes, mimeType: mimeType, name: filename);
    final location = await getSaveLocation(suggestedName: filename);
    if (!context.mounted) return;
    if (location == null) return;
    await file.saveTo(location.path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: ${location.path}')),
      );
    }
  }

  static Uint8List _excelBytes(List<List<Object?>> rows) {
    final excel = xls.Excel.createExcel();
    final sheet = excel['Sheet1'];
    for (final row in rows) {
      sheet.appendRow(
        row
            .map((e) => xls.TextCellValue(e?.toString() ?? ''))
            .toList(),
      );
    }
    final out = excel.save();
    return Uint8List.fromList(out ?? <int>[]);
  }

  static Future<void> _exportChooser(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              ListTile(
                leading: const Icon(Icons.people_outline_rounded),
                title: const Text('Patient Data'),
                subtitle: const Text('Download as Excel (.xlsx)'),
                onTap: () => Navigator.of(context).pop('patients'),
              ),
              ListTile(
                leading: const Icon(Icons.history_rounded),
                title: const Text('Audit Logs'),
                subtitle: const Text('Download as Excel (.xlsx)'),
                onTap: () => Navigator.of(context).pop('audit'),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
    if (!context.mounted) return;
    if (picked == null) return;

    final ts = DateTime.now().millisecondsSinceEpoch;
    if (picked == 'patients') {
      final bytes = _excelBytes([
        ['Patient ID', 'Name', 'Risk', 'Status', 'Date'],
        ['OP-9343-X', '2345678ol', 'HIGH RISK', 'Pending', '4/6/2026'],
        ['OP-9294-X', '9', 'HIGH RISK', 'Reviewed', '4/4/2026'],
      ]);
      await _saveBytesAs(
        context,
        filename: 'patients-$ts.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        bytes: bytes,
      );
      return;
    }

    final bytes = _excelBytes([
      ['Event', 'Details', 'When'],
      ['Login', 'OTP verified', 'Today'],
      ['Viewed Case', 'Case OP-9343-X opened', 'Today'],
      ['Settings Updated', 'Auto-Logout changed', 'Yesterday'],
    ]);
    await _saveBytesAs(
      context,
      filename: 'audit-logs-$ts.xlsx',
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      bytes: bytes,
    );
  }

  static Future<void> _editProfile(
    BuildContext context,
    SettingsController ctrl,
    SettingsState settings,
  ) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    await ctrl.importProfilePhoto(file);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);

    return ListView(
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Configure your application preferences and security.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: context.appSoftIconFill,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: context.scheme.outline.withValues(alpha: 0.65)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                    child: settings.profilePhotoBase64 == null
                      ? const Icon(Icons.person_outline_rounded,
                          color: AppColors.primary)
                        : Image.memory(
                            base64Decode(settings.profilePhotoBase64!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const Icon(Icons.person_outline_rounded,
                                  color: AppColors.primary),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.profileName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(settings.profileEmail,
                        style: TextStyle(
                            color: context.scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(
                      'Role: ${settings.profileRole}    •    Joined: ${settings.profileJoinedIso}',
                      style: TextStyle(
                          color: context.scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => _editProfile(context, ctrl, settings),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('Edit Profile'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 940;
            final w =
                wide ? (constraints.maxWidth - 18) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: [
                SizedBox(
                  width: w,
                  child: AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ANALYSIS ENGINE',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  letterSpacing: 1.3,
                                  color: context.scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _ToggleTile(
                            title: 'Cloud-based Analysis',
                            subtitle: 'Use high-performance remote servers',
                            value: settings.cloudAnalysisEnabled,
                            onChanged: ctrl.setCloudAnalysisEnabled,
                            icon: Icons.cloud_outlined,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'APPEARANCE & ACCESSIBILITY',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  letterSpacing: 1.3,
                                  color: context.scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _SelectTile(
                            title: 'Theme',
                            subtitle: 'Current: ${settings.themeMode == AppThemeMode.dark ? 'Dark' : 'Light'}',
                            icon: Icons.wb_sunny_outlined,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: context.scheme.surface,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                    color: context.scheme.outline
                                        .withValues(alpha: 0.65)),
                              ),
                              child: Text(
                                settings.themeMode == AppThemeMode.dark
                                    ? 'Dark'
                                    : 'Light',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: context.scheme.onSurface,
                                ),
                              ),
                            ),
                            onTap: () async {
                              final next = settings.themeMode == AppThemeMode.dark
                                  ? AppThemeMode.light
                                  : AppThemeMode.dark;
                              await ctrl.setThemeMode(next);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Theme set to ${next == AppThemeMode.dark ? 'Dark' : 'Light'}.',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                          _ToggleTile(
                            title: 'High Contrast Mode',
                            subtitle: 'Improve visual clarity',
                            value: settings.highContrastEnabled,
                            onChanged: ctrl.setHighContrastEnabled,
                            icon: Icons.contrast_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: w,
                  child: AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DATA MANAGEMENT',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  letterSpacing: 1.3,
                                  color: context.scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _SelectTile(
                            title: 'Export All Data',
                            subtitle: 'Download patient data or audit logs',
                            icon: Icons.download_outlined,
                            onTap: () async {
                              await _exportChooser(context);
                            },
                          ),
                          const SizedBox(height: 10),
                          _RetentionTile(
                            months: settings.dataRetentionMonths,
                            onMonthsChanged: ctrl.setDataRetentionMonths,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: w,
                  child: AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SECURITY & PRIVACY',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  letterSpacing: 1.3,
                                  color: context.scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _ToggleTile(
                            title: 'Biometric Lock',
                            subtitle: 'Require FaceID/TouchID',
                            value: settings.biometricLockEnabled,
                            onChanged: (v) async {
                              await ctrl.setBiometricLockEnabled(v);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(v
                                        ? 'Biometric lock enabled (wire-up local_auth next).'
                                        : 'Biometric lock disabled.'),
                                  ),
                                );
                              }
                            },
                            icon: Icons.fingerprint_rounded,
                          ),
                          const SizedBox(height: 10),
                          _ToggleTile(
                            title: 'Auto-Logout',
                            subtitle: 'Session timeout duration',
                            value: settings.autoLogoutEnabled,
                            onChanged: ctrl.setAutoLogoutEnabled,
                            icon: Icons.timer_outlined,
                          ),
                          if (settings.autoLogoutEnabled) ...[
                            const SizedBox(height: 10),
                            _AutoLogoutChoices(
                              minutes: settings.autoLogoutMinutes,
                              onChanged: ctrl.setAutoLogoutMinutes,
                            ),
                          ],
                          const SizedBox(height: 10),
                          _SelectTile(
                            title: 'Audit Logs',
                            subtitle: 'View access history',
                            icon: Icons.history_rounded,
                            onTap: () => context.push('/c/settings/audit-logs'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: w,
                  child: AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SUPPORT & LEGAL',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  letterSpacing: 1.3,
                                  color: context.scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _SelectTile(
                            title: 'Tutorial',
                            subtitle: 'Re-watch capture guide',
                            icon: Icons.help_outline_rounded,
                            onTap: () => context.push('/c/settings/tutorial'),
                          ),
                          const SizedBox(height: 10),
                          _SelectTile(
                            title: 'Contact Support',
                            subtitle: 'Get technical assistance',
                            icon: Icons.mail_outline_rounded,
                            onTap: () async {
                              final uri = Uri(
                                scheme: 'mailto',
                                path: 'support@clinicalcurator.app',
                                queryParameters: {
                                  'subject': 'Clinical Curator Support',
                                  'body':
                                      'Describe your issue here (include device + app version).',
                                },
                              );
                              final ok = await launchUrl(uri);
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'No email app available. Please email support@clinicalcurator.app'),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                          _SelectTile(
                            title: 'Privacy Policy',
                            subtitle: 'Terms & legal documentation',
                            icon: Icons.shield_outlined,
                            onTap: () => context.push('/c/settings/privacy'),
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
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appNestedTileFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: context.scheme.outline.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.appSoftIconFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: context.scheme.outline.withValues(alpha: 0.65)),
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
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style:
                      TextStyle(color: context.scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appNestedTileFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: context.scheme.outline.withValues(alpha: 0.65)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.appSoftIconFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: context.scheme.outline.withValues(alpha: 0.65)),
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
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style:
                        TextStyle(color: context.scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    color: context.scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _AutoLogoutChoices extends StatelessWidget {
  const _AutoLogoutChoices({
    required this.minutes,
    required this.onChanged,
  });

  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [2, 10, 30, 60];
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appNestedTileFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: scheme.outline.withValues(alpha: 0.65)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final m in options)
            ChoiceChip(
              label: Text('$m min'),
              selected: minutes == m,
              onSelected: (_) => onChanged(m),
              selectedColor: scheme.primaryContainer,
              checkmarkColor: scheme.primary,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w800,
                color: minutes == m
                    ? scheme.onPrimaryContainer
                    : scheme.onSurface,
              ),
              side: BorderSide(
                color: minutes == m
                    ? scheme.primary.withValues(alpha: 0.45)
                    : scheme.outline.withValues(alpha: 0.75),
              ),
            ),
        ],
      ),
    );
  }
}

class _RetentionTile extends StatefulWidget {
  const _RetentionTile({
    required this.months,
    required this.onMonthsChanged,
  });

  final int months;
  final ValueChanged<int> onMonthsChanged;

  @override
  State<_RetentionTile> createState() => _RetentionTileState();
}

class _RetentionTileState extends State<_RetentionTile> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = ((widget.months.clamp(1, 60) - 1) / 59.0).clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(covariant _RetentionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.months != widget.months) {
      _value = ((widget.months.clamp(1, 60) - 1) / 59.0).clamp(0.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = (1 + (_value * 59).round()).clamp(1, 60);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appNestedTileFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: scheme.outline.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.appSoftIconFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.65)),
                ),
                child: const Icon(Icons.schedule_outlined,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Retention Period',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How long records are kept',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: context.appSoftIconFill,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.65)),
                ),
                child: Text(
                  ClinicianSettingsPage._formatMonths(months),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Slider(
            value: _value,
            divisions: 59,
            onChanged: (v) {
              setState(() => _value = v);
              widget.onMonthsChanged((1 + (_value * 59).round()).clamp(1, 60));
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 MONTH',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              Text('60 MONTHS',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

