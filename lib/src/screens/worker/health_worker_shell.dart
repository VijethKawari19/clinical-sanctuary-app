import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/health_worker_profile_popover.dart';

/// Wraps health worker routes with a top bar (notifications + profile with theme & actions).
class HealthWorkerShell extends ConsumerWidget {
  const HealthWorkerShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoBase64 =
        ref.watch(settingsControllerProvider).profilePhotoBase64;

    return Scaffold(
      body: Column(
        children: [
          _HealthWorkerTopBar(photoBase64: photoBase64),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _HealthWorkerTopBar extends StatelessWidget {
  const _HealthWorkerTopBar({required this.photoBase64});

  final String? photoBase64;

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
          Text(
            'OPMD',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          Text(
            'CLINICAL SUITE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.notifications_none_rounded,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          _HealthWorkerProfileButton(photoBase64: photoBase64),
        ],
      ),
    );
  }
}

class _HealthWorkerProfileButton extends StatefulWidget {
  const _HealthWorkerProfileButton({required this.photoBase64});

  final String? photoBase64;

  @override
  State<_HealthWorkerProfileButton> createState() =>
      _HealthWorkerProfileButtonState();
}

class _HealthWorkerProfileButtonState
    extends State<_HealthWorkerProfileButton> {
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
              child: HealthWorkerProfilePopover(
                onClose: () => Navigator.of(ctx).pop(),
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
                child: HealthWorkerProfilePopover(onClose: _remove),
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
            backgroundColor: const Color(0xFFE7F2FA),
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
