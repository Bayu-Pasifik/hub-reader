import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/app_settings_provider.dart';
import 'ui/router.dart';
import 'ui/widgets/app_lock.dart';

class HubReaderApp extends ConsumerWidget {
  const HubReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appSettingsProvider);
    final dark = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: s.accent.color,
      brightness: Brightness.dark,
    );
    return MaterialApp.router(
      title: 'Hub Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: s.accent.color),
      darkTheme: s.pureBlack
          ? dark.copyWith(
              scaffoldBackgroundColor: Colors.black,
              colorScheme: dark.colorScheme.copyWith(surface: Colors.black),
            )
          : dark,
      themeMode: s.themeMode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => AppLockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
