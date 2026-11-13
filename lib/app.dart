import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/app_settings_provider.dart';
import 'state/download_providers.dart';
import 'ui/deep_links.dart';
import 'ui/router.dart';
import 'ui/widgets/app_lock.dart';

class HubReaderApp extends ConsumerStatefulWidget {
  const HubReaderApp({super.key});

  @override
  ConsumerState<HubReaderApp> createState() => _HubReaderAppState();
}

class _HubReaderAppState extends ConsumerState<HubReaderApp> {
  @override
  void initState() {
    super.initState();
    // Tautan hubreader:// (lihat DeepLinks): buka di atas tab yang aktif.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinks.listen((location) => ref.read(routerProvider).push(location));
      // Lanjutkan antrean unduhan yang tersimpan dari sesi sebelumnya.
      ref.read(downloadQueueProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
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
