import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

/// Warna utama aplikasi.
enum AppAccent {
  indigo('Indigo', Colors.indigo),
  teal('Hijau toska', Colors.teal),
  green('Hijau', Colors.green),
  orange('Oranye', Colors.deepOrange),
  pink('Merah muda', Colors.pink),
  purple('Ungu', Colors.deepPurple),
  blueGrey('Abu biru', Colors.blueGrey);

  const AppAccent(this.label, this.color);

  final String label;
  final Color color;
}

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.pureBlack = false,
    this.accent = AppAccent.indigo,
    this.appLock = false,
    this.lockAfter = const Duration(minutes: 1),
    this.incognito = false,
  });

  final ThemeMode themeMode;

  /// Latar hitam pekat pada tema gelap (hemat baterai di layar OLED).
  final bool pureBlack;
  final AppAccent accent;

  /// Minta sidik jari / PIN perangkat saat aplikasi dibuka.
  final bool appLock;

  /// Kunci lagi setelah aplikasi di latar selama ini.
  final Duration lockAfter;

  /// Mode samaran: riwayat & posisi baca tidak dicatat.
  final bool incognito;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? pureBlack,
    AppAccent? accent,
    bool? appLock,
    Duration? lockAfter,
    bool? incognito,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        pureBlack: pureBlack ?? this.pureBlack,
        accent: accent ?? this.accent,
        appLock: appLock ?? this.appLock,
        lockAfter: lockAfter ?? this.lockAfter,
        incognito: incognito ?? this.incognito,
      );
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

class AppSettingsNotifier extends Notifier<AppSettings> {
  static const _theme = 'app.theme.v1';
  static const _black = 'app.pure_black.v1';
  static const _accent = 'app.accent.v1';
  static const _lock = 'app.lock.v1';
  static const _lockAfter = 'app.lock_after_seconds.v1';
  static const _incognito = 'app.incognito.v1';

  @override
  AppSettings build() {
    final p = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      themeMode: ThemeMode.values.where((m) => m.name == p.getString(_theme)).firstOrNull ?? ThemeMode.system,
      pureBlack: p.getBool(_black) ?? false,
      accent: AppAccent.values.where((a) => a.name == p.getString(_accent)).firstOrNull ?? AppAccent.indigo,
      appLock: p.getBool(_lock) ?? false,
      lockAfter: Duration(seconds: p.getInt(_lockAfter) ?? 60),
      incognito: p.getBool(_incognito) ?? false,
    );
  }

  Future<void> update(AppSettings Function(AppSettings) change) async {
    state = change(state);
    final p = ref.read(sharedPreferencesProvider);
    await p.setString(_theme, state.themeMode.name);
    await p.setBool(_black, state.pureBlack);
    await p.setString(_accent, state.accent.name);
    await p.setBool(_lock, state.appLock);
    await p.setInt(_lockAfter, state.lockAfter.inSeconds);
    await p.setBool(_incognito, state.incognito);
  }
}
