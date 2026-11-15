import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/platform/reader_bridge.dart';
import 'core/net/image_cache.dart';
import 'data/models/source_library.dart';
import 'state/app_settings_provider.dart';
import 'state/home_widget_sync.dart';
import 'state/onboarding_provider.dart';
import 'state/source_library_providers.dart';
import 'ui/widgets/library_routing.dart';
import 'state/download_providers.dart';
import 'ui/app_shortcuts.dart';
import 'ui/deep_links.dart';
import 'ui/router.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/widgets/app_update_ui.dart';
import 'ui/widgets/app_lock.dart';

class HubReaderApp extends ConsumerStatefulWidget {
  const HubReaderApp({super.key});

  @override
  ConsumerState<HubReaderApp> createState() => _HubReaderAppState();
}

class _HubReaderAppState extends ConsumerState<HubReaderApp> {
  /// Rapikan cache gambar sesuai batas ukuran: saat aplikasi dibuka dan setiap masuk ke latar.
  void _trimImageCache() {
    final mb = ref.read(appSettingsProvider).imageCacheMb;
    AppImageCache.instance.trimTo(mb * 1024 * 1024).ignore();
  }

  late final AppLifecycleListener _lifecycle;

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onPause: _trimImageCache);
    // Tautan hubreader:// (lihat DeepLinks): buka di atas tab yang aktif.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReaderBridge.setSecure(ref.read(appSettingsProvider).secureScreen);
      DeepLinks.listen((location) => ref.read(routerProvider).push(location));
      AppShortcuts.init((location, isTab) {
        final router = ref.read(routerProvider);
        isTab ? router.go(location) : router.push(location);
      });
      _syncHomeWidget(ref.read(sourceHistoryProvider));
      // Lanjutkan antrean unduhan yang tersimpan dari sesi sebelumnya.
      ref.read(downloadQueueProvider);
      // Bersihkan unduhan bab yang sudah dibaca (bila pengaturan aktif).
      ref.read(downloadIndexProvider.notifier).purgeRead().ignore();
      // Tunda sebentar supaya tidak bersaing dengan pemuatan layar pertama.
      Future<void>.delayed(const Duration(seconds: 8), _trimImageCache);
      // Rilis baru di GitHub (paling sering sekali sehari).
      autoCheckForUpdates(() => ref.read(routerProvider).routerDelegate.navigatorKey.currentContext, ref).ignore();
    });
  }

  /// Widget layar utama: bacaan terakhir dari riwayat.
  void _syncHomeWidget(List<SourceHistoryEntry> history) {
    final e = history.firstOrNull;
    if (e == null) {
      HomeWidgetSync.update();
      return;
    }
    final info = librarySourceInfo(ref, e.item.sourceId);
    HomeWidgetSync.update(
      title: e.item.title,
      subtitle: e.chapterName,
      link: DeepLinks.linkFor(info.readerLocation(e.item.url, e.chapterUrl)),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sourceHistoryProvider, (_, next) => _syncHomeWidget(next));
    ref.listen(appSettingsProvider.select((x) => x.secureScreen), (_, on) => ReaderBridge.setSecure(on));
    final s = ref.watch(appSettingsProvider);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // Material You: pakai warna utama wallpaper sebagai seed tema.
        final useDynamic = s.dynamicColor && lightDynamic != null && darkDynamic != null;
        // Android 13+: gestur kembali prediktif (pratinjau layar sebelumnya saat menggeser).
        const transitions = PageTransitionsTheme(builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        });
        final light = ThemeData(
          useMaterial3: true,
          pageTransitionsTheme: transitions,
          colorSchemeSeed: useDynamic ? lightDynamic.primary : s.accent.color,
        );
        final dark = ThemeData(
          useMaterial3: true,
          pageTransitionsTheme: transitions,
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
          builder: (context, child) => AppLockGate(
            child: Stack(
              children: [
                // Router tetap hidup di bawah sambutan, jadi tautan dalam & pintasan tidak hilang.
                Positioned.fill(child: child ?? const SizedBox.shrink()),
                if (!ref.watch(onboardingDoneProvider)) const Positioned.fill(child: OnboardingScreen()),
              ],
            ),
          ),
        );
      },
    );
  }
}
