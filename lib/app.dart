import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/app_settings_provider.dart';
import 'state/download_providers.dart';
import 'ui/app_shortcuts.dart';
import 'ui/deep_links.dart';
import 'ui/router.dart';
import 'ui/widgets/app_update_ui.dart';
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
      AppShortcuts.init((location, isTab) {
        final router = ref.read(routerProvider);
        isTab ? router.go(location) : router.push(location);
      });
      // Lanjutkan antrean unduhan yang tersimpan dari sesi sebelumnya.
      ref.read(downloadQueueProvider);
      // Bersihkan unduhan bab yang sudah dibaca (bila pengaturan aktif).
      ref.read(downloadIndexProvider.notifier).purgeRead().ignore();
      // Rilis baru di GitHub (paling sering sekali sehari).
      autoCheckForUpdates(() => ref.read(routerProvider).routerDelegate.navigatorKey.currentContext, ref).ignore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appSettingsProvider);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // Material You: pakai warna utama wallpaper sebagai seed tema.
        final useDynamic = s.dynamicColor && lightDynamic != null && darkDynamic != null;
        final light = ThemeData(
          useMaterial3: true,
          colorSchemeSeed: useDynamic ? lightDynamic.primary : s.accent.color,
        );
        final dark = ThemeData(
          useMaterial3: true,
          colorSchemeSeed: useDynamic ? darkDynamic.primary : s.accent.color,
          brightness: Brightness.dark,
        );
        return MaterialApp.router(
          title: 'Hub Reader',
          debugShowCheckedModeBanner: false,
          theme: light,
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
      },
    );
  }
}
