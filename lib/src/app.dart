import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/settings/settings_controller.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = appRouter;
    final settings = ref.watch(settingsControllerProvider);
    final textTheme = GoogleFonts.interTextTheme();

    return MaterialApp.router(
      title: 'Clinical Curator',
      debugShowCheckedModeBanner: false,
      themeAnimationDuration: Duration.zero,
      themeMode: settings.flutterThemeMode,
      theme: settings.highContrastEnabled
          ? AppTheme.highContrast(textTheme: textTheme)
          : AppTheme.light(textTheme: textTheme),
      darkTheme: AppTheme.dark(textTheme: textTheme),
      routerConfig: router,
    );
  }
}

