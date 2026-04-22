import 'package:flutter/material.dart';

/// Theme-aware accessors so screens avoid hard-coded [AppColors] for text/surfaces.
extension AppThemeContext on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;

  Color get appMutedForeground => scheme.onSurfaceVariant;

  Color get appBorder => scheme.outline;

  /// Subtle tinted backgrounds (replaces hard-coded `0xFFF3F7FC` / similar).
  Color get appSubtleFill => scheme.surfaceContainerHighest;

  /// Selected row / nav highlight (replaces `0xFFE7F2FA`).
  Color get appSelectionFill => scheme.primaryContainer;

  Color get appSelectionBorder =>
      scheme.outlineVariant.withValues(alpha: 0.9);

  /// Nested setting row / chip well (replaces `Colors.white` inner tiles).
  Color get appNestedTileFill =>
      Theme.of(this).brightness == Brightness.dark
          ? scheme.surfaceContainerHighest
          : scheme.surface;

  /// Icon circle background (replaces `#F3F7FC` / light wells).
  Color get appSoftIconFill =>
      Theme.of(this).brightness == Brightness.dark
          ? scheme.surfaceContainerHighest
          : scheme.primaryContainer;
}
