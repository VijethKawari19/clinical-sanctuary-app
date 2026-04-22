import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/session/session_controller.dart';
import '../../features/settings/settings_controller.dart';
import '../../features/settings/settings_state.dart';
import '../../theme/app_theme.dart';

class ClinicianShell extends ConsumerWidget {
  const ClinicianShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final settings = ref.watch(settingsControllerProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final showSearch =
            !path.startsWith('/c/queue') && !path.startsWith('/c/settings');

        if (isNarrow) {
          return Scaffold(
            drawer: Drawer(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: _SideNavContent(selectedPath: path, ref: ref),
                ),
              ),
            ),
            body: Column(
              children: [
                _TopBar(
                  photoBase64: settings.profilePhotoBase64,
                  showSearch: showSearch,
                  leading: Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Menu',
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: child,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              _SideNav(selectedPath: path, ref: ref),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      photoBase64: settings.profilePhotoBase64,
                      showSearch: showSearch,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.selectedPath, required this.ref});
  final String selectedPath;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          right: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: _SideNavContent(selectedPath: selectedPath, ref: ref),
        ),
      ),
    );
  }
}

class _SideNavContent extends StatelessWidget {
  const _SideNavContent({required this.selectedPath, required this.ref});

  final String selectedPath;
  final WidgetRef ref;

  bool _isSelected(String path) => selectedPath.startsWith(path);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: context.appSoftIconFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.65),
                ),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OPMD',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'CLINICAL SUITE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.1,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        _NavItem(
          label: 'Dashboard',
          icon: Icons.grid_view_rounded,
          selected: _isSelected('/c/dashboard'),
          onTap: () => context.go('/c/dashboard'),
        ),
        const SizedBox(height: 6),
        _NavItem(
          label: 'Patients',
          icon: Icons.people_outline_rounded,
          selected: _isSelected('/c/queue') || _isSelected('/c/case/'),
          onTap: () => context.go('/c/queue'),
        ),
        const SizedBox(height: 6),
        _NavItem(
          label: 'Settings',
          icon: Icons.settings_outlined,
          selected: _isSelected('/c/settings'),
          onTap: () => context.go('/c/settings'),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () {
            ref.read(sessionControllerProvider.notifier).endSession();
            context.go('/auth');
          },
          icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
          label: const Align(
            alignment: Alignment.centerLeft,
            child: Text('Logout', style: TextStyle(color: AppColors.danger)),
          ),
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.photoBase64,
    required this.showSearch,
    this.leading,
  });

  final String? photoBase64;
  final bool showSearch;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
        ),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: showSearch
                  ? TextField(
                      style: TextStyle(color: scheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Search patients, records...',
                        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: scheme.outline.withValues(alpha: 0.65),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: scheme.outline.withValues(alpha: 0.65),
                          ),
                        ),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.notifications_none_rounded,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          _ProfileButton(photoBase64: photoBase64),
        ],
      ),
    );
  }
}

class _ProfileButton extends StatefulWidget {
  const _ProfileButton({required this.photoBase64});

  final String? photoBase64;

  @override
  State<_ProfileButton> createState() => _ProfileButtonState();
}

class _ProfileButtonState extends State<_ProfileButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  void _toggle() {
    final isNarrow = MediaQuery.sizeOf(context).width < 600;
    if (isNarrow) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
            child: Material(
              color: Colors.transparent,
              child: Consumer(
                builder: (context, ref, _) {
                  final settings = ref.watch(settingsControllerProvider);
                  final ctrl = ref.read(settingsControllerProvider.notifier);
                  return _ProfilePopover(
                    settings: settings,
                    onClose: () => Navigator.of(ctx).pop(),
                    onChangePhoto: () async {
                      final file = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                      );
                      if (file == null) return;
                      await ctrl.importProfilePhoto(file);
                    },
                    onLogout: () {
                      Navigator.of(ctx).pop();
                      ref.read(sessionControllerProvider.notifier).endSession();
                      context.go('/auth');
                    },
                  );
                },
              ),
            ),
          );
        },
      );
      return;
    }
    if (_entry != null) {
      _remove();
      return;
    }
    _entry = _buildEntry();
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void _remove() {
    _entry?.remove();
    _entry = null;
  }

  OverlayEntry _buildEntry() {
    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _remove,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 12),
              child: Material(
                color: Colors.transparent,
                child: Consumer(
                  builder: (context, ref, _) {
                    final settings = ref.watch(settingsControllerProvider);
                    final ctrl = ref.read(settingsControllerProvider.notifier);
                    return _ProfilePopover(
                      settings: settings,
                      onClose: _remove,
                      onChangePhoto: () async {
                        final file = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                        );
                        if (file == null) return;
                        await ctrl.importProfilePhoto(file);
                      },
                      onLogout: () {
                        _remove();
                        ref
                            .read(sessionControllerProvider.notifier)
                            .endSession();
                        context.go('/auth');
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: widget.photoBase64 == null
                ? null
                : MemoryImage(base64Decode(widget.photoBase64!)),
            child: widget.photoBase64 == null
                ? const Icon(Icons.person, color: AppColors.primary, size: 18)
                : null,
          ),
        ),
      ),
    );
  }
}

class _ProfilePopover extends StatelessWidget {
  const _ProfilePopover({
    required this.settings,
    required this.onClose,
    required this.onChangePhoto,
    required this.onLogout,
  });

  final SettingsState settings;
  final VoidCallback onClose;
  final VoidCallback onChangePhoto;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.55)),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 40),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surface,
                      side: BorderSide(
                        color: scheme.outline.withValues(alpha: 0.65),
                      ),
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
                              ? const Icon(
                                  Icons.person,
                                  color: AppColors.primary,
                                  size: 40,
                                )
                              : Image.memory(
                                  base64Decode(settings.profilePhotoBase64!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) =>
                                      const Icon(
                                        Icons.person,
                                        color: AppColors.primary,
                                        size: 40,
                                      ),
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
                            onPressed: onChangePhoto,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(44, 44),
                            ),
                            child: const Icon(
                              Icons.photo_camera_outlined,
                              size: 20,
                            ),
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
                    settings.profileRole,
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
                  Divider(
                    height: 1,
                    color: scheme.outline.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onLogout,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Logout',
                            style: Theme.of(context).textTheme.titleMedium
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
